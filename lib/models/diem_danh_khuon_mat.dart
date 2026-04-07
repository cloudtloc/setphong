/// Request diem danh khuon mat (multipart + metadata).
class DiemDanhKhuonMatRequest {
  const DiemDanhKhuonMatRequest({
    required this.doiTuongLoai,
    this.sinhVienId,
    this.vienChucId,
    required this.buoiHocId,
    this.lopHocPhanId,
    this.phongId,
    this.longThietBi,
    this.latThietBi,
    this.anhChupThoiDiem,
    this.faceMeshJson,
    this.peerId,
    this.seq,
  });

  final String doiTuongLoai;
  final int? sinhVienId;
  final int? vienChucId;
  final int buoiHocId;
  final int? lopHocPhanId;
  final int? phongId;
  final double? longThietBi;
  final double? latThietBi;
  final String? anhChupThoiDiem;
  final String? faceMeshJson;
  final String? peerId;
  final int? seq;

  Map<String, String> toFieldMap() {
    final m = <String, String>{
      'doiTuongLoai': doiTuongLoai,
      'buoiHocId': '$buoiHocId',
    };
    if (sinhVienId != null) m['sinhVienId'] = '$sinhVienId';
    if (vienChucId != null) m['vienChucId'] = '$vienChucId';
    if (lopHocPhanId != null) m['lopHocPhanId'] = '$lopHocPhanId';
    if (phongId != null) m['phongId'] = '$phongId';
    if (longThietBi != null) m['longThietBi'] = '$longThietBi';
    if (latThietBi != null) m['latThietBi'] = '$latThietBi';
    if (anhChupThoiDiem != null) m['anhChupThoiDiem'] = anhChupThoiDiem!;
    if (faceMeshJson != null) m['faceMeshJson'] = faceMeshJson!;
    if (peerId != null) m['peerId'] = peerId!;
    if (seq != null) m['seq'] = '$seq';
    return m;
  }
}

/// Phan hoi API diem danh khuon mat.
class DiemDanhKhuonMatResponse {
  const DiemDanhKhuonMatResponse({
    required this.thanhCong,
    this.doTinCayNhanDien,
    this.saiSoViTri,
    this.hopLeKhuonMat,
    this.hopLeViTri,
  });

  final bool thanhCong;
  final double? doTinCayNhanDien;
  final double? saiSoViTri;
  final bool? hopLeKhuonMat;
  final bool? hopLeViTri;

  factory DiemDanhKhuonMatResponse.fromJson(Map<String, dynamic> json) {
    return DiemDanhKhuonMatResponse(
      thanhCong: json['thanhCong'] as bool? ?? false,
      doTinCayNhanDien: (json['doTinCayNhanDien'] as num?)?.toDouble(),
      saiSoViTri: (json['saiSoViTri'] as num?)?.toDouble(),
      hopLeKhuonMat: json['hopLeKhuonMat'] as bool?,
      hopLeViTri: json['hopLeViTri'] as bool?,
    );
  }
}
