import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diem_danh_khuon_mat.dart';
import '../services/face_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/face_mesh_capture_screen.dart';
import 'benchmark_diem_danh_screen.dart';

/// Màn hình điểm danh khuôn mặt: nhập buổi học, chụp ảnh, gửi API.
class DiemDanhKhuonMatScreen extends StatefulWidget {
  const DiemDanhKhuonMatScreen({super.key});

  @override
  State<DiemDanhKhuonMatScreen> createState() => _DiemDanhKhuonMatScreenState();
}

class _DiemDanhKhuonMatScreenState extends State<DiemDanhKhuonMatScreen> {
  final FaceApiService _api = FaceApiService();

  String _doiTuongLoai = 'SINH_VIEN';
  final TextEditingController _sinhVienIdController = TextEditingController();
  final TextEditingController _vienChucIdController = TextEditingController();
  final TextEditingController _buoiHocIdController = TextEditingController();
  final TextEditingController _phongIdController = TextEditingController();
  final TextEditingController _lopHocPhanIdController = TextEditingController();

  String? _base64Image;
  String? _faceMeshJson;
  bool _loading = false;
  String? _message;
  DiemDanhKhuonMatResponse? _lastResponse;
  double? _previewLongThietBi;
  double? _previewLatThietBi;

  @override
  void dispose() {
    _sinhVienIdController.dispose();
    _vienChucIdController.dispose();
    _buoiHocIdController.dispose();
    _phongIdController.dispose();
    _lopHocPhanIdController.dispose();
    super.dispose();
  }

  /// Giá trị độ tin cậy thang [0,1]; khoảng [0.94, 0.99] hiển thị như 100%.
  String _chuoiPhanTramDoTinCay(double? v) {
    if (v == null) return '-';
    final hienThi = (v >= 0.95 && v <= 0.99) ? 1.0 : v;
    return '${(hienThi * 100).round()}%';
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
      _base64Image = base64Encode(bytes);
      _faceMeshJson = null;
      _message = null;
      _lastResponse = null;
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
      _base64Image = result.base64FaceCrop;
      _faceMeshJson = result.faceMeshJson;
      _message = null;
      _lastResponse = null;
    });
  }

  Future<void> _submit() async {
    if (_base64Image == null || _base64Image!.isEmpty) {
      setState(() => _message = 'Vui lòng chụp hoặc chọn ảnh khuôn mặt.');
      return;
    }
    final buoiHocId = int.tryParse(_buoiHocIdController.text.trim());
    if (buoiHocId == null) {
      setState(() => _message = 'Nhập mã buổi học (số).');
      return;
    }
    int? sinhVienId;
    int? vienChucId;
    if (_doiTuongLoai == 'SINH_VIEN') {
      final id = int.tryParse(_sinhVienIdController.text.trim());
      if (id == null) {
        setState(() => _message = 'Nhập mã sinh viên');
        return;
      }
      sinhVienId = id;
    } else {
      final id = int.tryParse(_vienChucIdController.text.trim());
      if (id == null) {
        setState(() => _message = 'Nhập mã viên chức');
        return;
      }
      vienChucId = id;
    }

    setState(() {
      _loading = true;
      _message = null;
      _lastResponse = null;
      _previewLongThietBi = null;
      _previewLatThietBi = null;
    });

    try {
      final phongId = int.tryParse(_phongIdController.text.trim());
      double? longThietBi;
      double? latThietBi;

      if (phongId != null) {
        try {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            var permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission != LocationPermission.denied &&
                permission != LocationPermission.deniedForever) {
              final pos = await Geolocator.getCurrentPosition();
              longThietBi = pos.longitude;
              latThietBi = pos.latitude;
              setState(() {
                _previewLongThietBi = longThietBi;
                _previewLatThietBi = latThietBi;
              });
            }
          }
        } catch (e) {
          debugPrint('Get position for attendance error: $e');
        }
      }

      final request = DiemDanhKhuonMatRequest(
        doiTuongLoai: _doiTuongLoai,
        sinhVienId: sinhVienId,
        vienChucId: vienChucId,
        buoiHocId: buoiHocId,
        anhChupThoiDiem: _base64Image,
        faceMeshJson: _faceMeshJson,
        lopHocPhanId: int.tryParse(_lopHocPhanIdController.text.trim()),
        phongId: phongId,
        longThietBi: longThietBi,
        latThietBi: latThietBi,
      );
      final response = await _api.diemDanhKhuonMat(request);
      setState(() {
        _loading = false;
        _lastResponse = response;
        _message = response.thongDiep ??
            (response.thanhCong ? 'Điểm danh thành công.' : 'Điểm danh thất bại.');
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
    final ok = _lastResponse?.thanhCong == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh khuôn mặt'),
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const BenchmarkDiemDanhScreen(),
                      ),
                    );
                  },
            child: const Text('Benchmark'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thông tin buổi học',
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
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _buoiHocIdController,
              decoration: const InputDecoration(
                labelText: 'Mã buổi học',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _lopHocPhanIdController,
              decoration: const InputDecoration(
                labelText: 'Mã lớp học phần (tùy chọn)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _phongIdController,
              decoration: const InputDecoration(
                labelText: 'Mã phòng (lấy vị trí)',
              ),
              keyboardType: TextInputType.number,
            ),
            if (_previewLatThietBi != null && _previewLongThietBi != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tọa độ gửi kèm: ${_previewLatThietBi!.toStringAsFixed(6)}, ${_previewLongThietBi!.toStringAsFixed(6)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ảnh tại thời điểm điểm danh',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nên chụp trực tiếp để khớp khuôn mặt; chọn ảnh khi không dùng được camera.',
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
            if (_base64Image != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Đã chọn dữ liệu (~${(_base64Image!.length / 1024).toStringAsFixed(1)} KB)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_faceMeshJson != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Đã có face mesh (crop chuẩn).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (_message != null) ...[
              AppStatusBanner(
                positive: ok,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_lastResponse != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Độ tin cậy: ${_chuoiPhanTramDoTinCay(_lastResponse!.doTinCayNhanDien)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ok
                              ? AppSemantic.successForeground(context)
                              : AppSemantic.errorForeground(context),
                        ),
                      ),
                      if (_lastResponse!.saiSoViTri != null)
                        Text(
                          'Sai số vị trí: ${_lastResponse!.saiSoViTri!.toStringAsFixed(1)} m',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ok
                                ? AppSemantic.successForeground(context)
                                : AppSemantic.errorForeground(context),
                          ),
                        ),
                      Text(
                        'Hợp lệ khuôn mặt: ${_lastResponse!.hopLeKhuonMat == true ? 'Có' : 'Không'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ok
                              ? AppSemantic.successForeground(context)
                              : AppSemantic.errorForeground(context),
                        ),
                      ),
                      if (_lastResponse!.hopLeViTri != null)
                        Text(
                          'Hợp lệ vị trí: ${_lastResponse!.hopLeViTri == true ? 'Có' : 'Không'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ok
                                ? AppSemantic.successForeground(context)
                                : AppSemantic.errorForeground(context),
                          ),
                        ),
                    ],
                  ],
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
                  : const Text('Gửi điểm danh'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
