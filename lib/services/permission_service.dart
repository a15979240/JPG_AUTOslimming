import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// 權限服務
///
/// 處理 Android 儲存空間 / 通知權限請求。
class PermissionService {
  const PermissionService._();

  /// 請求所有需要的權限
  ///
  /// 回傳 true 表示所有必要權限均已授予。
  static Future<bool> requestAllPermissions() async {
    if (!Platform.isAndroid) return true;

    // 同時請求儲存與相片權限（permission_handler 會依 Android 版本自動處理）
    final statuses = await [
      Permission.storage,
      Permission.photos,
      Permission.notification,
    ].request();

    final storageOk = statuses[Permission.storage]?.isGranted == true ||
        statuses[Permission.storage]?.isLimited == true;
    final photosOk = statuses[Permission.photos]?.isGranted == true ||
        statuses[Permission.photos]?.isLimited == true;
    final notificationOk = statuses[Permission.notification]?.isGranted == true ||
        statuses[Permission.notification]?.isProvisional == true ||
        statuses[Permission.notification]?.isLimited == true;

    // 任一儲存相關權限授予即可
    return (storageOk || photosOk) && notificationOk;
  }

  /// 請求通知權限
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted || status.isProvisional || status.isLimited;
  }

  /// 檢查所有權限是否已授予
  static Future<bool> checkAllPermissions() async {
    if (!Platform.isAndroid) return true;

    final storageGranted = await Permission.storage.isGranted;
    final photosGranted = await Permission.photos.isGranted;
    final notificationGranted = await Permission.notification.isGranted;

    return (storageGranted || photosGranted) && notificationGranted;
  }
}
