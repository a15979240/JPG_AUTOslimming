import 'package:flutter/material.dart';
import 'package:jpg_slimming/i18n/app_strings.dart';

/// 手動模式設定面板
class ManualModePanel extends StatelessWidget {
  final int quality;
  final int resolution;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<int> onResolutionChanged;
  final AppStrings strings;

  const ManualModePanel({
    super.key,
    required this.quality,
    required this.resolution,
    required this.onQualityChanged,
    required this.onResolutionChanged,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  strings.manualTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 品質滑桿
            Text(
              '${strings.quality}：$quality%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: quality.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              label: '$quality%',
              onChanged: (v) => onQualityChanged(v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1%', style: Theme.of(context).textTheme.bodySmall),
                Text('100%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),

            const Divider(height: 24),

            // 解析度滑桿
            Text(
              '${strings.resolution}：$resolution%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: resolution.toDouble(),
              min: 10,
              max: 100,
              divisions: 90,
              label: '$resolution%',
              onChanged: (v) => onResolutionChanged(v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10%', style: Theme.of(context).textTheme.bodySmall),
                Text('100%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
