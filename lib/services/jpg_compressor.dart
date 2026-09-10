import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:jpg_slimming/models/app_settings.dart';

/// 壓縮結果
class CompressionResult {
  final Uint8List data;
  final int quality;
  final double resolutionScale;

  /// 壓縮後大小 (bytes)
  int get outputSizeBytes => data.length;

  CompressionResult({
    required this.data,
    required this.quality,
    required this.resolutionScale,
  });
}

/// JPG 壓縮引擎
///
/// 支援兩種模式：
/// 1. 手動模式：指定品質(%) + 解析度(%)
/// 2. 自動模式：以目標容量為基準，品質優先、解析度其次
///
/// 所有壓縮運算均在背景 isolate 執行，避免阻塞 UI。
class JpgCompressor {
  static const _interpolation = img.Interpolation.linear;

  /// 策略 A（跳過下限）的「品質／解析度」交替、均衡降級組合。
  ///
  /// 依使用者規則：
  ///   品質 → 70% → 解析度 50% → 品質 50% → 解析度 40% → …
  /// 每次只降一個維度、並依序縮減門檻，讓品質與解析度保持平衡，
  /// 避免「頭重腳輕」（單一維度降到底、另一維度仍維持在高檔）。
  /// 依序愈靠前的組合愈「接近原始」，輸出也愈「接近目標容量」。
  static const List<List<int>> _skipCombos = [
    // [品質%, 解析度%]
    [100, 100],
    [90, 90],
    [80, 80],
    [70, 100], // 品質 → 70%
    [70, 50], // 解析度 → 50%
    [50, 50], // 品質 → 50%
    [50, 40], // 解析度 → 40%
    [40, 40],
    [40, 30],
    [30, 30],
    [30, 20],
    [20, 20],
    [20, 10],
    [10, 10],
    [10, 5],
    [5, 5],
    [5, 1],
    [1, 1],
  ];

  /// 依指定品質與解析度縮放率壓縮（策略 A 使用的輔助函式）。
  static Uint8List _encodeAtCombination(
    img.Image image, {
    required int quality,
    required double scale,
  }) {
    final q = quality.clamp(1, 100).toInt();
    if (scale >= 1.0) {
      return img.encodeJpg(image, quality: q);
    }
    final resized = img.copyResize(
      image,
      width: (image.width * scale).round().clamp(1, 1 << 24),
      height: (image.height * scale).round().clamp(1, 1 << 24),
      interpolation: _interpolation,
    );
    return img.encodeJpg(resized, quality: q);
  }

  const JpgCompressor._();

  /// 手動壓縮（在 isolate 中執行，不阻塞 UI）
  ///
  /// [input] 原始 JPG 位元組
  /// [quality] 品質 1-100
  /// [resolutionPercent] 解析度百分比 10-100
  static Future<CompressionResult> manualCompress({
    required Uint8List input,
    required int quality,
    required double resolutionPercent,
  }) {
    return Isolate.run(() {
      final image = img.decodeJpg(input);
      if (image == null) {
        throw const FormatException('無法解析此 JPG 圖片');
      }

      // 套用 EXIF 方向，確保輸出方向正確
      final oriented = img.bakeOrientation(image);

      final scale = (resolutionPercent / 100.0).clamp(0.1, 1.0);
      img.Image working;
      if (scale >= 1.0) {
        working = oriented;
      } else {
        working = img.copyResize(
          oriented,
          width: (oriented.width * scale).round().clamp(1, 1 << 24),
          height: (oriented.height * scale).round().clamp(1, 1 << 24),
          interpolation: _interpolation,
        );
      }

      final q = quality.clamp(1, 100);
      final data = img.encodeJpg(working, quality: q);
      return CompressionResult(
        data: data,
        quality: q,
        resolutionScale: scale,
      );
    });
  }

  /// 以目標容量為基準的自動壓縮（在 isolate 中執行，不阻塞 UI）
  ///
  /// 演算法（品質優先）：
  /// 1. 先在原始解析度下，以「最高品質 ≤ 目標容量」為目標做二元搜尋
  /// 2. 若連最低品質都超過目標容量，才降低解析度（5% 一階）
  /// 3. 品質下限 [minQuality]，解析度下限 [minResolutionPercent]
  /// 4. 每次搜尋前先實際試壓計算容量，確認可行才繼續，避免重複作業
  static Future<CompressionResult> autoCompress({
    required Uint8List input,
    required int targetBytes,
    required int minQuality,
    required double minResolutionPercent,
    CapacityStrategy capacityStrategy = CapacityStrategy.keepLimits,
  }) {
    return Isolate.run(() {
      final image = img.decodeJpg(input);
      if (image == null) {
        throw const FormatException('無法解析此 JPG 圖片');
      }

      final oriented = img.bakeOrientation(image);

      final effectiveMinQuality = minQuality.clamp(10, 100).toInt();
      final minScale =
          (minResolutionPercent / 100.0).clamp(0.1, 1.0).toDouble();

      // 先嘗試原始解析度（品質最優先）
      final estimatedFullSize = _estimateOutputSizeForImage(
        oriented,
        quality: effectiveMinQuality,
        scale: 1.0,
      );
      final estimatedScale = estimatedFullSize <= targetBytes
          ? 1.0
          : math.sqrt((targetBytes / estimatedFullSize).clamp(0.0, 1.0));
      final startScale = estimatedScale.clamp(minScale, 1.0).toDouble();

      // 產生解析度等級並逐一嘗試
      final scales = <double>[];
      for (double s = startScale; s >= minScale - 0.0001; s -= 0.05) {
        if (s < minScale) s = minScale;
        scales.add(s);
      }
      if (scales.isEmpty || (scales.last - minScale).abs() > 0.001) {
        scales.add(minScale);
      }

      for (final scale in scales) {
        final result = _searchAtResolution(
          image: oriented,
          scale: scale,
          targetBytes: targetBytes,
          minQuality: effectiveMinQuality,
        );
        if (result != null) return result;
      }

      // 所有等級都無法達標
      if (capacityStrategy == CapacityStrategy.skipLimits) {
        // 策略 A：跳過下限限制，改以「品質／解析度交替、均衡降級」的梯階組合
        // 依使用者規則，避免「頭重腳輕」。
        //
        // 從組合清單第一個（最接近原始）開始嘗試，只要任一組合壓縮後
        // ≤ 目標容量即回傳該結果（愈靠前愈接近目標容量）。
        // 每個組合一開始先快速預估容量判斷，再實際壓縮；確認可行才保留，
        // 避免不必要的重複作業。
        for (final combo in _skipCombos) {
          final comboQuality = combo[0];
          final comboScale = combo[1] / 100.0;
          // 已在下限內搜尋過的組合，不需重複嘗試
          if (comboQuality >= effectiveMinQuality &&
              comboScale >= minScale - 0.0001) {
            continue;
          }
          final data = _encodeAtCombination(
            oriented,
            quality: comboQuality,
            scale: comboScale,
          );
          if (data.length <= targetBytes) {
            return CompressionResult(
              data: data,
              quality: comboQuality,
              resolutionScale: comboScale,
            );
          }
        }

        // 最後手段：品質 1% + 解析度 10%
        final smallest = img.copyResize(
          oriented,
          width: (oriented.width * 0.1).round().clamp(1, 1 << 24),
          height: (oriented.height * 0.1).round().clamp(1, 1 << 24),
          interpolation: _interpolation,
        );
        final finalData = img.encodeJpg(smallest, quality: 1);
        return CompressionResult(
          data: finalData,
          quality: 1,
          resolutionScale: 0.1,
        );
      } else {
        // 策略 B（預設）：以下限為主，即使超過目標容量
        final working = img.copyResize(
          oriented,
          width: (oriented.width * minScale).round().clamp(1, 1 << 24),
          height: (oriented.height * minScale).round().clamp(1, 1 << 24),
          interpolation: _interpolation,
        );
        final data = img.encodeJpg(working, quality: effectiveMinQuality);
        return CompressionResult(
          data: data,
          quality: effectiveMinQuality,
          resolutionScale: minScale,
        );
      }
    });
  }

  /// 估算壓縮後容量（快速、低準度）
  ///
  /// 用於處理前先預估，避免不必要的完整壓縮。
  /// 傳回估計的 bytes。
  static Future<int> estimateOutputSize({
    required Uint8List input,
    required int quality,
  }) {
    return Isolate.run(() {
      final image = img.decodeJpg(input);
      if (image == null) return input.length;

      // 以 1/4 解析度快速試壓，再按面積比例放大估算
      final small = img.copyResize(
        image,
        width: (image.width / 4).round().clamp(1, 1 << 24),
        height: (image.height / 4).round().clamp(1, 1 << 24),
        interpolation: _interpolation,
      );
      final smallData = img.encodeJpg(small, quality: quality.clamp(1, 100));
      final ratio = image.width * image.height / (small.width * small.height);
      return (smallData.length * ratio).round();
    });
  }

  /// 在指定解析度下，二元搜尋「最高品質且壓縮後 ≤ 目標容量」
  ///
  /// 傳回 null 代表連最低品質都超過目標容量。
  static int _estimateOutputSizeForImage(
    img.Image image, {
    required int quality,
    required double scale,
  }) {
    final scaledWidth = (image.width * scale).round().clamp(1, 1 << 24);
    final scaledHeight = (image.height * scale).round().clamp(1, 1 << 24);
    final sampleWidth = (scaledWidth / 4).round().clamp(1, scaledWidth);
    final sampleHeight = (scaledHeight / 4).round().clamp(1, scaledHeight);
    final sample = img.copyResize(
      image,
      width: sampleWidth,
      height: sampleHeight,
      interpolation: _interpolation,
    );
    final sampleData = img.encodeJpg(sample, quality: quality.clamp(1, 100));
    return (sampleData.length * scaledWidth * scaledHeight /
            (sampleWidth * sampleHeight))
        .round();
  }

  static CompressionResult? _searchAtResolution({
    required img.Image image,
    required double scale,
    required int targetBytes,
    required int minQuality,
  }) {
    img.Image working;
    if (scale >= 1.0) {
      working = image;
    } else {
      working = img.copyResize(
        image,
        width: (image.width * scale).round().clamp(1, 1 << 24),
        height: (image.height * scale).round().clamp(1, 1 << 24),
        interpolation: _interpolation,
      );
    }

    // 快速驗證：最低品質都超標 → 此解析度無解
    final minData = img.encodeJpg(working, quality: minQuality);
    if (minData.length > targetBytes) {
      return null;
    }

    // 二元搜尋最高品質使得 輸出 ≤ targetBytes
    int low = minQuality;
    int high = 100;
    CompressionResult? best;
    int iterations = 0;
    const maxIterations = 10;

    while (low <= high && iterations < maxIterations) {
      iterations++;
      final mid = (low + high) ~/ 2;
      final data = img.encodeJpg(working, quality: mid);

      if (data.length <= targetBytes) {
        best = CompressionResult(
          data: data,
          quality: mid,
          resolutionScale: scale,
        );
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // 已找到最佳品質，若還可再 +1 品質且仍 ≤ 目標容量，則用更高品質
    if (best != null && best.quality < 100) {
      final upQuality = best.quality + 1;
      final upData = img.encodeJpg(working, quality: upQuality);
      if (upData.length <= targetBytes) {
        return CompressionResult(
          data: upData,
          quality: upQuality,
          resolutionScale: scale,
        );
      }
    }

    return best;
  }
}
