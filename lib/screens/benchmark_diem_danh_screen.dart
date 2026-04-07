import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diem_danh_khuon_mat.dart';
import '../services/face_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/face_mesh_capture_screen.dart';

/// Kết quả một lần gọi API trong benchmark (seq: thứ tự 0..N-1).
class _KetQuaTungLuot {
  _KetQuaTungLuot({
    required this.seq,
    required this.userId,
    required this.thoiGian,
    required this.thanhCong,
    this.phanHoi,
    this.loi,
  });

  final int seq;
  final int userId;
  final Duration thoiGian;
  final bool thanhCong;
  final DiemDanhKhuonMatResponse? phanHoi;
  final String? loi;
}

/// Tổng hợp thống kê sau khi chạy benchmark.
class _TongHopBenchmark {
  _TongHopBenchmark({
    required this.tongSo,
    required this.soThanhCong,
    required this.thoiGianTuongDong,
    required this.tongThoiGianCongLuot,
    required this.trungBinhMs,
    required this.minMs,
    required this.maxMs,
    required this.yeuCauMoiGiay,
    this.trungBinhDoTinCay,
    this.trungBinhSaiSoViTri,
  });

  final int tongSo;
  final int soThanhCong;
  /// Thời gian thực từ lúc bắt đầu đến khi xong mọi lượt (đúng cho song song).
  final Duration thoiGianTuongDong;
  /// Cộng thời gian từng lượt (chỉ tham khảo, không dùng làm thông lượng khi gọi song song).
  final Duration tongThoiGianCongLuot;
  final double trungBinhMs;
  final double minMs;
  final double maxMs;
  final double yeuCauMoiGiay;
  final double? trungBinhDoTinCay;
  final double? trungBinhSaiSoViTri;

  int get soThatBai => tongSo - soThanhCong;

  double get tyLeThanhCongPhanTram =>
      tongSo == 0 ? 0 : (soThanhCong * 100 / tongSo);
}

/// Số nhân logic (Luồng) OS báo cáo; dùng gợi ý độ đồng thời khi gọi mạng song song.
int _soNhanThietBi() {
  try {
    final n = Platform.numberOfProcessors;
    if (n >= 1) return n;
  } catch (_) {
    // Môi trường không hỗ trợ (hiếm khi trên mobile).
  }
  return 4;
}

/// Đồng thời mặc định: ~4× nhân (tác vụ I/O), trần 128 để tránh quá tải RAM trên máy yếu.
int _goiYDongThoiMacDinh() {
  final n = _soNhanThietBi();
  return math.max(4, math.min(n * 4, 128));
}

/// Trần an toàn cho ô nhập: tăng theo nhân để benchmark dùng được nhiều kết nối song song.
int _gioiHanDongThoiTren() {
  final n = _soNhanThietBi();
  return math.min(512, math.max(48, n * 24));
}

/// Mỗi lượt benchmark dịch thêm bấy nhiêu mét (mô phỏng sai số GPS nhẹ, tách biệt giữa các request).
const double _buocSaiSoViTriMetMoiLuot = 0.1;

/// Cộng dịch chuyển bắc/đông (mét) lên tọa độ WGS84 độ.
(double latDeg, double longDeg) _viTriCongThemMet(
  double lat0,
  double long0,
  double bacMet,
  double dongMet,
) {
  const metMotDoVi = 111320.0;
  final rad = lat0 * math.pi / 180;
  final metMotDoKinh = metMotDoVi * math.cos(rad);
  return (
    lat0 + bacMet / metMotDoVi,
    long0 + dongMet / metMotDoKinh,
  );
}

/// Giả lập nhiều người điểm danh khuôn mặt + vị trí, đo thời gian và thống kê.
class BenchmarkDiemDanhScreen extends StatefulWidget {
  const BenchmarkDiemDanhScreen({super.key});

  @override
  State<BenchmarkDiemDanhScreen> createState() =>
      _BenchmarkDiemDanhScreenState();
}

class _BenchmarkDiemDanhScreenState extends State<BenchmarkDiemDanhScreen> {
  final FaceApiService _api = FaceApiService();

  String _doiTuongLoai = 'SINH_VIEN';
  final TextEditingController _soLuongController =
      TextEditingController(text: '10');
  final TextEditingController _maBatDauController =
      TextEditingController(text: '1');
  final TextEditingController _buocTangController =
      TextEditingController(text: '1');
  final TextEditingController _soDongThoiToiDaController =
      TextEditingController();
  final TextEditingController _buoiHocIdController = TextEditingController();
  final TextEditingController _phongIdController = TextEditingController();
  final TextEditingController _lopHocPhanIdController =
      TextEditingController();

  String? _base64Image;
  String? _faceMeshJson;
  bool _dangChay = false;
  bool _yeuCauHuy = false;
  String? _message;
  bool _messageThanhCong = false;

  double? _previewLongThietBi;
  double? _previewLatThietBi;

  List<_KetQuaTungLuot> _ketQuaChiTiet = [];
  _TongHopBenchmark? _tongHop;
  bool _motMaCoDinh = false;

  @override
  void initState() {
    super.initState();
    _soDongThoiToiDaController.text = '${_goiYDongThoiMacDinh()}';
  }

  @override
  void dispose() {
    _soLuongController.dispose();
    _maBatDauController.dispose();
    _buocTangController.dispose();
    _soDongThoiToiDaController.dispose();
    _buoiHocIdController.dispose();
    _phongIdController.dispose();
    _lopHocPhanIdController.dispose();
    super.dispose();
  }

  String _chuoiPhanTramDoTinCay(double? v) {
    if (v == null) return '-';
    final hienThi = (v >= 0.95 && v <= 0.99) ? 1.0 : v;
    return '${(hienThi * 100).round()}%';
  }

  _TongHopBenchmark _tinhTongHop(
    List<_KetQuaTungLuot> ds, {
    required Duration thoiGianTuongDong,
  }) {
    if (ds.isEmpty) {
      return _TongHopBenchmark(
        tongSo: 0,
        soThanhCong: 0,
        thoiGianTuongDong: Duration.zero,
        tongThoiGianCongLuot: Duration.zero,
        trungBinhMs: 0,
        minMs: 0,
        maxMs: 0,
        yeuCauMoiGiay: 0,
      );
    }

    final ok = ds.where((e) => e.thanhCong).toList();
    final tongMs = ds.fold<double>(0, (s, e) => s + e.thoiGian.inMicroseconds / 1000.0);
    final minMs = ds.map((e) => e.thoiGian.inMicroseconds / 1000.0).reduce(math.min);
    final maxMs = ds.map((e) => e.thoiGian.inMicroseconds / 1000.0).reduce(math.max);
    final tb = tongMs / ds.length;
    final tongGianCong = ds.fold<Duration>(
      Duration.zero,
      (s, e) => s + e.thoiGian,
    );
    final giayTuongDong = thoiGianTuongDong.inMicroseconds / 1000000.0;
    final rps = giayTuongDong > 0 ? ds.length / giayTuongDong : 0.0;

    double? tbDt;
    if (ok.isNotEmpty) {
      final coDoTinCay = ok.where((e) => e.phanHoi?.doTinCayNhanDien != null).toList();
      if (coDoTinCay.isNotEmpty) {
        tbDt = coDoTinCay
                .map((e) => e.phanHoi!.doTinCayNhanDien!)
                .reduce((a, b) => a + b) /
            coDoTinCay.length;
      }
    }

    double? tbSaiSo;
    if (ok.isNotEmpty) {
      final coSaiSo = ok.where((e) => e.phanHoi?.saiSoViTri != null).toList();
      if (coSaiSo.isNotEmpty) {
        tbSaiSo = coSaiSo
                .map((e) => e.phanHoi!.saiSoViTri!)
                .reduce((a, b) => a + b) /
            coSaiSo.length;
      }
    }

    return _TongHopBenchmark(
      tongSo: ds.length,
      soThanhCong: ok.length,
      thoiGianTuongDong: thoiGianTuongDong,
      tongThoiGianCongLuot: tongGianCong,
      trungBinhMs: tb,
      minMs: minMs,
      maxMs: maxMs,
      yeuCauMoiGiay: rps,
      trungBinhDoTinCay: tbDt,
      trungBinhSaiSoViTri: tbSaiSo,
    );
  }

  Future<_KetQuaTungLuot> _motLuot({
    required int seq,
    required int userId,
    required int buoiHocId,
    required DiemDanhKhuonMatRequest mau,
  }) async {
    final sw = Stopwatch()..start();
    try {
      double? latGui = mau.latThietBi;
      double? longGui = mau.longThietBi;
      if (latGui != null && longGui != null) {
        final themBac = _buocSaiSoViTriMetMoiLuot * seq;
        final o = _viTriCongThemMet(latGui, longGui, themBac, 0);
        latGui = o.$1;
        longGui = o.$2;
      }
      final req = DiemDanhKhuonMatRequest(
        doiTuongLoai: mau.doiTuongLoai,
        sinhVienId: mau.sinhVienId != null ? userId : null,
        vienChucId: mau.vienChucId != null ? userId : null,
        buoiHocId: buoiHocId,
        lopHocPhanId: mau.lopHocPhanId,
        phongId: mau.phongId,
        longThietBi: longGui,
        latThietBi: latGui,
        anhChupThoiDiem: mau.anhChupThoiDiem,
        faceMeshJson: mau.faceMeshJson,
        peerId: userId.toString(),
        seq: seq,
      );
      final resp = await _api.diemDanhKhuonMat(req);
      sw.stop();
      return _KetQuaTungLuot(
        seq: seq,
        userId: userId,
        thoiGian: sw.elapsed,
        thanhCong: resp.thanhCong,
        phanHoi: resp,
      );
    } catch (e, st) {
      sw.stop();
      final ts = DateTime.now().toIso8601String();
      debugPrint(
        'benchmark loi peerId=$userId seq=$seq timestamp=$ts error=$e stack=$st',
      );
      return _KetQuaTungLuot(
        seq: seq,
        userId: userId,
        thoiGian: sw.elapsed,
        thanhCong: false,
        loi: e.toString().replaceFirst('Exception: ', ''),
      );
    }
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
      _tongHop = null;
      _ketQuaChiTiet = [];
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
      _base64Image = result.base64FaceCrop;
      _faceMeshJson = result.faceMeshJson;
      _tongHop = null;
      _ketQuaChiTiet = [];
      _message = null;
    });
  }

  Future<void> _chayBenchmark() async {
    if (_base64Image == null || _base64Image!.isEmpty) {
      setState(() {
        _message = 'Vui lòng chụp hoặc chọn ảnh dùng chung cho các lượt giả lập.';
        _messageThanhCong = false;
      });
      return;
    }

    final n = int.tryParse(_soLuongController.text.trim());
    if (n == null || n < 1) {
      setState(() {
        _message = 'Số lượng người dùng phải là số nguyên dương.';
        _messageThanhCong = false;
      });
      return;
    }

    final baseId = int.tryParse(_maBatDauController.text.trim());
    if (baseId == null) {
      setState(() {
        _message = 'Nhập mã đối tượng bắt đầu (số).';
        _messageThanhCong = false;
      });
      return;
    }

    var step = int.tryParse(_buocTangController.text.trim()) ?? 1;
    if (!_motMaCoDinh && step < 1) {
      setState(() {
        _message = 'Bước tăng mã phải >= 1.';
        _messageThanhCong = false;
      });
      return;
    }
    if (_motMaCoDinh) {
      step = 0;
    }

    final maxParallel =
        int.tryParse(_soDongThoiToiDaController.text.trim()) ?? 1;
    final tranDongThoi = _gioiHanDongThoiTren();
    if (maxParallel < 1 || maxParallel > tranDongThoi) {
      setState(() {
        _message =
            'Số request đồng thời phải từ 1 đến $tranDongThoi (theo ${_soNhanThietBi()} nhân CPU).';
        _messageThanhCong = false;
      });
      return;
    }

    final buoiHocId = int.tryParse(_buoiHocIdController.text.trim());
    if (buoiHocId == null) {
      setState(() {
        _message = 'Nhập mã buổi học (số).';
        _messageThanhCong = false;
      });
      return;
    }

    final phongIdRaw = _phongIdController.text.trim();
    final phongId =
        phongIdRaw.isEmpty ? null : int.tryParse(phongIdRaw);
    if (phongIdRaw.isNotEmpty && phongId == null) {
      setState(() {
        _message = 'Mã phòng không hợp lệ.';
        _messageThanhCong = false;
      });
      return;
    }

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
          }
        }
      } catch (e, st) {
        final ts = DateTime.now().toIso8601String();
        debugPrint(
          'benchmark lay vi tri loi seq=-1 timestamp=$ts error=$e stack=$st',
        );
      }
    }

    setState(() {
      _dangChay = true;
      _yeuCauHuy = false;
      _message = null;
      _ketQuaChiTiet = [];
      _tongHop = null;
      _previewLongThietBi = longThietBi;
      _previewLatThietBi = latThietBi;
    });

    final mau = DiemDanhKhuonMatRequest(
      doiTuongLoai: _doiTuongLoai,
      sinhVienId: _doiTuongLoai == 'SINH_VIEN' ? baseId : null,
      vienChucId: _doiTuongLoai == 'GIANG_VIEN' ? baseId : null,
      buoiHocId: buoiHocId,
      anhChupThoiDiem: _base64Image,
      faceMeshJson: _faceMeshJson,
      lopHocPhanId: int.tryParse(_lopHocPhanIdController.text.trim()),
      phongId: phongId,
      longThietBi: longThietBi,
      latThietBi: latThietBi,
    );

    final oKetQua = List<_KetQuaTungLuot?>.filled(n, null);
    final swToanBo = Stopwatch()..start();
    try {
      var i = 0;
      while (i < n) {
        if (_yeuCauHuy) {
          break;
        }
        final batchEnd = math.min(i + maxParallel, n);
        final batch = <Future<_KetQuaTungLuot>>[];
        for (var j = i; j < batchEnd; j++) {
          final userId = _motMaCoDinh ? baseId : baseId + j * step;
          batch.add(
            _motLuot(
              seq: j,
              userId: userId,
              buoiHocId: buoiHocId,
              mau: mau,
            ).then((ketQua) {
              oKetQua[ketQua.seq] = ketQua;
              if (mounted) {
                setState(() {
                  _ketQuaChiTiet = [
                    for (var k = 0; k < n; k++)
                      if (oKetQua[k] != null) oKetQua[k]!,
                  ];
                });
              }
              return ketQua;
            }),
          );
        }
        await Future.wait(batch);
        if (mounted) {
          setState(() {
            _ketQuaChiTiet = [
              for (var k = 0; k < n; k++)
                if (oKetQua[k] != null) oKetQua[k]!,
            ];
          });
        }
        i = batchEnd;
      }

      swToanBo.stop();
      final tatCa = [
        for (var k = 0; k < n; k++)
          if (oKetQua[k] != null) oKetQua[k]!,
      ];
      final hop = _tinhTongHop(
        tatCa,
        thoiGianTuongDong: swToanBo.elapsed,
      );
      setState(() {
        _tongHop = hop;
        _dangChay = false;
        if (_yeuCauHuy && tatCa.length < n) {
          _message =
              'Đã dừng sớm. Đã hoàn thành ${tatCa.length}/$n lượt.';
          _messageThanhCong = false;
        } else {
          _message = 'Benchmark hoàn tất.';
          _messageThanhCong = true;
        }
      });
    } catch (e, st) {
      final ts = DateTime.now().toIso8601String();
      debugPrint(
        'benchmark fatal seq=-1 timestamp=$ts error=$e stack=$st',
      );
      setState(() {
        _dangChay = false;
        _message = e.toString().replaceFirst('Exception: ', '');
        _messageThanhCong = false;
      });
    } finally {
      if (swToanBo.isRunning) {
        swToanBo.stop();
      }
    }
  }

  void _yeuCauDung() {
    setState(() => _yeuCauHuy = true);
  }

  Widget _oThongSo(BuildContext context, String nhan, String giaTri) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(nhan, style: t.bodySmall),
          ),
          Expanded(
            flex: 5,
            child: Text(
              giaTri,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hop = _tongHop;
    final goiYDongThoi = _goiYDongThoiMacDinh();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Benchmark điểm danh'),
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
              'Tham số giả lập',
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
              onChanged: _dangChay
                  ? null
                  : (v) => setState(() => _doiTuongLoai = v ?? 'SINH_VIEN'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _soLuongController,
              decoration: InputDecoration(
                labelText: _motMaCoDinh
                    ? 'Số lượt gọi API (cùng một mã)'
                    : 'Số lượng người dùng giả lập',
              ),
              keyboardType: TextInputType.number,
              enabled: !_dangChay,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _maBatDauController,
              decoration: InputDecoration(
                labelText: _doiTuongLoai == 'SINH_VIEN'
                    ? (_motMaCoDinh
                        ? 'Mã số sinh viên (MSSV)'
                        : 'Mã sinh viên bắt đầu')
                    : (_motMaCoDinh
                        ? 'Mã số viên chức'
                        : 'Mã viên chức bắt đầu'),
              ),
              keyboardType: TextInputType.number,
              enabled: !_dangChay,
            ),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Một mã cố định (không tăng mã giữa các lượt)',
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                'Bật khi chỉ cần đo tải hoặc lặp lại cùng một MSSV/mã viên chức; tránh nhiều mã khác nhau trong thời gian ngắn',
                style: theme.textTheme.bodySmall,
              ),
              value: _motMaCoDinh,
              onChanged: _dangChay
                  ? null
                  : (v) => setState(() => _motMaCoDinh = v),
            ),
            if (!_motMaCoDinh) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _buocTangController,
                decoration: const InputDecoration(
                  labelText: 'Bước tăng mã (mỗi lượt cộng thêm)',
                ),
                keyboardType: TextInputType.number,
                enabled: !_dangChay,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _soDongThoiToiDaController,
              decoration: const InputDecoration(
                labelText: 'Số request đồng thời tối đa',
                helperText: '1 = tuần tự; cao hơn = nhiều kết nối song song (tận dụng đa nhân I/O)',
              ),
              keyboardType: TextInputType.number,
              enabled: !_dangChay,
            ),
            
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _dangChay
                    ? null
                    : () {
                        setState(() {
                          _soDongThoiToiDaController.text =
                              '$goiYDongThoi';
                        });
                      },
                child: const Text('Đặt lại theo gợi ý CPU'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _buoiHocIdController,
              decoration: const InputDecoration(
                labelText: 'Mã buổi học',
              ),
              keyboardType: TextInputType.number,
              enabled: !_dangChay,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _lopHocPhanIdController,
              decoration: const InputDecoration(
                labelText: 'Mã lớp học phần (tùy chọn)',
              ),
              keyboardType: TextInputType.number,
              enabled: !_dangChay,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _phongIdController,
              decoration: const InputDecoration(
                labelText: 'Mã phòng',
              ),
              keyboardType: TextInputType.number,
              enabled: !_dangChay,
            ),
            if (_previewLatThietBi != null && _previewLongThietBi != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tọa độ gốc (lượt đầu): ${_previewLatThietBi!.toStringAsFixed(6)}, ${_previewLongThietBi!.toStringAsFixed(6)}',
                style: theme.textTheme.bodySmall,
              )
             
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ảnh và mesh dùng chung',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
           
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dangChay ? null : _openFaceMeshCapture,
                    child: const Text('Chụp ảnh'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dangChay
                        ? null
                        : () => _pickImage(ImageSource.gallery),
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
                positive: _messageThanhCong,
                child: Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (hop != null && hop.tongSo > 0) ...[
              Text(
                'Kết quả benchmark',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _oThongSo(
                        context,
                        'Tổng số lượt',
                        '${hop.tongSo}',
                      ),
                      _oThongSo(
                        context,
                        'Thành công / Thất bại',
                        '${hop.soThanhCong} / ${hop.soThatBai}',
                      ),
                      _oThongSo(
                        context,
                        'Tỷ lệ thành công',
                        '${hop.tyLeThanhCongPhanTram.toStringAsFixed(1)}%',
                      ),
                      _oThongSo(
                        context,
                        'Thời gian thực (đồng hồ tường)',
                        '${(hop.thoiGianTuongDong.inMilliseconds / 1000).toStringAsFixed(2)} s',
                      ),
                      _oThongSo(
                        context,
                        'Tổng thời gian (cộng từng lượt)',
                        '${(hop.tongThoiGianCongLuot.inMilliseconds / 1000).toStringAsFixed(2)} s',
                      ),
                      _oThongSo(
                        context,
                        'Thời gian trung bình mỗi lượt',
                        '${hop.trungBinhMs.toStringAsFixed(0)} ms',
                      ),
                      _oThongSo(
                        context,
                        'Nhanh nhất / Chậm nhất',
                        '${hop.minMs.toStringAsFixed(0)} ms / ${hop.maxMs.toStringAsFixed(0)} ms',
                      ),
                      _oThongSo(
                        context,
                        'Thông lượng (lượt/giây, theo thời gian thực)',
                        hop.yeuCauMoiGiay.toStringAsFixed(2),
                      ),
                      if (hop.trungBinhDoTinCay != null)
                        _oThongSo(
                          context,
                          'Độ tin cậy TB (các lượt thành công)',
                          _chuoiPhanTramDoTinCay(hop.trungBinhDoTinCay),
                        ),
                      if (hop.trungBinhSaiSoViTri != null)
                        _oThongSo(
                          context,
                          'Sai số vị trí TB (các lượt thành công)',
                          '${hop.trungBinhSaiSoViTri!.toStringAsFixed(1)} m',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Chi tiết từng lượt',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              ..._ketQuaChiTiet.map((e) {
                final ok = e.thanhCong;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: AppStatusBanner(
                    positive: ok,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'seq=${e.seq} | mã=${e.userId} | ${e.thoiGian.inMilliseconds} ms',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (e.loi != null)
                          Text(
                            e.loi!,
                            style: theme.textTheme.bodySmall,
                          )
                        else if (e.phanHoi != null) ...[
                          Text(
                            'Độ tin cậy: ${_chuoiPhanTramDoTinCay(e.phanHoi!.doTinCayNhanDien)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (e.phanHoi!.saiSoViTri != null)
                            Text(
                              'Sai số vị trí: ${e.phanHoi!.saiSoViTri!.toStringAsFixed(1)} m',
                              style: theme.textTheme.bodySmall,
                            ),
                          Text(
                            'Hợp lệ khuôn mặt: ${e.phanHoi!.hopLeKhuonMat == true ? 'Có' : 'Không'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (e.phanHoi!.hopLeViTri != null)
                            Text(
                              'Hợp lệ vị trí: ${e.phanHoi!.hopLeViTri == true ? 'Có' : 'Không'}',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _dangChay ? null : _chayBenchmark,
                    child: _dangChay
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Chạy benchmark'),
                  ),
                ),
                if (_dangChay) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _yeuCauDung,
                      child: const Text('Dừng sau batch hiện tại'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
