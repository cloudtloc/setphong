import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Chất lượng WebP gửi lên server (đồng bộ với kỳ vọng BE lưu `.webp`).
const int kFaceWebpQuality = 82;

/// JPEG trung gian khi đã có khung raster (trước khi nén WebP).
const int kFaceIntermediateJpegQuality = 92;

/// Giải mã ảnh gốc, áp EXIF, rồi nén WebP — base64 thuần (BE đã hỗ trợ data URL).
Future<String?> bytesToBase64Webp(
  Uint8List rawBytes, {
  int quality = kFaceWebpQuality,
}) async {
  final out = await bytesToWebpBytes(rawBytes, quality: quality);
  if (out == null || out.isEmpty) return null;
  return base64Encode(out);
}

/// Giải mã ảnh gốc, áp EXIF, rồi nén WebP — bytes để upload multipart (giảm JSON parse + GC).
Future<Uint8List?> bytesToWebpBytes(
  Uint8List rawBytes, {
  int quality = kFaceWebpQuality,
}) async {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final jpeg = Uint8List.fromList(
    img.encodeJpg(upright, quality: kFaceIntermediateJpegQuality),
  );
  final out = await FlutterImageCompress.compressWithList(
    jpeg,
    quality: quality,
    format: CompressFormat.webp,
  );
  if (out.isEmpty) return null;
  return Uint8List.fromList(out);
}

/// Mã hóa khung ảnh đã crop/resize (package `image`) thành base64 WebP.
Future<String> encodeRasterImageToBase64Webp(
  img.Image image, {
  int quality = kFaceWebpQuality,
}) async {
  final out = await encodeRasterImageToWebpBytes(image, quality: quality);
  return base64Encode(out);
}

/// Mã hóa khung ảnh đã crop/resize (package `image`) thành WebP bytes để upload multipart.
Future<Uint8List> encodeRasterImageToWebpBytes(
  img.Image image, {
  int quality = kFaceWebpQuality,
}) async {
  final jpeg = Uint8List.fromList(
    img.encodeJpg(image, quality: kFaceIntermediateJpegQuality),
  );
  final out = await FlutterImageCompress.compressWithList(
    jpeg,
    quality: quality,
    format: CompressFormat.webp,
  );
  return Uint8List.fromList(out);
}
