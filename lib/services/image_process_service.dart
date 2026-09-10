import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:jpg_slimming/models/app_settings.dart';
import 'package:jpg_slimming/models/file_item.dart';
import 'package:jpg_slimming/services/jpg_compressor.dart';

/// 圖片處理進度回呼
typedef ProcessProgressCallback =
    void Function(FileItem item, int index, int total);

/// 圖片處理服務
class ImageProcessService {
  const ImageProcessService._();

  /// 等待檔案完整（不再變動）
  ///
  /// 檢查檔案大小是否穩定，避免處理「正在複製/移動中」的檔案。
  /// [maxWaitSeconds] 最多等待秒數，預設 10 秒。
  /// 回傳 true 表示檔案已穩定可處理；false 表示等待逾時。
  static Future<bool> waitForFileStable(
    String filePath, {
    int maxWaitSeconds = 10,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    var lastSize = await file.length();
    var stableCount = 0;

    // 連續 3 次（間隔 1 秒）大小相同 → 判定檔案穩定
    for (var i = 0; i < maxWaitSeconds; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));

      if (!await file.exists()) return false;

      final currentSize = await file.length();
      if (currentSize == lastSize) {
        stableCount++;
        if (stableCount >= 2) {
          return true; // 檔案大小連續 2 秒穩定
        }
      } else {
        stableCount = 0;
        lastSize = currentSize;
      }
    }

    return stableCount >= 2;
  }

  /// 處理單一檔案並輸出
  ///
  /// [item] 欲處理的檔案項目
  /// [settings] 應用程式設定
  /// [outputFolderPath] 輸出資料夾（若無則與來源同目錄）
  /// [overwrite] 是否覆蓋已存在的輸出檔案
  ///
  /// 回傳 [FileItem]（處理後狀態與結果已更新）
  static Future<FileItem> processFile({
    required FileItem item,
    required AppSettings settings,
    required String? outputFolderPath,
    bool overwrite = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    item.status = ProcessingStatus.processing;
    item.errorMessage = null;

    try {
      // 1. 檢查檔案存在
      final inputFile = File(item.path);
      if (!await inputFile.exists()) {
        throw FileSystemException('檔案不存在', item.path);
      }

      // 2. 等待檔案完整（若是監測來源的檔案，確保複製/移動完成）
      final stable = await waitForFileStable(item.path, maxWaitSeconds: 5);
      if (!stable) {
        // 等待逾時但檔案仍存在，仍嘗試處理
        debugPrint('警告: 檔案可能尚未穩定，仍嘗試處理 ${item.path}');
      }

      // 3. 讀取檔案
      final inputBytes = await inputFile.readAsBytes();

      // 4. 輸出檔名（避免覆蓋原始檔）
      final baseName = p.basename(item.path);
      final ext = p.extension(baseName).toLowerCase();
      final nameWithoutExt = p.basenameWithoutExtension(baseName);

      // 確定輸出資料夾
      String effectiveOutputDir;
      if (outputFolderPath != null && outputFolderPath.isNotEmpty) {
        effectiveOutputDir = outputFolderPath;
      } else {
        effectiveOutputDir = p.dirname(item.path);
      }
      await Directory(effectiveOutputDir).create(recursive: true);

      // 輸出檔名：原名_slimmed.jpg
      String outputFileName;
      if (overwrite) {
        outputFileName = '$nameWithoutExt$ext';
      } else {
        outputFileName = '${nameWithoutExt}_slimmed$ext';
      }
      final outputPath = p.join(effectiveOutputDir, outputFileName);

      // 5. 執行壓縮（在 isolate 中執行，不阻塞 UI）
      final CompressionResult result;
      if (settings.isAutoMode) {
        result = await JpgCompressor.autoCompress(
          input: inputBytes,
          targetBytes: settings.targetSizeBytes,
          minQuality: settings.minQuality,
          minResolutionPercent: settings.minResolution.toDouble(),
          capacityStrategy: settings.capacityStrategy,
        );
      } else {
        result = await JpgCompressor.manualCompress(
          input: inputBytes,
          quality: settings.quality,
          resolutionPercent: settings.resolution.toDouble(),
        );
      }

      // 6. 寫入輸出檔案
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(result.data, flush: true);

      // 7. 更新項目狀態
      item.outputSizeBytes = result.outputSizeBytes;
      item.qualityUsed = result.quality;
      item.resolutionUsed = result.resolutionScale;
      item.outputPath = outputPath;
      item.status = ProcessingStatus.success;
      item.processingTime = stopwatch.elapsed;

      return item;
    } catch (e) {
      item.status = ProcessingStatus.failed;
      item.errorMessage = e.toString();
      item.processingTime = stopwatch.elapsed;
      return item;
    }
  }

  /// 比對「輸出資料夾」與「來源檔名」：判斷輸出資料夾中是否已有檔案
  /// 「包含」來源檔案名稱（不含副檔名）。
  ///
  /// 用途：當「重新處理相同檔案」關閉時，用來判斷來源檔是否已處理過，
  /// 避免重複壓縮。只要輸出資料夾裡有任何檔名含有來源檔的主檔名，
  /// （例如來源 `photo.jpg` 對應輸出 `photo_slimmed.jpg`），即視為已處理。
  static bool outputNameContainsSource(
    String sourceFileName, {
    Set<String>? outputFileNames,
  }) {
    final names = outputFileNames;
    if (names == null || names.isEmpty) return false;

    final lower = sourceFileName.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final base = dot > 0 ? lower.substring(0, dot) : lower;
    if (base.isEmpty) return false;

    for (final outputName in names) {
      if (outputName.contains(base)) return true;
    }
    return false;
  }

  /// 掃描輸出資料夾並回傳其中所有檔名的小寫集合。
  ///
  /// 用於「不重新處理相同檔案」時，一次列出輸出名稱集合，
  /// 再以 [outputNameContainsSource] 逐一比對來源檔，效率較高。
  /// 若輸出資料夾未設定或不存在，回傳空集合。
  static Future<Set<String>> listOutputFileNames(String? outputFolder) async {
    final result = <String>{};
    if (outputFolder == null || outputFolder.isEmpty) return result;

    final dir = Directory(outputFolder);
    if (!await dir.exists()) return result;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toLowerCase();
      if (name.isNotEmpty) result.add(name);
    }
    return result;
  }
  ///
  /// [items] 待處理檔案列表
  /// [settings] 應用程式設定
  /// [outputFolderPath] 輸出資料夾
  /// [progressCallback] 進度回呼（每處理一個檔案觸發一次）
  /// [concurrency] 同時處理數量（預設 1，一次只處理一個，避免資源耗盡與 UI 卡頓）
  static Future<void> processFiles({
    required List<FileItem> items,
    required AppSettings settings,
    required String? outputFolderPath,
    ProcessProgressCallback? progressCallback,
    int concurrency = 1,
  }) async {
    if (items.isEmpty) return;

    final semaphore = _SimpleSemaphore(concurrency);
    final total = items.length;
    var completed = 0;

    await Future.wait(
      items.map((item) async {
        await semaphore.acquire();
        try {
          await processFile(
            item: item,
            settings: settings,
            outputFolderPath: outputFolderPath,
          );
        } finally {
          semaphore.release();
          completed++;
          progressCallback?.call(item, completed - 1, total);
        }
      }),
    );
  }
}

/// 簡單號誌（限制同時執行數量，避免大量圖片同時壓縮導致記憶體爆量與 UI 卡頓）
class _SimpleSemaphore {
  int _permits;

  _SimpleSemaphore(int maxPermits) : _permits = maxPermits;

  Future<void> acquire() async {
    while (true) {
      if (_permits > 0) {
        _permits--;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void release() {
    _permits++;
  }
}
