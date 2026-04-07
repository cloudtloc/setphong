import 'package:flutter/material.dart';

import '../models/diem_danh_ban_ghi.dart';
import '../services/face_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// Tra cứu lịch sử điểm danh và danh sách theo buổi (giao diện người dùng, không phải công cụ API thô).
class TraCuuDieuChinhApiScreen extends StatefulWidget {
  const TraCuuDieuChinhApiScreen({super.key});

  @override
  State<TraCuuDieuChinhApiScreen> createState() => _TraCuuDieuChinhApiScreenState();
}

class _TraCuuDieuChinhApiScreenState extends State<TraCuuDieuChinhApiScreen>
    with SingleTickerProviderStateMixin {
  final FaceApiService _api = FaceApiService();
  late TabController _tabController;

  bool _laSinhVien = true;
  final TextEditingController _maCaNhanCtl = TextEditingController();
  DateTime? _tuNgay;
  DateTime? _denNgay;

  final TextEditingController _maBuoiHocCtl = TextEditingController();
  final TextEditingController _maLopHocPhanCtl = TextEditingController();

  final TextEditingController _peerIdCtl = TextEditingController();
  final TextEditingController _seqCtl = TextEditingController();

  bool _dangTai = false;
  String? _loiCaNhan;
  String? _loiBuoi;

  List<DiemDanhBanGhi> _ketQuaLichSu = [];
  List<DiemDanhBanGhi> _ketQuaBuoi = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _maCaNhanCtl.dispose();
    _maBuoiHocCtl.dispose();
    _maLopHocPhanCtl.dispose();
    _peerIdCtl.dispose();
    _seqCtl.dispose();
    super.dispose();
  }

  String? _peerIdOpt() {
    final t = _peerIdCtl.text.trim();
    return t.isEmpty ? null : t;
  }

  int? _seqOpt() => int.tryParse(_seqCtl.text.trim());

  String _anhBanGhiUrl(int banGhiId) {
    return _api.getAnhDiemDanhBanGhiUrl(
      banGhiId,
      peerId: _peerIdOpt(),
      seq: _seqOpt(),
    );
  }

  DateTime? _dauNgayUtc(DateTime? d) {
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day).toUtc();
  }

  DateTime? _cuoiNgayUtc(DateTime? d) {
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toUtc();
  }

  static String _trangThaiTiengViet(String? t) {
    return switch (t) {
      'THANH_CONG' => 'Có mặt',
      'THAT_BAI' => 'Vắng / không hợp lệ',
      _ => t ?? '—',
    };
  }

  static String _chuoiThoiGian(DateTime? t) {
    if (t == null) return '—';
    final l = t.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final yy = l.year.toString();
    final hh = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  Future<void> _chonNgay({required bool laTuNgay}) async {
    final now = DateTime.now();
    final banDau = laTuNgay ? (_tuNgay ?? now) : (_denNgay ?? now);
    final chon = await showDatePicker(
      context: context,
      initialDate: banDau,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: laTuNgay ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
    );
    if (chon == null) return;
    setState(() {
      if (laTuNgay) {
        _tuNgay = chon;
      } else {
        _denNgay = chon;
      }
    });
  }

  Future<void> _taiLichSuCaNhan() async {
    final ma = int.tryParse(_maCaNhanCtl.text.trim());
    if (ma == null || ma <= 0) {
      setState(() {
        _loiCaNhan = _laSinhVien
            ? 'Vui lòng nhập mã số sinh viên (MSSV) hợp lệ.'
            : 'Vui lòng nhập mã giảng viên hợp lệ.';
      });
      return;
    }

    setState(() {
      _dangTai = true;
      _loiCaNhan = null;
      _ketQuaLichSu = [];
    });

    final peerId = _peerIdOpt();
    final seq = _seqOpt();
    try {
      final list = await _api.getLichSuDiemDanhCaNhan(
        doiTuongLoai: _laSinhVien ? 'SINH_VIEN' : 'GIANG_VIEN',
        sinhVienId: _laSinhVien ? ma : null,
        vienChucId: _laSinhVien ? null : ma,
        tuNgayUtc: _dauNgayUtc(_tuNgay),
        denNgayUtc: _cuoiNgayUtc(_denNgay),
        skip: 0,
        take: 200,
        peerId: peerId,
        seq: seq,
      );
      if (!mounted) return;
      setState(() {
        _ketQuaLichSu = list;
        _dangTai = false;
      });
    } catch (e, st) {
      final ts = DateTime.now().toUtc().toIso8601String();
      debugPrint(
        'TraCuuDieuChinhApiScreen lichSu peerId=$peerId seq=$seq ts=$ts error=$e stack=$st',
      );
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loiCaNhan = 'Không tải được lịch sử. ${e.toString()}';
      });
    }
  }

  Future<void> _taiDanhSachBuoi() async {
    final buoi = int.tryParse(_maBuoiHocCtl.text.trim());
    if (buoi == null || buoi <= 0) {
      setState(() => _loiBuoi = 'Vui lòng nhập mã buổi học hợp lệ.');
      return;
    }

    final lopTxt = _maLopHocPhanCtl.text.trim();
    final lopId = lopTxt.isEmpty ? null : int.tryParse(lopTxt);
    if (lopTxt.isNotEmpty && lopId == null) {
      setState(() => _loiBuoi = 'Mã lớp học phần không hợp lệ.');
      return;
    }

    setState(() {
      _dangTai = true;
      _loiBuoi = null;
      _ketQuaBuoi = [];
    });

    final peerId = _peerIdOpt();
    final seq = _seqOpt();
    try {
      final list = await _api.getDanhSachDiemDanhBuoiHoc(
        buoi,
        doiTuongLoai: 'SINH_VIEN',
        lopHocPhanId: lopId,
        peerId: peerId,
        seq: seq,
      );
      if (!mounted) return;
      setState(() {
        _ketQuaBuoi = list;
        _dangTai = false;
      });
    } catch (e, st) {
      final ts = DateTime.now().toUtc().toIso8601String();
      debugPrint(
        'TraCuuDieuChinhApiScreen buoi peerId=$peerId seq=$seq ts=$ts error=$e stack=$st',
      );
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loiBuoi = 'Không tải được danh sách. ${e.toString()}';
      });
    }
  }

  void _moChiTiet(DiemDanhBanGhi b) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.sm,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Chi tiết điểm danh', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _dongChiTiet(ctx, 'Mã bản ghi', '${b.id}'),
                _dongChiTiet(ctx, 'Buổi học', '${b.buoiHocId}'),
                _dongChiTiet(ctx, 'Sinh viên (id)', '${b.sinhVienId ?? '—'}'),
                _dongChiTiet(ctx, 'Thời gian', _chuoiThoiGian(b.thoiGianDiemDanh ?? b.ngayTao)),
                _dongChiTiet(ctx, 'Trạng thái', _trangThaiTiengViet(b.trangThai)),
                _dongChiTiet(ctx, 'Nhận diện khuôn mặt',
                    b.diemDanhBangKhuonMat == true ? 'Đạt' : (b.diemDanhBangKhuonMat == false ? 'Không đạt' : '—')),
                _dongChiTiet(ctx, 'Vị trí trong phạm vi',
                    b.diemDanhBangViTri == true ? 'Đạt' : (b.diemDanhBangViTri == false ? 'Không đạt' : '—')),
                const SizedBox(height: AppSpacing.sm),
                Text('Ảnh tại thời điểm điểm danh', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      _anhBanGhiUrl(b.id),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        final ts = DateTime.now().toUtc().toIso8601String();
                        debugPrint(
                          'TraCuuDieuChinhApiScreen anhChiTiet peerId=${_peerIdOpt()} seq=${_seqOpt()} ts=$ts banGhiId=${b.id} error=$error',
                        );
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Text(
                                'Chưa có ảnh hoặc không tải được ảnh.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (b.lyDoDieuChinh != null && b.lyDoDieuChinh!.isNotEmpty)
                  _dongChiTiet(ctx, 'Lý do điều chỉnh', b.lyDoDieuChinh!),
                if (b.ghiChu != null && b.ghiChu!.isNotEmpty)
                  _dongChiTiet(ctx, 'Ghi chú', b.ghiChu!),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _dongChiTiet(BuildContext ctx, String nhan, String giaTri) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              nhan,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(giaTri, style: Theme.of(ctx).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _moHopThoaiDieuChinh(DiemDanhBanGhi b) async {
    final gvCtl = TextEditingController();
    final lyDoCtl = TextEditingController();
    var trangThai = 'THANH_CONG';

    _KetQuaDieuChinhTuHopThoai? ketQua;
    try {
      ketQua = await showDialog<_KetQuaDieuChinhTuHopThoai?>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('Điều chỉnh điểm danh'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sinh viên: ${b.sinhVienId ?? '—'} · Buổi ${b.buoiHocId}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('Trạng thái sau điều chỉnh'),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          FilterChip(
                            label: const Text('Có mặt'),
                            selected: trangThai == 'THANH_CONG',
                            onSelected: (_) => setLocal(() => trangThai = 'THANH_CONG'),
                          ),
                          FilterChip(
                            label: const Text('Vắng'),
                            selected: trangThai == 'THAT_BAI',
                            onSelected: (_) => setLocal(() => trangThai = 'THAT_BAI'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: gvCtl,
                        decoration: const InputDecoration(
                          labelText: 'Mã giảng viên thực hiện',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: lyDoCtl,
                        decoration: const InputDecoration(
                          labelText: 'Lý do (bắt buộc)',
                          border: OutlineInputBorder(),
                          hintText: 'Ví dụ: Có mặt nhưng thiết bị lỗi',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Huỷ'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final gvId = int.tryParse(gvCtl.text.trim());
                      final lyDo = lyDoCtl.text.trim();
                      if (gvId == null || gvId <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập mã giảng viên hợp lệ.')),
                        );
                        return;
                      }
                      if (lyDo.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập lý do điều chỉnh.')),
                        );
                        return;
                      }
                      Navigator.pop(
                        ctx,
                        _KetQuaDieuChinhTuHopThoai(
                          gvId: gvId,
                          lyDo: lyDo,
                          trangThaiMoi: trangThai,
                        ),
                      );
                    },
                    child: const Text('Lưu'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      gvCtl.dispose();
      lyDoCtl.dispose();
    }

    if (ketQua == null || !mounted) return;

    setState(() => _dangTai = true);
    final peerId = _peerIdOpt();
    final seq = _seqOpt();
    try {
      await _api.dieuChinhBanGhiDiemDanh(
        b.id,
        DieuChinhDiemDanhRequest(
          trangThaiMoi: ketQua.trangThaiMoi,
          dieuChinhBoiVienChucId: ketQua.gvId,
          lyDo: ketQua.lyDo,
          peerId: peerId,
          seq: seq,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật điểm danh.')),
      );
      await _taiDanhSachBuoi();
    } catch (e, st) {
      final ts = DateTime.now().toUtc().toIso8601String();
      debugPrint(
        'TraCuuDieuChinhApiScreen dieuChinh peerId=$peerId seq=$seq ts=$ts error=$e stack=$st',
      );
      if (!mounted) return;
      setState(() => _dangTai = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: ${e.toString()}')),
      );
    }
  }

  Widget _theLichSu(DiemDanhBanGhi b) {
    final coMat = b.trangThai == 'THANH_CONG';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _moChiTiet(b),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: coMat
                    ? AppSemantic.successBackground(context)
                    : AppSemantic.errorBackground(context),
                foregroundColor: coMat
                    ? AppSemantic.successForeground(context)
                    : AppSemantic.errorForeground(context),
                child: Text(
                  coMat ? 'C' : 'V',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buổi học ${b.buoiHocId}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _chuoiThoiGian(b.thoiGianDiemDanh ?? b.ngayTao),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _trangThaiTiengViet(b.trangThai),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: coMat
                                ? AppSemantic.successForeground(context)
                                : AppSemantic.errorForeground(context),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _theBuoi(DiemDanhBanGhi b) {
    final coMat = b.trangThai == 'THANH_CONG';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: coMat
                    ? AppSemantic.successBackground(context)
                    : AppSemantic.errorBackground(context),
                foregroundColor: coMat
                    ? AppSemantic.successForeground(context)
                    : AppSemantic.errorForeground(context),
                child: Text('${b.sinhVienId ?? '—'}'),
              ),
              title: Text('MSSV: ${b.sinhVienId ?? '—'}'),
              subtitle: Text(
                '${_trangThaiTiengViet(b.trangThai)} · ${_chuoiThoiGian(b.thoiGianDiemDanh ?? b.ngayTao)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Chi tiết',
                    onPressed: () => _moChiTiet(b),
                    icon: const Icon(Icons.info_outline),
                  ),
                  FilledButton.tonal(
                    onPressed: _dangTai ? null : () => _moHopThoaiDieuChinh(b),
                    child: const Text('Điều chỉnh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử điểm danh'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cá nhân'),
            Tab(text: 'Theo buổi học'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_dangTai) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _tabCaNhan(),
                _tabBuoiHoc(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabCaNhan() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Xem lịch sử điểm danh của một người',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Bạn đang tra cứu cho'),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: true, label: Text('Sinh viên')),
            ButtonSegment<bool>(value: false, label: Text('Giảng viên')),
          ],
          selected: {_laSinhVien},
          onSelectionChanged: _dangTai
              ? null
              : (s) => setState(() {
                    _laSinhVien = s.first;
                  }),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _maCaNhanCtl,
          decoration: InputDecoration(
            labelText: _laSinhVien ? 'Mã số sinh viên (MSSV)' : 'Mã giảng viên',
            hintText: _laSinhVien ? 'Ví dụ: 11088' : 'Ví dụ: 12',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppSectionTitle('Lọc theo ngày (tùy chọn)'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _dangTai ? null : () => _chonNgay(laTuNgay: true),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _tuNgay == null
                      ? 'Từ ngày'
                      : '${_tuNgay!.day}/${_tuNgay!.month}/${_tuNgay!.year}',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _dangTai ? null : () => _chonNgay(laTuNgay: false),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _denNgay == null
                      ? 'Đến ngày'
                      : '${_denNgay!.day}/${_denNgay!.month}/${_denNgay!.year}',
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _dangTai
              ? null
              : () => setState(() {
                    _tuNgay = null;
                    _denNgay = null;
                  }),
          child: const Text('Xóa bộ lọc ngày'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _dangTai ? null : _taiLichSuCaNhan,
          icon: const Icon(Icons.search),
          label: const Text('Xem lịch sử'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loiCaNhan != null)
          AppStatusBanner(
            positive: false,
            child: Text(_loiCaNhan!),
          ),
        if (_ketQuaLichSu.isEmpty && !_dangTai && _loiCaNhan == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(
              'Chưa có dữ liệu. Nhập mã và nhấn «Xem lịch sử».',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ..._ketQuaLichSu.map(_theLichSu),
        ExpansionTile(
          title: const Text('Tùy chọn kỹ thuật'),
          childrenPadding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          children: [
            TextField(
              controller: _peerIdCtl,
              decoration: const InputDecoration(
                labelText: 'peerId (log server)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _seqCtl,
              decoration: const InputDecoration(
                labelText: 'seq (log server)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabBuoiHoc() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Danh sách điểm danh trong một buổi học',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Dùng cho giảng viên: xem sinh viên đã điểm danh và chỉnh sửa khi cần.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _maBuoiHocCtl,
          decoration: const InputDecoration(
            labelText: 'Mã buổi học',
            hintText: 'Bắt buộc',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _maLopHocPhanCtl,
          decoration: const InputDecoration(
            labelText: 'Mã lớp học phần (tùy chọn)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _dangTai ? null : _taiDanhSachBuoi,
          icon: const Icon(Icons.groups),
          label: const Text('Tải danh sách sinh viên'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loiBuoi != null)
          AppStatusBanner(
            positive: false,
            child: Text(_loiBuoi!),
          ),
        if (_ketQuaBuoi.isEmpty && !_dangTai && _loiBuoi == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(
              'Chưa có danh sách. Nhập mã buổi học và nhấn «Tải danh sách».',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ..._ketQuaBuoi.map(_theBuoi),
        ExpansionTile(
          title: const Text('Tùy chọn kỹ thuật'),
          childrenPadding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          children: [
            TextField(
              controller: _peerIdCtl,
              decoration: const InputDecoration(
                labelText: 'peerId (log server)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _seqCtl,
              decoration: const InputDecoration(
                labelText: 'seq (log server)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ],
    );
  }
}

class _KetQuaDieuChinhTuHopThoai {
  _KetQuaDieuChinhTuHopThoai({
    required this.gvId,
    required this.lyDo,
    required this.trangThaiMoi,
  });

  final int gvId;
  final String lyDo;
  final String trangThaiMoi;
}
