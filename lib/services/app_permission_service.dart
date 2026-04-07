import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  Future<bool> requestAll() async {
    try {
      final List<Permission> permissions = [
        Permission.camera,
        Permission.locationWhenInUse,
      ];

      if (defaultTargetPlatform == TargetPlatform.android) {
        permissions.add(Permission.storage);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        permissions.add(Permission.photos);
      }

      await permissions.request();

      return await isEssentialGranted();
    } catch (e) {
      debugPrint('Request permissions error: $e');
      return false;
    }
  }

  Future<bool> isEssentialGranted() async {
    try {
      final camera = await Permission.camera.status;
      final location = await Permission.locationWhenInUse.status;

      final bool mediaOk;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final storage = await Permission.storage.status;
        mediaOk = storage.isGranted || storage.isLimited;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final photos = await Permission.photos.status;
        mediaOk = photos.isGranted || photos.isLimited;
      } else {
        mediaOk = true;
      }

      final ok = (camera.isGranted || camera.isLimited) &&
          (location.isGranted || location.isLimited) &&
          mediaOk;

      debugPrint(
        'Permission status camera=$camera location=$location mediaOk=$mediaOk ok=$ok',
      );

      return ok;
    } catch (e) {
      debugPrint('Check permissions error: $e');
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Open app settings error: $e');
    }
  }
}

