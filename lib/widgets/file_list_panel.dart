import 'package:flutter/material.dart';
import 'package:jpg_slimming/i18n/app_strings.dart';
import 'package:jpg_slimming/models/app_settings.dart';
import 'package:jpg_slimming/models/file_item.dart';

/// 檔案列表面板（處理區塊：分頁顯示檔案與狀態）
class FileListPanel extends StatefulWidget {
  final List<FileItem> files;
  final bool isProcessing;
  final ValueChanged<FileItem> onRemove;
  final bool showOutputColumn;
  final AppStrings strings;

  const FileListPanel({
    super.key,
    required this.files,
    required this.isProcessing,
    required this.onRemove,
    required this.strings,
    this.showOutputColumn = true,
  });

  @override
  State<FileListPanel> createState() => _FileListPanelState();
}

class _FileListPanelState extends State<FileListPanel> {
  /// 每頁可選數量
  static const List<int> _pageSizeOptions = [5, 10, 20];

  int _pageSize = 5;
  int _currentPage = 1;

  AppStrings get _strings => widget.strings;

  int get _totalPages {
    final count = widget.files.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }

  List<FileItem> get _visibleFiles {
    final start = (_currentPage - 1) * _pageSize;
    if (start >= widget.files.length) return const <FileItem>[];
    final end = (start + _pageSize).clamp(0, widget.files.length);
    return widget.files.sublist(start, end);
  }

  @override
  void didUpdateWidget(FileListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 檔案數量變動後，確保目前頁數不超出總頁數
    if (_currentPage > _totalPages) {
      _currentPage = _totalPages;
    }
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page.clamp(1, _totalPages));
  }

  void _setPageSize(int size) {
    setState(() {
      _pageSize = size;
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files;
    final strings = widget.strings;

    if (files.isEmpty) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.image_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                strings.selectJpg,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.scanFolder,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${strings.fileListTitle}（${files.length}）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.isProcessing
                        ? null
                        : () => widget.onRemove(files.first),
                    tooltip: strings.clearList,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
                ],
              ),
            ),

            // 分頁控制列（放在區塊上方）
            _buildPaginationBar(context),

            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _visibleFiles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _visibleFiles[index];
                  return _FileItemTile(
                    item: file,
                    isProcessing: widget.isProcessing,
                    showOutputColumn: widget.showOutputColumn,
                    onRemove: () => widget.onRemove(file),
                    strings: strings,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 分頁控制列：每頁數量選擇（5/10/20）＋上一頁／下一頁
  Widget _buildPaginationBar(BuildContext context) {
    final hasPrev = _currentPage > 1;
    final hasNext = _currentPage < _totalPages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Text(
            _strings.pageSizeLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          // 每頁數量選擇
          SegmentedButton<int>(
            segments: [
              for (final size in _pageSizeOptions)
                ButtonSegment(value: size, label: Text('$size')),
            ],
            selected: {_pageSize},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: widget.isProcessing
                ? null
                : (value) => _setPageSize(value.first),
          ),
          const Spacer(),
          IconButton(
            onPressed: !widget.isProcessing && hasPrev
                ? () => _goToPage(_currentPage - 1)
                : null,
            tooltip: _strings.stopWatching,
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$_currentPage / $_totalPages',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            onPressed: !widget.isProcessing && hasNext
                ? () => _goToPage(_currentPage + 1)
                : null,
            tooltip: _strings.scheduledRealTime,
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _FileItemTile extends StatelessWidget {
  final FileItem item;
  final bool isProcessing;
  final bool showOutputColumn;
  final VoidCallback onRemove;
  final AppStrings strings;

  const _FileItemTile({
    required this.item,
    required this.isProcessing,
    required this.showOutputColumn,
    required this.onRemove,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final statusIcon = _statusIcon();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _buildStatusText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                ),
              ],
            ),
          ),

          if (showOutputColumn) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.originalSizeText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.outputSizeText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: item.status == ProcessingStatus.success
                            ? Colors.green
                            : Theme.of(context).colorScheme.outline,
                      ),
                ),
                if (item.status == ProcessingStatus.success) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${item.compressionRatioText} · ${strings.quality} ${item.qualityUsed}%'
                    ' · ${strings.resolution} ${(item.resolutionUsed * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ],

          IconButton(
            onPressed: isProcessing ? null : onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: Theme.of(context).colorScheme.outline,
            tooltip: strings.clearList,
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    switch (item.status) {
      case ProcessingStatus.success:
        return Colors.green;
      case ProcessingStatus.failed:
        return Colors.red;
      case ProcessingStatus.processing:
        return Colors.orange;
      case ProcessingStatus.skipped:
        return Colors.grey;
      case ProcessingStatus.pending:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _statusIcon() {
    switch (item.status) {
      case ProcessingStatus.success:
        return Icons.check_circle;
      case ProcessingStatus.failed:
        return Icons.error;
      case ProcessingStatus.processing:
        return Icons.hourglass_top;
      case ProcessingStatus.skipped:
        return Icons.skip_next;
      case ProcessingStatus.pending:
        return Icons.schedule;
    }
  }

  String _buildStatusText() {
    switch (item.status) {
      case ProcessingStatus.success:
        return '✓ ${strings.success}';
      case ProcessingStatus.failed:
        return item.errorMessage ?? strings.failed;
      case ProcessingStatus.processing:
        return strings.processing;
      case ProcessingStatus.skipped:
        return strings.skipped;
      case ProcessingStatus.pending:
        return strings.none;
    }
  }
}
