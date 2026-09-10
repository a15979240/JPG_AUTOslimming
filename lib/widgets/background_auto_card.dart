import 'package:flutter/material.dart';
import 'package:jpg_slimming/i18n/app_strings.dart';
import 'package:jpg_slimming/models/app_settings.dart';

/// 背景自動化設定卡片
///
/// 提供三種監測模式（二選一）：
/// - 關閉（off）
/// - 定時監測（scheduled）：WorkManager 週期掃描
/// - 即時監測（realtime）：Directory.watch 即時偵測
class BackgroundAutoCard extends StatelessWidget {
  final MonitorMode monitorMode;
  final int intervalMinutes;
  final ValueChanged<MonitorMode> onMonitorModeChanged;
  final ValueChanged<int> onIntervalChanged;
  final AppStrings strings;

  const BackgroundAutoCard({
    super.key,
    required this.monitorMode,
    required this.intervalMinutes,
    required this.onMonitorModeChanged,
    required this.onIntervalChanged,
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
                const Icon(Icons.notifications_active_outlined,
                    color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.backgroundAuto,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 監測模式：2x2 方形方格（文字自動換行，不省略）
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _MonitorTile(
                  icon: Icons.power_settings_new,
                  label: strings.none,
                  selected: monitorMode == MonitorMode.off,
                  onTap: () => onMonitorModeChanged(MonitorMode.off),
                ),
                _MonitorTile(
                  icon: Icons.schedule,
                  label: strings.scheduledMonitoring,
                  selected: monitorMode == MonitorMode.scheduled,
                  onTap: () => onMonitorModeChanged(MonitorMode.scheduled),
                ),
                _MonitorTile(
                  icon: Icons.radar,
                  label: strings.realtimeMonitoring,
                  selected: monitorMode == MonitorMode.realtime,
                  onTap: () => onMonitorModeChanged(MonitorMode.realtime),
                ),
                _MonitorTile(
                  icon: Icons.all_inclusive,
                  label: strings.scheduledRealtime,
                  selected: monitorMode == MonitorMode.both,
                  onTap: () => onMonitorModeChanged(MonitorMode.both),
                ),
              ],
            ),

            // 定時監測：顯示掃描間隔滑桿
            if (monitorMode == MonitorMode.scheduled ||
                monitorMode == MonitorMode.both) ...[
              const SizedBox(height: 16),
              Text(
                '${strings.scanningInterval}：$intervalMinutes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Slider(
                value: intervalMinutes.toDouble(),
                min: 15,
                max: 1440,
                divisions: 95,
                label: '$intervalMinutes',
                onChanged: (v) => onIntervalChanged(v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('15', style: Theme.of(context).textTheme.bodySmall),
                  Text('1440', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],

            // 即時監測：說明文字
            if (monitorMode == MonitorMode.realtime ||
                monitorMode == MonitorMode.both) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.realtimeImmediate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 背景自動化監測模式的單一方形方格按鈕
class _MonitorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MonitorTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          // 上下排列：圖示在上、文字在下，文字可換行（不省略）
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.clip,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
