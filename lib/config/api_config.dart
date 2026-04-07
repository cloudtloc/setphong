import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Cau hinh API doc tu file [.env] (API_BASE_URL, v.v.).
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    try {
      final v = dotenv.env['API_BASE_URL']?.trim() ?? '';
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    } catch (_) {
      return '';
    }
  }

  static String get googleMapsApiKey {
    try {
      return dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }
}
