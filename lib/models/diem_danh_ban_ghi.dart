/// Ban ghi tong hop diem danh theo buoi (API tra ve camelCase).
class DiemDanhBanGhi {
  final int id;
  final int buoiHocId;
  final String? doiTuongLoai;
  final int? sinhVienId;
  final int? vienChucId;
  final DateTime? thoiGianDiemDanh;
  final bool? diemDanhBangKhuonMat;
  final bool? diemDanhBangViTri;
  final int? diemDanhThietBiId;
  final int? logIdChinh;
  final String? trangThai;
  final String? ghiChu;
  final int? dieuChinhBoiVienChucId;
  final String? lyDoDieuChinh;
  final DateTime? thoiGianDieuChinh;
  final DateTime? ngayTao;
  final DateTime? ngayCapNhat;

  DiemDanhBanGhi({
    required this.id,
    required this.buoiHocId,
    this.doiTuongLoai,
    this.sinhVienId,
    this.vienChucId,
    this.thoiGianDiemDanh,
    this.diemDanhBangKhuonMat,
    this.diemDanhBangViTri,
    this.diemDanhThietBiId,
    this.logIdChinh,
    this.trangThai,
    this.ghiChu,
    this.dieuChinhBoiVienChucId,
    this.lyDoDieuChinh,
    this.thoiGianDieuChinh,
    this.ngayTao,
    this.ngayCapNhat,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory DiemDanhBanGhi.fromJson(Map<String, dynamic> json) {
    return DiemDanhBanGhi(
      id: json['id'] as int,
      buoiHocId: json['buoiHocId'] as int,
      doiTuongLoai: json['doiTuongLoai'] as String?,
      sinhVienId: json['sinhVienId'] as int?,
      vienChucId: json['vienChucId'] as int?,
      thoiGianDiemDanh: _parseDate(json['thoiGianDiemDanh']),
      diemDanhBangKhuonMat: json['diemDanhBangKhuonMat'] as bool?,
      diemDanhBangViTri: json['diemDanhBangViTri'] as bool?,
      diemDanhThietBiId: json['diemDanhThietBiId'] as int?,
      logIdChinh: json['logIdChinh'] as int?,
      trangThai: json['trangThai'] as String?,
      ghiChu: json['ghiChu'] as String?,
      dieuChinhBoiVienChucId: json['dieuChinhBoiVienChucId'] as int?,
      lyDoDieuChinh: json['lyDoDieuChinh'] as String?,
      thoiGianDieuChinh: _parseDate(json['thoiGianDieuChinh']),
      ngayTao: _parseDate(json['ngayTao']),
      ngayCapNhat: _parseDate(json['ngayCapNhat']),
    );
  }
}

/// Body PUT dieu chinh diem danh.
class DieuChinhDiemDanhRequest {
  final String trangThaiMoi;
  final int dieuChinhBoiVienChucId;
  final String lyDo;
  final String? ghiChuBoSung;
  final String? peerId;
  final int? seq;

  DieuChinhDiemDanhRequest({
    required this.trangThaiMoi,
    required this.dieuChinhBoiVienChucId,
    required this.lyDo,
    this.ghiChuBoSung,
    this.peerId,
    this.seq,
  });

  Map<String, dynamic> toJson() => {
        'trangThaiMoi': trangThaiMoi,
        'dieuChinhBoiVienChucId': dieuChinhBoiVienChucId,
        'lyDo': lyDo,
        if (ghiChuBoSung != null) 'ghiChuBoSung': ghiChuBoSung,
        if (peerId != null) 'peerId': peerId,
        if (seq != null) 'seq': seq,
      };
}
