import 'dart:io';

import 'package:jpg_slimming/models/app_settings.dart';

/// 單一 JPG 檔案的處理資訊
class FileItem {
  final String path;
  final String fileName;
  final int originalSizeBytes;
  int? outputSizeBytes;
  ProcessingStatus status = ProcessingStatus.pending;
  int qualityUsed = -1;
  double resolutionUsed = 1.0;
  String? errorMessage;
  String? outputPath;
  Duration? processingTime;

  FileItem({
    required this.path,
    required this.fileName,
    required this.originalSizeBytes,
  });

  /// 讀取檔案大小 (bytes)
  static Future<int> fileSizeBytes(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// 原始大小格式化
  String get originalSizeText => _formatBytes(originalSizeBytes);

  /// 輸出大小格式化
  String get outputSizeText =>
      outputSizeBytes != null ? _formatBytes(outputSizeBytes!) : '-';

  /// 壓縮率文字
  String get compressionRatioText {
    if (outputSizeBytes == null || outputSizeBytes == 0) return '-';
    final ratio = ((outputSizeBytes! / originalSizeBytes) * 100).toStringAsFixed(0);
    return '$ratio%';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
