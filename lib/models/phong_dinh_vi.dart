class PhongDinhVi {
  int phongId;
  double? long;
  double? lat;
  double? banKinh;
  int? toaNhaId;
  DateTime? lastSync;

  PhongDinhVi({
    required this.phongId,
    this.long,
    this.lat,
    this.banKinh,
    this.toaNhaId,
    this.lastSync,
  });

  Map<String, dynamic> toJson() {
    return {
      'phongId': phongId,
      'long': long,
      'lat': lat,
      'banKinh': banKinh,
      'toaNhaId': toaNhaId,
      'lastSync': lastSync?.toIso8601String(),
    };
  }

  factory PhongDinhVi.fromJson(Map<String, dynamic> json) {
    return PhongDinhVi(
      phongId: json['phongId'] as int,
      long: (json['long'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      banKinh: (json['banKinh'] as num?)?.toDouble(),
      toaNhaId: json['toaNhaId'] as int?,
      lastSync: json['lastSync'] != null
          ? DateTime.tryParse(json['lastSync'] as String)
          : null,
    );
  }
}

