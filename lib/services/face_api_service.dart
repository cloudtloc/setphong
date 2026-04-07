import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/diem_danh_ban_ghi.dart';
import '../models/diem_danh_khuon_mat.dart';

/// Client goi API diem danh / dieu chinh (duong dan mac dinh co the doi o backend).
class FaceApiService {
  FaceApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl;
    if (base.isEmpty) {
      throw Exception('Chua cau hinh API_BASE_URL trong file .env');
    }
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
  }

  static List<dynamic> _decodeListBody(String body) {
    final d = jsonDecode(body);
    if (d is List<dynamic>) return d;
    if (d is Map<String, dynamic>) {
      final items =
          d['items'] ?? d['data'] ?? d['content'] ?? d['danhSach'];
      if (items is List<dynamic>) return items;
    }
    throw FormatException('Khong parse duoc danh sach tu JSON');
  }

  String getAnhDiemDanhBanGhiUrl(
    int banGhiId, {
    String? peerId,
    int? seq,
  }) {
    final q = <String, String>{};
    if (peerId != null && peerId.isNotEmpty) {
      q['peerId'] = peerId;
    }
    if (seq != null) {
      q['seq'] = '$seq';
    }
    return _uri('/api/diem-danh/ban-ghi/$banGhiId/anh', q).toString();
  }

  Future<List<DiemDanhBanGhi>> getLichSuDiemDanhCaNhan({
    required String doiTuongLoai,
    int? sinhVienId,
    int? vienChucId,
    DateTime? tuNgayUtc,
    DateTime? denNgayUtc,
    required int skip,
    required int take,
    String? peerId,
    int? seq,
  }) async {
    final q = <String, String>{
      'doiTuongLoai': doiTuongLoai,
      'skip': '$skip',
      'take': '$take',
    };
    if (sinhVienId != null) {
      q['sinhVienId'] = '$sinhVienId';
    }
    if (vienChucId != null) {
      q['vienChucId'] = '$vienChucId';
    }
    if (tuNgayUtc != null) {
      q['tuNgay'] = tuNgayUtc.toIso8601String();
    }
    if (denNgayUtc != null) {
      q['denNgay'] = denNgayUtc.toIso8601String();
    }
    if (peerId != null && peerId.isNotEmpty) {
      q['peerId'] = peerId;
    }
    if (seq != null) {
      q['seq'] = '$seq';
    }

    final res = await _client.get(_uri('/api/diem-danh/lich-su', q));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'getLichSuDiemDanhCaNhan HTTP ${res.statusCode} body=${res.body}',
      );
    }
    final raw = _decodeListBody(res.body);
    return raw
        .map((e) => DiemDanhBanGhi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DiemDanhBanGhi>> getDanhSachDiemDanhBuoiHoc(
    int buoiHocId, {
    required String doiTuongLoai,
    int? lopHocPhanId,
    String? peerId,
    int? seq,
  }) async {
    final q = <String, String>{
      'doiTuongLoai': doiTuongLoai,
    };
    if (lopHocPhanId != null) {
      q['lopHocPhanId'] = '$lopHocPhanId';
    }
    if (peerId != null && peerId.isNotEmpty) {
      q['peerId'] = peerId;
    }
    if (seq != null) {
      q['seq'] = '$seq';
    }

    final res = await _client.get(
      _uri('/api/diem-danh/buoi-hoc/$buoiHocId/danh-sach', q),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'getDanhSachDiemDanhBuoiHoc HTTP ${res.statusCode} body=${res.body}',
      );
    }
    final raw = _decodeListBody(res.body);
    return raw
        .map((e) => DiemDanhBanGhi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> dieuChinhBanGhiDiemDanh(
    int banGhiId,
    DieuChinhDiemDanhRequest body,
  ) async {
    final res = await _client.put(
      _uri('/api/diem-danh/ban-ghi/$banGhiId'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'dieuChinhBanGhiDiemDanh HTTP ${res.statusCode} body=${res.body}',
      );
    }
  }

  Future<DiemDanhKhuonMatResponse> diemDanhKhuonMatMultipart({
    required DiemDanhKhuonMatRequest request,
    required Uint8List webpBytes,
  }) async {
    final uri = _uri('/api/diem-danh/khuon-mat');
    final req = http.MultipartRequest('POST', uri);
    for (final e in request.toFieldMap().entries) {
      req.fields[e.key] = e.value;
    }
    req.files.add(
      http.MultipartFile.fromBytes(
        'anhWebp',
        webpBytes,
        filename: 'face.webp',
      ),
    );

    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'diemDanhKhuonMatMultipart HTTP ${res.statusCode} body=${res.body}',
      );
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return DiemDanhKhuonMatResponse.fromJson(map);
  }
}
