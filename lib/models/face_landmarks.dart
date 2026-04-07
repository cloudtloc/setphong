class FaceLandmarksPoint {
  final double x;
  final double y;

  const FaceLandmarksPoint({
    required this.x,
    required this.y,
  });

  factory FaceLandmarksPoint.fromJson(Map<String, dynamic> json) {
    return FaceLandmarksPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

class FaceLandmarksResponse {
  final int dangKyKhuonMatId;
  final List<FaceLandmarksPoint> landmarks;

  const FaceLandmarksResponse({
    required this.dangKyKhuonMatId,
    required this.landmarks,
  });

  factory FaceLandmarksResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['landmarks'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => FaceLandmarksPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return FaceLandmarksResponse(
      dangKyKhuonMatId: json['dangKyKhuonMatId'] as int,
      landmarks: list,
    );
  }
}

