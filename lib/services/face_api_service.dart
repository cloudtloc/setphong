import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/dang_ky_khuon_mat.dart';
import '../models/diem_danh_ban_ghi.dart';
import '../models/diem_danh_khuon_mat.dart';
import '../models/face_landmarks.dart';

/// Service goi API dang ky va diem danh khuon mat.
class FaceApiService {
  static const String _base = apiBaseUrl;

  /// Header cho ngrok (tranh trang interstitial).
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Ngrok-Skip-Browser-Warning': 'true',
      };

  /// POST api/DangKyKhuonMat - dang ky khuon mat (HinhAnhNguon la base64).
  Future<DangKyKhuonMat?> dangKyKhuonMat(DangKyKhuonMat request) async {
    final body = request.toJson();
    final resp = await http.post(
      Uri.parse('$_base/api/DangKyKhuonMat'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (resp.statusCode != 201) {
      final msg = _tryParseMessage(resp.body) ?? resp.reasonPhrase ?? 'Loi ${resp.statusCode}';
      throw Exception(msg);
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return DangKyKhuonMat.fromJson(data);
  }

  /// GET api/DangKyKhuonMat/{id}
  Future<DangKyKhuonMat?> getDangKyById(int id) async {
    final resp = await http.get(
      Uri.parse('$_base/api/DangKyKhuonMat/$id'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return DangKyKhuonMat.fromJson(data);
  }

  /// GET api/DangKyKhuonMat/sinhvien/{sinhVienId}
  Future<List<DangKyKhuonMat>> getDangKyBySinhVien(int sinhVienId) async {
    final resp = await http.get(
      Uri.parse('$_base/api/DangKyKhuonMat/sinhvien/$sinhVienId'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    final list = jsonDecode(resp.body) as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => DangKyKhuonMat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET api/DangKyKhuonMat/vienchuc/{vienChucId}
  Future<List<DangKyKhuonMat>> getDangKyByVienChuc(int vienChucId) async {
    final resp = await http.get(
      Uri.parse('$_base/api/DangKyKhuonMat/vienchuc/$vienChucId'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    final list = jsonDecode(resp.body) as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => DangKyKhuonMat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST api/diemdanh - diem danh (khuon mat + vi tri).
  Future<DiemDanhKhuonMatResponse> diemDanhKhuonMat(
      DiemDanhKhuonMatRequest request) async {
    final resp = await http.post(
      Uri.parse('$_base/api/diemdanh'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (data != null) {
        return DiemDanhKhuonMatResponse.fromJson(data);
      }
    }

    final msg = _tryParseMessage(resp.body) ??
        resp.reasonPhrase ??
        'Loi ${resp.statusCode}';
    debugPrint('diemDanhKhuonMat error: $msg');
    throw Exception(msg);
  }

  /// GET api/diemdanh/landmarks/{dangKyKhuonMatId}
  Future<FaceLandmarksResponse?> getLandmarksByDangKy(int dangKyKhuonMatId) async {
    final resp = await http.get(
      Uri.parse('$_base/api/diemdanh/landmarks/$dangKyKhuonMatId'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return FaceLandmarksResponse.fromJson(data);
  }

  /// URL anh diem danh theo ma ban ghi (query peerId, seq neu co).
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
    return Uri.parse('$_base/api/diemdanh/ban-ghi/$banGhiId/anh')
        .replace(queryParameters: q.isEmpty ? null : q)
        .toString();
  }

  static List<dynamic> _decodeListBody(String body) {
    final d = jsonDecode(body);
    if (d is List<dynamic>) {
      return d;
    }
    if (d is Map<String, dynamic>) {
      final items =
          d['items'] ?? d['data'] ?? d['content'] ?? d['danhSach'];
      if (items is List<dynamic>) {
        return items;
      }
    }
    throw FormatException('Khong parse duoc danh sach tu JSON');
  }

  /// GET lich su diem danh ca nhan (query).
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

    final uri = Uri.parse('$_base/api/diemdanh/lich-su').replace(
      queryParameters: q,
    );
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg = _tryParseMessage(resp.body) ??
          resp.reasonPhrase ??
          'Loi ${resp.statusCode}';
      throw Exception(msg);
    }
    final raw = _decodeListBody(resp.body);
    return raw
        .map((e) => DiemDanhBanGhi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET danh sach diem danh theo buoi hoc.
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

    final uri = Uri.parse('$_base/api/diemdanh/buoi-hoc/$buoiHocId/danh-sach')
        .replace(queryParameters: q);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg = _tryParseMessage(resp.body) ??
          resp.reasonPhrase ??
          'Loi ${resp.statusCode}';
      throw Exception(msg);
    }
    final raw = _decodeListBody(resp.body);
    return raw
        .map((e) => DiemDanhBanGhi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT dieu chinh ban ghi diem danh.
  Future<void> dieuChinhBanGhiDiemDanh(
    int banGhiId,
    DieuChinhDiemDanhRequest body,
  ) async {
    final resp = await http.put(
      Uri.parse('$_base/api/diemdanh/ban-ghi/$banGhiId'),
      headers: {
        ..._headers,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(body.toJson()),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg = _tryParseMessage(resp.body) ??
          resp.reasonPhrase ??
          'Loi ${resp.statusCode}';
      throw Exception(msg);
    }
  }

  static String? _tryParseMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map) {
        // Uu tien hien thi thong tin loi validation chi tiet cua ASP.NET Core
        if (m['errors'] is Map) {
          final errors = m['errors'] as Map;
          final buffer = StringBuffer();
          errors.forEach((key, value) {
            if (buffer.isNotEmpty) buffer.write('\n');
            final msgs = value is List ? value : [value];
            buffer.write('$key: ${msgs.join(', ')}');
          });
          final text = buffer.toString().trim();
          if (text.isNotEmpty) return text;
        }
        if (m['title'] != null) return m['title'] as String?;
        if (m['message'] != null) return m['message'] as String?;
        if (m['detail'] != null) return m['detail'] as String?;
      }
      return m is String ? m : null;
    } catch (_) {
      return body.isNotEmpty ? body : null;
    }
  }
}
