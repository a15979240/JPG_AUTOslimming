import 'package:flutter/material.dart';
import 'package:jpg_slimming/i18n/app_strings.dart';

/// 來源 / 輸出資料夾選擇卡片
class FolderPickerCard extends StatelessWidget {
  final String? sourceFolderPath;
  final String? outputFolderPath;
  final VoidCallback onPickSource;
  final VoidCallback onPickOutput;
  final AppStrings strings;

  const FolderPickerCard({
    super.key,
    required this.sourceFolderPath,
    required this.outputFolderPath,
    required this.onPickSource,
    required this.onPickOutput,
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
                const Icon(Icons.folder_outlined, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  strings.sourceFolder,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 來源資料夾
            _buildFolderRow(
              context: context,
              icon: Icons.input,
              iconColor: Colors.blue,
              title: strings.sourceFolder,
              path: sourceFolderPath,
              buttonLabel: strings.pickFolder,
              onPressed: onPickSource,
            ),

            const SizedBox(height: 12),

            // 輸出資料夾
            _buildFolderRow(
              context: context,
              icon: Icons.output,
              iconColor: Colors.green,
              title: strings.outputFolder,
              path: outputFolderPath,
              buttonLabel: strings.pickFolder,
              onPressed: onPickOutput,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String? path,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                path ?? strings.pickFolder,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: path == null
                          ? Theme.of(context).colorScheme.outline
                          : null,
                      fontWeight:
                          path == null ? FontWeight.normal : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}
