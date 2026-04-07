import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/dang_ky_khuon_mat.dart';
import '../services/face_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/face_mesh_capture_screen.dart';

/// Màn hình đăng ký khuôn mặt: chụp/chọn ảnh, nhập đối tượng, gửi API.
class DangKyKhuonMatScreen extends StatefulWidget {
  const DangKyKhuonMatScreen({super.key});

  @override
  State<DangKyKhuonMatScreen> createState() => _DangKyKhuonMatScreenState();
}

class _DangKyKhuonMatScreenState extends State<DangKyKhuonMatScreen> {
  final FaceApiService _api = FaceApiService();
  final _formKey = GlobalKey<FormState>();

  String _doiTuongLoai = 'SINH_VIEN';
  final TextEditingController _sinhVienIdController = TextEditingController();
  final TextEditingController _vienChucIdController = TextEditingController();
  String? _base64FaceCrop;
  String? _faceMeshJson;
  bool _loading = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _sinhVienIdController.dispose();
    _vienChucIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() {
      _base64FaceCrop = base64Encode(bytes);
      _faceMeshJson = null;
      _message = null;
    });
  }

  Future<void> _openFaceMeshCapture() async {
    final result = await Navigator.of(context).push<FaceMeshCaptureResult>(
      PageRouteBuilder<FaceMeshCaptureResult>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FaceMeshCaptureScreen(),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (result == null) return;
    setState(() {
      _base64FaceCrop = result.base64FaceCrop;
      _faceMeshJson = result.faceMeshJson;
      _message = null;
    });
  }

  Future<void> _submit() async {
    if (_base64FaceCrop == null || _base64FaceCrop!.isEmpty) {
      setState(() => _message = 'Vui lòng chụp hoặc chọn ảnh khuôn mặt.');
      return;
    }
    int? sinhVienId;
    int? vienChucId;
    if (_doiTuongLoai == 'SINH_VIEN') {
      final id = int.tryParse(_sinhVienIdController.text.trim());
      if (id == null) {
        setState(() => _message = 'Nhập mã sinh viên (số).');
        return;
      }
      sinhVienId = id;
    } else {
      final id = int.tryParse(_vienChucIdController.text.trim());
      if (id == null) {
        setState(() => _message = 'Nhập mã viên chức (số).');
        return;
      }
      vienChucId = id;
    }

    setState(() {
      _loading = true;
      _message = null;
      _success = false;
    });

    try {
      final request = DangKyKhuonMat(
        doiTuongLoai: _doiTuongLoai,
        sinhVienId: sinhVienId,
        vienChucId: vienChucId,
        hinhAnhSoSanhBase64: _base64FaceCrop,
        faceMeshJson: _faceMeshJson,
        isActive: true,
      );
      final result = await _api.dangKyKhuonMat(request);
      setState(() {
        _loading = false;
        _success = true;
        _message = 'Đăng ký thành công. Mã: ${result?.id}';
        _base64FaceCrop = null;
        _faceMeshJson = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký khuôn mặt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thông tin đối tượng',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const AppSectionTitle('Loại đối tượng'),
              DropdownButtonFormField<String>(
                initialValue: _doiTuongLoai,
                items: const [
                  DropdownMenuItem(value: 'SINH_VIEN', child: Text('Sinh viên')),
                  DropdownMenuItem(value: 'GIANG_VIEN', child: Text('Giảng viên')),
                ],
                onChanged: (v) => setState(() => _doiTuongLoai = v ?? 'SINH_VIEN'),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_doiTuongLoai == 'SINH_VIEN')
                TextFormField(
                  controller: _sinhVienIdController,
                  decoration: const InputDecoration(
                    labelText: 'Mã sinh viên',
                  ),
                  keyboardType: TextInputType.number,
                )
              else
                TextFormField(
                  controller: _vienChucIdController,
                  decoration: const InputDecoration(
                    labelText: 'Mã viên chức',
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ảnh khuôn mặt',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chụp trực tiếp để có dữ liệu khớp mặt tốt nhất. Từ thư viện chỉ dùng khi cần.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _openFaceMeshCapture,
                      child: const Text('Chụp ảnh'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
                      child: const Text('Chọn ảnh'),
                    ),
                  ),
                ],
              ),
              if (_base64FaceCrop != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Đã chọn dữ liệu (~${((_base64FaceCrop?.length ?? 0) / 1024).toStringAsFixed(1)} KB)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_faceMeshJson != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Đã có dữ liệu face mesh (468 điểm).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_message != null) ...[
                AppStatusBanner(
                  positive: _success,
                  child: Text(
                    _message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gửi đăng ký'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
