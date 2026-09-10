import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 即時監測資料夾變動服務
///
/// 使用 Dart 內建 `Directory.watch()`，當來源資料夾新增/修改 JPG 檔案時，
/// 立即通知 UI 進行處理（類似 FolderSync Pro 的即時監測）。
class FolderWatcherService {
  static final FolderWatcherService _instance = FolderWatcherService._();

  factory FolderWatcherService() => _instance;

  FolderWatcherService._();

  StreamSubscription<FileSystemEvent>? _subscription;
  Directory? _watchedDirectory;
  bool _isWatching = false;

  /// 是否正在監測
  bool get isWatching => _isWatching;

  /// 目前監測的資料夾路徑
  String? get watchedPath => _watchedDirectory?.path;

  /// 開始監測指定資料夾
  ///
  /// [onNewJpg]：發現新增/修改的 JPG 檔案時回呼（傳入檔案路徑）。
  /// 會先停止現有監測，再啟動新的。
  void startWatching({
    required String folderPath,
    required void Function(String jpgPath) onNewJpg,
  }) {
    stopWatching();

    final directory = Directory(folderPath);
    if (!directory.existsSync()) {
      debugPrint('監測資料夾不存在: $folderPath');
      return;
    }

    _watchedDirectory = directory;
    _isWatching = true;

    // 監測資料夾及其子資料夾的變動
    _subscription = directory.watch(recursive: true).listen((event) {
      final path = event.path;
      final lower = path.toLowerCase();

      // 只處理 JPG/JPEG 檔案的新增或修改事件
      if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) return;

      if (event is FileSystemCreateEvent ||
          event is FileSystemModifyEvent ||
          event is FileSystemMoveEvent) {
        // 忽略已存在的輸出檔（_slimmed.jpg）
        if (lower.contains('_slimmed.')) return;

        debugPrint('即時監測發現檔案: $path');
        onNewJpg(path);
      }
    }, onError: (Object e) {
      debugPrint('監測資料夾發生錯誤: $e');
    });

    debugPrint('開始即時監測資料夾: $folderPath');
  }

  /// 停止監測
  void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
    _watchedDirectory = null;
    _isWatching = false;
    debugPrint('已停止即時監測');
  }
}
