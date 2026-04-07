import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image/image.dart' as img;

import '../theme/app_theme.dart';
import '../utils/face_image_webp.dart';

class FaceMeshCaptureResult {
  /// Ảnh crop (WebP bytes) để upload multipart.
  final Uint8List webpFaceCropBytes;
  final String faceMeshJson;

  const FaceMeshCaptureResult({
    required this.webpFaceCropBytes,
    required this.faceMeshJson,
  });
}

class FaceMeshCaptureScreen extends StatefulWidget {
  const FaceMeshCaptureScreen({super.key});

  @override
  State<FaceMeshCaptureScreen> createState() => _FaceMeshCaptureScreenState();
}

class _FaceMeshCaptureScreenState extends State<FaceMeshCaptureScreen> {
  /// MediaPipe Face Mesh: khóe mắt phải / trái (dùng ước lượng góc nghiêng đầu).
  static const int _meshRightEyeOuter = 33;
  static const int _meshLeftEyeOuter = 263;
  static const double _rollCorrectMinAbsDeg = 1.0;
  static const double _rollCorrectMaxAbsDeg = 42.0;

  /// Giới hạn cạnh dài sau crop: đủ chi tiết cho embedding/hiển thị, giảm pixel dư
  /// WebP trên ảnh đã scale hợp lý giảm dung lượng payload.
  static const int _faceCropMaxEdgePx = 512;

  CameraController? _camera;
  bool _cameraLoading = true;

  late final FaceMeshDetector _detector;
  bool _detecting = false;
  bool _streaming = false;

  List<FaceMeshPoint> _points = const [];
  InputImageRotation? _lastRotation;
  CameraLensDirection? _lastLensDirection;
  Size? _lastImageSize;

  String? _message;

  @override
  void initState() {
    super.initState();
    _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
    _initCamera();
  }

  @override
  void dispose() {
    _stopStream();
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _cameraLoading = true;
      _message = null;
    });

    try {
      final cams = await availableCameras();
      final front = cams.cast<CameraDescription?>().firstWhere(
            (c) => c?.lensDirection == CameraLensDirection.front,
            orElse: () => cams.isNotEmpty ? cams.first : null,
          );

      if (front == null) {
        setState(() {
          _cameraLoading = false;
          _message = 'Không tìm thấy camera.';
        });
        return;
      }

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _camera = controller;
        _cameraLoading = false;
      });

      await _startStream();
    } catch (e) {
      setState(() {
        _cameraLoading = false;
        _message = 'Khởi tạo camera thất bại: ${e.toString()}';
      });
    }
  }

  Future<void> _startStream() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (_streaming) return;

    try {
      _streaming = true;
      await cam.startImageStream(_processCameraImage);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _streaming = false;
      setState(() => _message = 'Bật luồng hình thất bại: ${e.toString()}');
    }
  }

  Future<void> _stopStream() async {
    final cam = _camera;
    if (cam == null) return;
    if (!_streaming) return;

    try {
      await cam.stopImageStream();
    } catch (_) {
      // ignore
    } finally {
      _streaming = false;
      _detecting = false;
    }
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    try {
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        var rotationCompensation = _orientations[deviceOrientation];
        if (rotationCompensation == null) return null;

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if ((Platform.isAndroid && format != InputImageFormat.nv21) ||
          (Platform.isIOS && format != InputImageFormat.bgra8888)) {
        return null;
      }

      if (image.planes.length != 1) return null;
      final plane = image.planes.first;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
    } catch (_) {
      return null;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_detecting) return;
    _detecting = true;

    try {
      final cam = _camera;
      if (cam == null) return;

      final input = _inputImageFromCameraImage(
        image,
        cam.description,
        cam.value.deviceOrientation,
      );
      if (input == null) return;

      _lastRotation = input.metadata?.rotation;
      _lastLensDirection = cam.description.lensDirection;
      _lastImageSize = input.metadata?.size;

      final meshes = await _detector.processImage(input);
      if (!mounted) return;

      if (meshes.isEmpty) {
        setState(() => _points = const []);
      } else {
        setState(() => _points = meshes.first.points);
      }
    } finally {
      _detecting = false;
    }
  }

  bool get _qualityOk {
    // Siết chất lượng để bbox khi crop ổn định hơn (tránh trường hợp mặt ở quá xa/nhỏ).
    if (_points.length < 320) return false;
    final size = _lastImageSize;
    if (size == null) return false;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final p in _points) {
      if (p.x < minX) minX = p.x.toDouble();
      if (p.y < minY) minY = p.y.toDouble();
      if (p.x > maxX) maxX = p.x.toDouble();
      if (p.y > maxY) maxY = p.y.toDouble();
    }
    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return false;

    final area = (w * h) / (size.width * size.height);
    // Tăng ngưỡng để đảm bảo vùng mặt chiếm đủ diện tích trong khung.
    return area >= 0.16;
  }

  double _quantile(List<double> values, double q) {
    if (values.isEmpty) return double.nan;
    final sorted = List<double>.from(values)..sort();
    final pos = (sorted.length - 1) * q;
    final base = pos.floor();
    final rest = pos - base;
    if (base >= sorted.length - 1) return sorted.last;
    return sorted[base] + rest * (sorted[base + 1] - sorted[base]);
  }

  /// Góc (độ) của đường nối hai khóe mắt so với trục ngang; dùng để xoay ảnh cho mặt "đứng".
  /// [mirrorX] giống logic mirror khi crop (camera trước, JPEG).
  double? _estimateRollDegreesFromEyes(
    List<FaceMeshPoint> pts,
    double imageWidth,
    bool mirrorX,
  ) {
    if (pts.length <= _meshLeftEyeOuter) return null;
    var xRe = pts[_meshRightEyeOuter].x.toDouble();
    var yRe = pts[_meshRightEyeOuter].y.toDouble();
    var xLe = pts[_meshLeftEyeOuter].x.toDouble();
    var yLe = pts[_meshLeftEyeOuter].y.toDouble();
    if (mirrorX) {
      xRe = imageWidth - xRe;
      xLe = imageWidth - xLe;
    }
    final dx = xLe - xRe;
    final dy = yLe - yRe;
    if (dx * dx + dy * dy < 4.0) return null;
    final deg = math.atan2(dy, dx) * 180.0 / math.pi;
    if (deg.abs() > _rollCorrectMaxAbsDeg) return null;
    return deg;
  }

  Map<String, double>? _buildFaceBboxNormalized({double paddingRatio = 0.20}) {
    if (_points.isEmpty) return null;
    final size = _lastImageSize;
    if (size == null || size.width <= 0 || size.height <= 0) return null;

    // Dùng biên theo phân vị để giảm outlier làm bbox bị "phình" ra.
    final xs = <double>[];
    final ys = <double>[];
    for (final p in _points) {
      xs.add(p.x.toDouble());
      ys.add(p.y.toDouble());
    }
    final minX = _quantile(xs, 0.01);
    final maxX = _quantile(xs, 0.99);
    final minY = _quantile(ys, 0.01);
    final maxY = _quantile(ys, 0.99);

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }

    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return null;

    final side = w * paddingRatio * 1.35;
    final top = h * paddingRatio * 2.2;
    final bottom = h * paddingRatio * 1.15;

    final left = (minX - side).clamp(0.0, size.width);
    final topY = (minY - top).clamp(0.0, size.height);
    final right = (maxX + side).clamp(0.0, size.width);
    final bottomY = (maxY + bottom).clamp(0.0, size.height);

    final bw = (right - left).clamp(0.0, size.width);
    final bh = (bottomY - topY).clamp(0.0, size.height);
    if (bw <= 1 || bh <= 1) return null;

    return {
      'x': (left / size.width).clamp(0.0, 1.0),
      'y': (topY / size.height).clamp(0.0, 1.0),
      'w': (bw / size.width).clamp(0.0, 1.0),
      'h': (bh / size.height).clamp(0.0, 1.0),
    };
  }

  Map<String, double>? _getUprightFaceBbox({
    double paddingRatio = 0.20,
    bool isFrontCamera = false,
  }) {
    if (_points.isEmpty) return null;
    final size = _lastImageSize;
    if (size == null || size.width <= 0 || size.height <= 0) return null;

    final rot = _lastRotation ?? InputImageRotation.rotation0deg;
    double rawW = size.width;
    double rawH = size.height;

    double uprightW = rawW;
    double uprightH = rawH;
    if (rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg) {
      uprightW = rawH;
      uprightH = rawW;
    }

    // Dùng phân vị để giảm outlier làm bbox bị phình.
    final xs = <double>[];
    final ys = <double>[];

    for (final p in _points) {
      double pX = p.x.toDouble();
      double pY = p.y.toDouble();

      double rx = pX;
      double ry = pY;

      if (rot == InputImageRotation.rotation90deg) {
        rx = pY;
        ry = rawW - pX;
      } else if (rot == InputImageRotation.rotation180deg) {
        rx = rawW - pX;
        ry = rawH - pY;
      } else if (rot == InputImageRotation.rotation270deg) {
        rx = rawH - pY;
        ry = pX;
      }

      // Khi dùng camera trước, hệ tọa độ JPEG thường đã mirror ngang,
      // nên cần mirror lại theo trục X để bbox khớp ảnh crop.
      if (isFrontCamera) {
        rx = uprightW - rx;
      }

      xs.add(rx);
      ys.add(ry);
    }

    final minX = _quantile(xs, 0.01);
    final maxX = _quantile(xs, 0.99);
    final minY = _quantile(ys, 0.01);
    final maxY = _quantile(ys, 0.99);

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }

    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return null;

    final side = w * paddingRatio * 1.35;
    final top = h * paddingRatio * 2.2;
    final bottom = h * paddingRatio * 1.15;

    final left = (minX - side).clamp(0.0, uprightW);
    final topY = (minY - top).clamp(0.0, uprightH);
    final right = (maxX + side).clamp(0.0, uprightW);
    final bottomY = (maxY + bottom).clamp(0.0, uprightH);

    final bw = (right - left).clamp(0.0, uprightW);
    final bh = (bottomY - topY).clamp(0.0, uprightH);
    if (bw <= 1 || bh <= 1) return null;

    return {
      'x': (left / uprightW).clamp(0.0, 1.0),
      'y': (topY / uprightH).clamp(0.0, 1.0),
      'w': (bw / uprightW).clamp(0.0, 1.0),
      'h': (bh / uprightH).clamp(0.0, 1.0),
    };
  }

  String _buildFaceMeshJson() {
    final size = _lastImageSize ?? const Size(1, 1);
    final w = size.width == 0 ? 1 : size.width;
    final h = size.height == 0 ? 1 : size.height;

    final points = _points
        .map((p) => {
              'x': (p.x / w).clamp(0, 1),
              'y': (p.y / h).clamp(0, 1),
              'z': p.z,
            })
        .toList();
    return jsonEncode({
      'rotation': _lastRotation?.rawValue,
      'lens': _lastLensDirection?.name,
      'points': points,
      'bbox': _buildFaceBboxNormalized(),
    });
  }

  Future<void> _capture() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (!_qualityOk) {
      setState(() => _message =
          'Chất lượng khuôn mặt chưa đạt. Hãy căn mặt to, đủ sáng và giữ máy ổn định.');
      return;
    }

    try {
      await _stopStream();
      final file = await cam.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final meshJson = _buildFaceMeshJson();

      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        setState(() => _message = 'Không thể xử lý ảnh để cắt khuôn mặt.');
        await _startStream();
        return;
      }

      // Xoay ảnh về đúng chiều upright theo EXIF (ảnh thư viện / một số máy).
      decoded = img.bakeOrientation(decoded);

      final isFront = cam.description.lensDirection == CameraLensDirection.front;
      final uprightFile = File('${file.path}_upright.jpg');

      img.Image imageForCrop = decoded;
      Map<String, double>? bbox;

      try {
        await uprightFile.writeAsBytes(img.encodeJpg(decoded, quality: 92));
        var meshesForCrop =
            await _detector.processImage(InputImage.fromFilePath(uprightFile.path));

        if (meshesForCrop.isNotEmpty) {
          final pts0 = meshesForCrop.first.points;
          final rollDeg = _estimateRollDegreesFromEyes(
            pts0,
            decoded.width.toDouble(),
            isFront,
          );

          if (rollDeg != null &&
              rollDeg.abs() >= _rollCorrectMinAbsDeg &&
              rollDeg.abs() <= _rollCorrectMaxAbsDeg) {
            final rotated = img.copyRotate(
              decoded,
              angle: -rollDeg,
              interpolation: img.Interpolation.linear,
            );
            await uprightFile.writeAsBytes(img.encodeJpg(rotated, quality: 92));
            meshesForCrop =
                await _detector.processImage(InputImage.fromFilePath(uprightFile.path));
            if (meshesForCrop.isNotEmpty) {
              imageForCrop = rotated;
            } else {
              debugPrint(
                'FaceMeshCapture: seq=capture rollDeg=${rollDeg.toStringAsFixed(2)} '
                'reprocessEmpty=true timestamp=${DateTime.now().toIso8601String()}',
              );
              imageForCrop = decoded;
              await uprightFile.writeAsBytes(img.encodeJpg(decoded, quality: 92));
              meshesForCrop =
                  await _detector.processImage(InputImage.fromFilePath(uprightFile.path));
            }
          }
        }

        if (meshesForCrop.isNotEmpty) {
          bbox = _computeBboxFromPoints(
            meshesForCrop.first.points,
            Size(
              imageForCrop.width.toDouble(),
              imageForCrop.height.toDouble(),
            ),
            isFrontCamera: isFront,
          );
        }
      } finally {
        try {
          await uprightFile.delete();
        } catch (_) {}
      }

      bbox ??= _getUprightFaceBbox(
        paddingRatio: 0.22,
        isFrontCamera: isFront,
      );

      if (bbox == null) {
        setState(() => _message = 'Không tìm thấy vùng khuôn mặt để cắt ảnh.');
        await _startStream();
        return;
      }

      final x = (bbox['x']! * imageForCrop.width).round().clamp(0, imageForCrop.width - 1);
      final y = (bbox['y']! * imageForCrop.height).round().clamp(0, imageForCrop.height - 1);
      final w = (bbox['w']! * imageForCrop.width).round().clamp(1, imageForCrop.width);
      final h = (bbox['h']! * imageForCrop.height).round().clamp(1, imageForCrop.height);
      final cropW = (x + w > imageForCrop.width) ? (imageForCrop.width - x) : w;
      final cropH = (y + h > imageForCrop.height) ? (imageForCrop.height - y) : h;

      final cropped = img.copyCrop(
        imageForCrop,
        x: x,
        y: y,
        width: cropW,
        height: cropH,
      );

      img.Image toEncode = cropped;
      final maxEdge = math.max(cropped.width, cropped.height);
      if (maxEdge > _faceCropMaxEdgePx) {
        final scale = _faceCropMaxEdgePx / maxEdge;
        final newW = math.max(1, (cropped.width * scale).round());
        final newH = math.max(1, (cropped.height * scale).round());
        toEncode = img.copyResize(
          cropped,
          width: newW,
          height: newH,
          interpolation: img.Interpolation.cubic,
        );
      }

      final webpBytes = await encodeRasterImageToWebpBytes(
        toEncode,
        quality: kFaceWebpQuality,
      );
      debugPrint(
        'FaceMeshCapture: seq=encode faceCrop webpBytesLen=${webpBytes.length} '
        'crop=${cropped.width}x${cropped.height} out=${toEncode.width}x${toEncode.height} '
        'timestamp=${DateTime.now().toIso8601String()}',
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        FaceMeshCaptureResult(
          webpFaceCropBytes: webpBytes,
          faceMeshJson: meshJson,
        ),
      );
    } catch (e) {
      setState(() => _message = 'Chụp ảnh thất bại: ${e.toString()}');
      await _startStream();
    }
  }

  /// Tính bbox từ danh sách điểm trên ảnh đã upright (có thể đã xoay thẳng theo mắt).
  /// Padding không đối xứng: phía trên rộng hơn để gồm trán/tóc; hai bên đủ cho tai.
  Map<String, double>? _computeBboxFromPoints(
    List<FaceMeshPoint> pts,
    Size imageSize, {
    bool isFrontCamera = false,
    double qLow = 0.01,
    double qHigh = 0.99,
    double basePadding = 0.22,
  }) {
    if (pts.isEmpty) return null;
    if (imageSize.width <= 0 || imageSize.height <= 0) return null;

    final xs = <double>[];
    final ys = <double>[];

    for (final p in pts) {
      double px = p.x.toDouble();
      final py = p.y.toDouble();

      if (isFrontCamera) {
        px = imageSize.width - px;
      }

      xs.add(px);
      ys.add(py);
    }

    final minX = _quantile(xs, qLow);
    final maxX = _quantile(xs, qHigh);
    final minY = _quantile(ys, qLow);
    final maxY = _quantile(ys, qHigh);

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }

    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return null;

    final side = w * basePadding * 1.35;
    final top = h * basePadding * 2.2;
    final bottom = h * basePadding * 1.15;

    final left = (minX - side).clamp(0.0, imageSize.width);
    final topY = (minY - top).clamp(0.0, imageSize.height);
    final right = (maxX + side).clamp(0.0, imageSize.width);
    final bottomY = (maxY + bottom).clamp(0.0, imageSize.height);

    final bw = (right - left).clamp(0.0, imageSize.width);
    final bh = (bottomY - topY).clamp(0.0, imageSize.height);
    if (bw <= 1 || bh <= 1) return null;

    return {
      'x': (left / imageSize.width).clamp(0.0, 1.0),
      'y': (topY / imageSize.height).clamp(0.0, 1.0),
      'w': (bw / imageSize.width).clamp(0.0, 1.0),
      'h': (bh / imageSize.height).clamp(0.0, 1.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chụp ảnh khuôn mặt'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chất lượng khung hình',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _qualityOk ? 'Đạt yêu cầu' : 'Chưa đạt — lại gần camera và giữ ổn định',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _qualityOk
                    ? AppSemantic.successForeground(context)
                    : AppSemantic.warningForeground(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Số điểm mesh: ${_points.length}',
              style: theme.textTheme.bodySmall,
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  color: Colors.black,
                  child: _cameraLoading
                      ? const Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : cam == null || !cam.value.isInitialized
                          ? const Center(child: Text('Không thể mở camera.'))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final canvasSize = Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Render preview theo BoxFit.cover để fill khung
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: cam.value.previewSize?.height ?? 1,
                                        height: cam.value.previewSize?.width ?? 1,
                                        child: CameraPreview(cam),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _FaceMeshPainter(
                                          points: _points,
                                          canvasSize: canvasSize,
                                          // Dùng kích thước theo đúng preview đang hiển thị (đã swap w/h ở SizedBox)
                                          // để tránh lệch khi camera ở chiều dọc.
                                          imageSize: Size(
                                            cam.value.previewSize?.height ?? 1,
                                            cam.value.previewSize?.width ?? 1,
                                          ),
                                          rotation: _lastRotation,
                                          lensDirection: _lastLensDirection ??
                                              cam.description.lensDirection,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: _capture,
              child: const Text('Chụp và dùng ảnh này'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceMeshPainter extends CustomPainter {
  final List<FaceMeshPoint> points;
  final Size canvasSize;
  final Size imageSize;
  final InputImageRotation? rotation;
  final CameraLensDirection lensDirection;

  _FaceMeshPainter({
    required this.points,
    required this.canvasSize,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.fill;

    final r = math.max(1.2, math.min(canvasSize.width, canvasSize.height) / 320);

    // Khi preview đang ở chiều dọc, `CameraPreview` đã xoay ảnh về đúng chiều hiển thị.
    // Nếu tiếp tục xoay điểm theo rotation metadata sẽ dễ bị lệch.
    final bool isPortraitPreview = canvasSize.height >= canvasSize.width;
    final rot = isPortraitPreview
        ? InputImageRotation.rotation0deg
        : (rotation ?? InputImageRotation.rotation0deg);
    final double rawW = imageSize.width == 0 ? 1.0 : imageSize.width;
    final double rawH = imageSize.height == 0 ? 1.0 : imageSize.height;

    double rotatedW = rawW;
    double rotatedH = rawH;
    if (rot == InputImageRotation.rotation90deg ||
        rot == InputImageRotation.rotation270deg) {
      rotatedW = rawH;
      rotatedH = rawW;
    }

    // preview đang BoxFit.cover => scale lớn nhất và center-crop
    final scale = math.max(
      canvasSize.width / (rotatedW == 0 ? 1.0 : rotatedW),
      canvasSize.height / (rotatedH == 0 ? 1.0 : rotatedH),
    );
    final dx = (canvasSize.width - rotatedW * scale) / 2.0;
    final dy = (canvasSize.height - rotatedH * scale) / 2.0;

    for (final p in points) {
      final x = p.x.toDouble();
      final y = p.y.toDouble();

      // chuẩn hoá về hệ toạ độ đã xoay để khớp với preview
      double rx = x;
      double ry = y;
      if (rot == InputImageRotation.rotation90deg) {
        rx = y;
        ry = rawW - x;
      } else if (rot == InputImageRotation.rotation180deg) {
        rx = rawW - x;
        ry = rawH - y;
      } else if (rot == InputImageRotation.rotation270deg) {
        rx = rawH - y;
        ry = x;
      }

      var cx = rx * scale + dx;
      var cy = ry * scale + dy;

      // Camera trước thường có hiệu ứng lật gương ở preview, nên cần mirror điểm để khớp overlay.
      if (lensDirection == CameraLensDirection.front) {
        cx = canvasSize.width - cx;
      }

      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceMeshPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.imageSize != imageSize;
  }
}

