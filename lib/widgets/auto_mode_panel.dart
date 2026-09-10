import 'package:flutter/material.dart';
import 'package:jpg_slimming/i18n/app_strings.dart';
import 'package:jpg_slimming/models/app_settings.dart';

/// 自動模式面板
///
/// - 目標容量：使用者可輸入任意 MB（可低於 1MB）
/// - 品質下限：10%~100%
/// - 解析度下限：10%~100%
/// - 容量策略：A（跳過下限）/ B（以下限為主，預設）
class AutoModePanel extends StatelessWidget {
  final double targetSizeMB;
  final int minQuality;
  final int minResolution;
  final CapacityStrategy capacityStrategy;
  final ValueChanged<double> onTargetSizeChanged;
  final ValueChanged<int> onMinQualityChanged;
  final ValueChanged<int> onMinResolutionChanged;
  final ValueChanged<CapacityStrategy> onCapacityStrategyChanged;
  final AppStrings strings;

  const AutoModePanel({
    super.key,
    required this.targetSizeMB,
    required this.minQuality,
    required this.minResolution,
    required this.capacityStrategy,
    required this.onTargetSizeChanged,
    required this.onMinQualityChanged,
    required this.onMinResolutionChanged,
    required this.onCapacityStrategyChanged,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.teal),
                const SizedBox(width: 8),
                Text(strings.autoTitle, style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),

            // 目標容量輸入框
            Text(strings.inputTargetSize, style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('targetSizeInput'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: TextEditingController(
                text: targetSizeMB == targetSizeMB.roundToDouble()
                    ? targetSizeMB.toStringAsFixed(0)
                    : targetSizeMB.toString(),
              ),
              decoration: InputDecoration(
                hintText: strings.targetSizeHint,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixText: 'MB',
              ),
              onSubmitted: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null && parsed > 0) {
                  onTargetSizeChanged(parsed);
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              strings.targetSizeHint,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),

            const SizedBox(height: 16),

            // 容量策略選擇（A/B）
            Text(strings.capacityStrategyLabel, style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<CapacityStrategy>(
              segments: [
                ButtonSegment(
                  value: CapacityStrategy.skipLimits,
                  icon: const Icon(Icons.bolt),
                  label: Text(strings.capacityStrategyA),
                ),
                ButtonSegment(
                  value: CapacityStrategy.keepLimits,
                  icon: const Icon(Icons.shield),
                  label: Text(strings.capacityStrategyB),
                ),
              ],
              selected: {capacityStrategy},
              onSelectionChanged: (value) =>
                  onCapacityStrategyChanged(value.first),
            ),
            const SizedBox(height: 4),
            Text(
              capacityStrategy == CapacityStrategy.skipLimits
                  ? strings.capacityStrategyADesc
                  : strings.capacityStrategyBDesc,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),

            const SizedBox(height: 16),

            // 最低品質滑桿（10~100）
            Text('${strings.minQualityLabel}：$minQuality%',
                style: textTheme.bodyMedium),
            Slider(
              value: minQuality.toDouble(),
              min: 10,
              max: 100,
              divisions: 90,
              label: '$minQuality%',
              onChanged: (value) => onMinQualityChanged(value.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10%', style: textTheme.bodySmall),
                Text('100%', style: textTheme.bodySmall),
              ],
            ),

            const Divider(height: 24),

            // 最低解析度滑桿（10~100）
            Text('${strings.minResolutionLabel}：$minResolution%',
                style: textTheme.bodyMedium),
            Slider(
              value: minResolution.toDouble(),
              min: 10,
              max: 100,
              divisions: 90,
              label: '$minResolution%',
              onChanged: (value) => onMinResolutionChanged(value.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10%', style: textTheme.bodySmall),
                Text('100%', style: textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
