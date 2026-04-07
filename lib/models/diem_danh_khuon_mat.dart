/// Request gui len POST api/diemdanh.
class DiemDanhKhuonMatRequest {
  String? doiTuongLoai;
  int? sinhVienId;
  int? vienChucId;
  int buoiHocId;
  int? lopHocPhanId;
  int? phongId;
  double? longThietBi;
  double? latThietBi;
  int? thietBiId;
  String? wifiSsidThoiDiem;
  String? wifiBssidThoiDiem;
  String? diaChiIpThoiDiem;
  String? anhChupThoiDiem;
  String? faceProvider;
  String? faceMeshJson;
  String? peerId;
  int? seq;

  DiemDanhKhuonMatRequest({
    this.doiTuongLoai,
    this.sinhVienId,
    this.vienChucId,
    required this.buoiHocId,
    this.lopHocPhanId,
    this.phongId,
    this.longThietBi,
    this.latThietBi,
    this.thietBiId,
    this.wifiSsidThoiDiem,
    this.wifiBssidThoiDiem,
    this.diaChiIpThoiDiem,
    this.anhChupThoiDiem,
    this.faceProvider,
    this.faceMeshJson,
    this.peerId,
    this.seq,
  });

  Map<String, dynamic> toJson() {
    return {
      'doiTuongLoai': doiTuongLoai,
      'sinhVienId': sinhVienId,
      'vienChucId': vienChucId,
      'buoiHocId': buoiHocId,
      'lopHocPhanId': lopHocPhanId,
      'phongId': phongId,
      'longThietBi': longThietBi,
      'latThietBi': latThietBi,
      'thietBiId': thietBiId,
      'wifiSsidThoiDiem': wifiSsidThoiDiem,
      'wifiBssidThoiDiem': wifiBssidThoiDiem,
      'diaChiIpThoiDiem': diaChiIpThoiDiem,
      'anhChupThoiDiem': anhChupThoiDiem,
      'faceProvider': faceProvider,
      'faceMeshJson': faceMeshJson,
      'peerId': peerId,
      'seq': seq,
    };
  }
}

/// Response tu POST api/diemdanh.
class DiemDanhKhuonMatResponse {
  bool thanhCong;
  String? thongDiep;
  double? doTinCayNhanDien;
  double? saiSoViTri;
  bool? hopLeViTri;
  bool? hopLeKhuonMat;
  int? dangKyKhuonMatId;
  int? logId;

  DiemDanhKhuonMatResponse({
    required this.thanhCong,
    this.thongDiep,
    this.doTinCayNhanDien,
    this.saiSoViTri,
    this.hopLeViTri,
    this.hopLeKhuonMat,
    this.dangKyKhuonMatId,
    this.logId,
  });

  factory DiemDanhKhuonMatResponse.fromJson(Map<String, dynamic> json) {
    return DiemDanhKhuonMatResponse(
      thanhCong: json['thanhCong'] as bool? ?? false,
      thongDiep: json['thongDiep'] as String?,
      doTinCayNhanDien:
          (json['doTinCayNhanDien'] as num?)?.toDouble(),
      saiSoViTri: (json['saiSoViTri'] as num?)?.toDouble(),
      hopLeViTri: json['hopLeViTri'] as bool?,
      hopLeKhuonMat: json['hopLeKhuonMat'] as bool?,
      dangKyKhuonMatId: json['dangKyKhuonMatId'] as int?,
      logId: json['logId'] as int?,
    );
  }
}
