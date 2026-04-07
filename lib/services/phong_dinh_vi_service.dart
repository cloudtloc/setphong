import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/phong_dinh_vi.dart';

class PhongDinhViService {
  static const String _base = apiBaseUrl;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Ngrok-Skip-Browser-Warning': 'true',
      };

  Future<PhongDinhVi> createPhong(PhongDinhVi request) async {
    final resp = await http.post(
      Uri.parse('$_base/api/PhongDinhVi'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );
    if (resp.statusCode != 201) {
      throw Exception(_tryParseMessage(resp.body) ??
          resp.reasonPhrase ??
          'Loi ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return PhongDinhVi.fromJson(data);
  }

  Future<PhongDinhVi?> getPhong(int phongId) async {
    final resp = await http.get(
      Uri.parse('$_base/api/PhongDinhVi/$phongId'),
      headers: _headers,
    );
    if (resp.statusCode == 404) {
      return null;
    }
    if (resp.statusCode != 200) {
      throw Exception(_tryParseMessage(resp.body) ??
          resp.reasonPhrase ??
          'Loi ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return PhongDinhVi.fromJson(data);
  }

  Future<void> updateLocation({
    required int phongId,
    required double long,
    required double lat,
    required double? banKinh,
  }) async {
    final body = {
      'phongId': phongId,
      'long': long,
      'lat': lat,
      'banKinh': banKinh,
    };
    final resp = await http.put(
      Uri.parse('$_base/api/PhongDinhVi/$phongId/location'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (resp.statusCode != 204) {
      throw Exception(_tryParseMessage(resp.body) ??
          resp.reasonPhrase ??
          'Loi ${resp.statusCode}');
    }
  }

  static String? _tryParseMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map) {
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

