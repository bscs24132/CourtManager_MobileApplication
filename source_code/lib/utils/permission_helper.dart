// lib/utils/permission_helper.dart

import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestNotificationPermission() async {
    // For Android 13 (API 33) and above, we need to explicitly request notification permission
    final status = await Permission.notification.request();

    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      // Permission denied
      return false;
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, open app settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  static Future<bool> checkNotificationPermission() async {
    return await Permission.notification.isGranted;
  }
}