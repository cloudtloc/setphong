/// Model dang ky khuon mat - khop voi backend DangKyKhuonMat.
class DangKyKhuonMat {
  int? id;
  String? doiTuongLoai;
  int? sinhVienId;
  int? vienChucId;
  /// URL/đường dẫn ảnh hiển thị (đã crop + nén) do server lưu.
  String? hinhAnhNguon;

  /// Base64 ảnh dùng để so sánh (đã crop khuôn mặt). Chỉ dùng khi tạo mới.
  String? hinhAnhSoSanhBase64;
  String? faceTemplatePath;
  String? landmarksJson;
  String? faceMeshJson;
  String? faceProvider;
  double? doTinCayMacDinh;
  int? thietBiId;
  String? wifiSsidDangKy;
  String? wifiBssidDangKy;
  String? diaChiIpDangKy;
  double? longDangKy;
  double? latDangKy;
  bool? isActive;
  DateTime? ngayHieuLucTu;
  DateTime? ngayHieuLucDen;
  DateTime? ngayTao;
  DateTime? ngayCapNhat;

  DangKyKhuonMat({
    this.id,
    this.doiTuongLoai,
    this.sinhVienId,
    this.vienChucId,
    this.hinhAnhNguon,
    this.hinhAnhSoSanhBase64,
    this.faceTemplatePath,
    this.landmarksJson,
    this.faceMeshJson,
    this.faceProvider,
    this.doTinCayMacDinh,
    this.thietBiId,
    this.wifiSsidDangKy,
    this.wifiBssidDangKy,
    this.diaChiIpDangKy,
    this.longDangKy,
    this.latDangKy,
    this.isActive,
    this.ngayHieuLucTu,
    this.ngayHieuLucDen,
    this.ngayTao,
    this.ngayCapNhat,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      // Khi tao moi, khong gui 'id' neu null de tranh loi parse int ben backend
      if (id != null) 'id': id,
      'doiTuongLoai': doiTuongLoai,
      'sinhVienId': sinhVienId,
      'vienChucId': vienChucId,
      // Lưu 1 ảnh duy nhất khi tạo mới: server dùng ảnh này để sinh embedding và lưu hiển thị.
      'hinhAnhSoSanhBase64': hinhAnhSoSanhBase64,

      // Giữ lại để tương thích khi đọc từ server (server trả về URL)
      'hinhAnhNguon': hinhAnhNguon,
      'faceTemplatePath': faceTemplatePath,
      'landmarksJson': landmarksJson,
      'faceMeshJson': faceMeshJson,
      'faceProvider': faceProvider,
      'doTinCayMacDinh': doTinCayMacDinh,
      'thietBiId': thietBiId,
      'wifiSsidDangKy': wifiSsidDangKy,
      'wifiBssidDangKy': wifiBssidDangKy,
      'diaChiIpDangKy': diaChiIpDangKy,
      'longDangKy': longDangKy,
      'latDangKy': latDangKy,
      'isActive': isActive,
      'ngayHieuLucTu': ngayHieuLucTu?.toIso8601String(),
      'ngayHieuLucDen': ngayHieuLucDen?.toIso8601String(),
      'ngayTao': ngayTao?.toIso8601String(),
      'ngayCapNhat': ngayCapNhat?.toIso8601String(),
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }

  factory DangKyKhuonMat.fromJson(Map<String, dynamic> json) {
    return DangKyKhuonMat(
      id: json['id'] as int?,
      doiTuongLoai: json['doiTuongLoai'] as String?,
      sinhVienId: json['sinhVienId'] as int?,
      vienChucId: json['vienChucId'] as int?,
      hinhAnhNguon: json['hinhAnhNguon'] as String?,
      // Các field base64 chỉ có khi client gửi lên, server thường không trả về
      hinhAnhSoSanhBase64: json['hinhAnhSoSanhBase64'] as String?,
      faceTemplatePath: json['faceTemplatePath'] as String?,
      landmarksJson: json['landmarksJson'] as String?,
      faceMeshJson: json['faceMeshJson'] as String?,
      faceProvider: json['faceProvider'] as String?,
      doTinCayMacDinh: (json['doTinCayMacDinh'] as num?)?.toDouble(),
      thietBiId: json['thietBiId'] as int?,
      wifiSsidDangKy: json['wifiSsidDangKy'] as String?,
      wifiBssidDangKy: json['wifiBssidDangKy'] as String?,
      diaChiIpDangKy: json['diaChiIpDangKy'] as String?,
      longDangKy: (json['longDangKy'] as num?)?.toDouble(),
      latDangKy: (json['latDangKy'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool?,
      ngayHieuLucTu: json['ngayHieuLucTu'] != null
          ? DateTime.tryParse(json['ngayHieuLucTu'] as String)
          : null,
      ngayHieuLucDen: json['ngayHieuLucDen'] != null
          ? DateTime.tryParse(json['ngayHieuLucDen'] as String)
          : null,
      ngayTao: json['ngayTao'] != null
          ? DateTime.tryParse(json['ngayTao'] as String)
          : null,
      ngayCapNhat: json['ngayCapNhat'] != null
          ? DateTime.tryParse(json['ngayCapNhat'] as String)
          : null,
    );
  }
}
