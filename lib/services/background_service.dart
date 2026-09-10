import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jpg_slimming/models/app_settings.dart';
import 'package:jpg_slimming/models/file_item.dart';
import 'package:jpg_slimming/services/file_service.dart';
import 'package:jpg_slimming/services/image_process_service.dart';
import 'package:workmanager/workmanager.dart';

/// 背景工作任務名稱
const String bgTaskScanAndProcess = 'jpgSlimmingScanAndProcess';
const String bgTaskUniqueName = 'jpgSlimmingBackgroundAuto';

/// 通知 channel 設定（一般通知：背景自動化完成通知等）
const String _notificationChannelId = 'jpg_slimming_bg';
const String _notificationChannelName = 'JPG 瘦身背景處理';
const String _notificationChannelDesc = '背景自動化瘦身處理通知';

/// 狀態通知 channel 設定（低重要性、持續存在、不打擾使用者）
///
/// 用途：在不開啟 App 的情況下，從系統通知列得知目前狀態：
/// - 監控中（即時監測來源資料夾）
/// - 處理中（處理進度：第幾個 / 共幾個）
/// - 已暫停 / 已停止 / 處理完成
const String _statusChannelId = 'jpg_slimming_status';
const String _statusChannelName = 'JPG 瘦身狀態';
const String _statusChannelDesc = '目前執行狀態（監控中 / 處理進度）';

/// 狀態通知 ID（固定，用同一 ID 反覆更新即「更新同一則通知」）
const int statusNotificationMonitoring = 2001;
const int statusNotificationProcessing = 2002;

/// 背景自動化服務
class BackgroundService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  const BackgroundService._();

  static Future<void> initNotifications() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);
      await _notifications.initialize(settings: settings);
    } catch (e) {
      debugPrint('Notification initialization unavailable: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('通知傳送失敗: $e');
    }
  }

  /// 顯示「狀態列通知」（低重要性、靜音、不打擾使用者）。
  ///
  /// 用固定 ID 反覆呼叫即可更新同一則通知；[ongoing] 為 true 時
  /// 通知會持續存在（如同態服務般），直到呼叫 [cancelStatusNotification] 清除。
  ///
  /// BUG 修復說明：使用者曾「滑掉」同一 id 的通知後，plugin 會保留
  /// 「已消失」狀態，導致之後再用相同 id show 不會重新出現。
  /// 因此這裡在 show 之前先 cancel 一次，重置 plugin 的內部狀態，
  /// 確保每次更新（甚至是滑掉後的下一次更新）都一定能重新彈出。
  static Future<void> showStatusNotification({
    required int id,
    required String title,
    required String body,
    bool ongoing = true,
  }) async {
    try {
      // 先取消同一 id 的舊通知（重置「已顯示/已滑掉」狀態；若原本沒有則忽略）
      try {
        await _notifications.cancel(id: id);
      } catch (e) {
        debugPrint('清除舊狀態通知失敗（略過）: $e');
      }

      final androidDetails = AndroidNotificationDetails(
        _statusChannelId,
        _statusChannelName,
        channelDescription: _statusChannelDesc,
        importance: Importance.min,
        priority: Priority.min,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        ongoing: ongoing,
        autoCancel: false,
        visibility: NotificationVisibility.private,
        showWhen: true,
      );
      final iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentSound: false,
        presentBanner: false,
      );
      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        // 使用者點開通知時不自動清除（由程式控制何時清除）
      );
    } catch (e) {
      debugPrint('狀態通知傳送失敗: $e');
    }
  }

  /// 清除指定的狀態通知
  static Future<void> cancelStatusNotification(int id) async {
    try {
      await _notifications.cancel(id: id);
    } catch (e) {
      debugPrint('清除狀態通知失敗: $e');
    }
  }

  static Future<void> registerPeriodicTask({
    required int intervalMinutes,
    required AppSettings settings,
  }) async {
    await Workmanager().registerPeriodicTask(
      bgTaskUniqueName,
      bgTaskScanAndProcess,
      frequency: Duration(minutes: intervalMinutes < 15 ? 15 : intervalMinutes),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      inputData: {
        'isAutoMode': settings.isAutoMode,
        'quality': settings.quality,
        'resolution': settings.resolution,
        'targetSizeMB': settings.targetSizeMB,
        'minQuality': settings.minQuality,
        'minResolution': settings.minResolution,
        'reprocessFiles': settings.reprocessFiles,
        'sourceFolderPath': settings.sourceFolderPath ?? '',
        'outputFolderPath': settings.outputFolderPath ?? '',
      },
    );
  }

  static Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(bgTaskUniqueName);
  }
}

@pragma('vm:entry-point')
void jpgSlimmingBackgroundCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('JPG Slimming 背景任務啟動: $taskName');

    await BackgroundService.initNotifications();

    try {
      final settings = _settingsFromInput(inputData);

      final sourcePath = settings.sourceFolderPath;
      if (sourcePath == null || sourcePath.isEmpty) {
        await BackgroundService.showNotification(
          id: 1001,
          title: 'JPG 瘦身',
          body: '未設定來源資料夾，跳過背景處理',
        );
        return false;
      }

      final List<FileItem> files;
      try {
        files = await FileService.scanFolderForJpgs(sourcePath);
      } catch (e) {
        debugPrint('掃描資料夾失敗: $e');
        await BackgroundService.showNotification(
          id: 1002,
          title: 'JPG 瘦身錯誤',
          body: '掃描來源資料夾失敗: $e',
        );
        return false;
      }

      debugPrint('掃描到 ${files.length} 個 JPG 檔案');
      if (files.isEmpty) {
        return true;
      }

      final outputFolder = settings.outputFolderPath;
      // 先掃描輸出資料夾，列出檔名集合（不重新處理時用於比對）
      final outputNames = !settings.reprocessFiles
          ? await ImageProcessService.listOutputFileNames(outputFolder)
          : const <String>{};
      final toProcess = <FileItem>[];
      for (final file in files) {
        // 「重新處理相同檔案」關閉時，只要輸出資料夾中有檔名「包含」
        // 來源檔名（不含副檔名）的檔案，即視為已處理過而跳過；
        // 開啟時則一律重新處理。
        if (outputFolder != null && outputFolder.isNotEmpty) {
          if (!settings.reprocessFiles &&
              ImageProcessService.outputNameContainsSource(
                  file.fileName,
                  outputFileNames: outputNames)) {
            file.status = ProcessingStatus.skipped;
            continue;
          }
        }
        toProcess.add(file);
      }

      debugPrint('待處理檔案: ${toProcess.length} 個');
      if (toProcess.isEmpty) {
        return true;
      }

      await BackgroundService.showNotification(
        id: 1003,
        title: 'JPG 瘦身',
        body: '開始處理 ${toProcess.length} 個 JPG 檔案...',
      );

      // 先列表完成後，依序（一個一個）處理，並用狀態通知回報即時進度。
      var index = 0;
      for (final item in toProcess) {
        index++;
        await BackgroundService.showStatusNotification(
          id: statusNotificationProcessing,
          title: '處理中',
          body: '$index / ${toProcess.length}：${item.fileName}',
        );
        await ImageProcessService.processFile(
          item: item,
          settings: settings,
          outputFolderPath: outputFolder,
        );
      }
      // 全部完成後清除「處理中」狀態通知
      await BackgroundService.cancelStatusNotification(
          statusNotificationProcessing);

      var success = 0;
      var failed = 0;
      for (final item in toProcess) {
        if (item.status == ProcessingStatus.success) {
          success++;
        } else if (item.status == ProcessingStatus.failed) {
          failed++;
        }
      }

      await BackgroundService.showNotification(
        id: 1004,
        title: 'JPG 瘦身完成',
        body: '成功: $success 個，失敗: $failed 個',
      );

      return failed == 0;
    } catch (e) {
      debugPrint('背景處理發生錯誤: $e');
      await BackgroundService.showNotification(
        id: 1005,
        title: 'JPG 瘦身錯誤',
        body: '背景處理發生錯誤: $e',
      );
      return false;
    }
  });
}

AppSettings _settingsFromInput(Map<String, dynamic>? input) {
  if (input == null) return const AppSettings();

  return AppSettings(
    isAutoMode: input['isAutoMode'] as bool? ?? false,
    quality: input['quality'] as int? ?? 85,
    resolution: input['resolution'] as int? ?? 100,
    targetSizeMB: (input['targetSizeMB'] as num?)?.toDouble() ??
        AppSettings.defaultTargetSizeMB,
    minQuality: (input['minQuality'] as int? ?? 80).clamp(10, 100).toInt(),
    minResolution:
        (input['minResolution'] as int? ?? 75).clamp(10, 100).toInt(),
    reprocessFiles: input['reprocessFiles'] as bool? ?? false,
    sourceFolderPath: (input['sourceFolderPath'] as String?)?.isNotEmpty == true
        ? input['sourceFolderPath'] as String
        : null,
    outputFolderPath: (input['outputFolderPath'] as String?)?.isNotEmpty == true
        ? input['outputFolderPath'] as String
        : null,
  );
}

