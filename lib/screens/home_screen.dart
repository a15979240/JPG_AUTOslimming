import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jpg_slimming/i18n/app_strings.dart';
import 'package:jpg_slimming/models/app_settings.dart';
import 'package:jpg_slimming/models/file_item.dart';
import 'package:jpg_slimming/services/background_service.dart';
import 'package:jpg_slimming/services/file_service.dart';
import 'package:jpg_slimming/services/folder_watcher_service.dart';
import 'package:jpg_slimming/services/image_process_service.dart';
import 'package:jpg_slimming/services/permission_service.dart';
import 'package:jpg_slimming/services/settings_service.dart';
import 'package:jpg_slimming/widgets/auto_mode_panel.dart';
import 'package:jpg_slimming/widgets/background_auto_card.dart';
import 'package:jpg_slimming/widgets/file_list_panel.dart';
import 'package:jpg_slimming/widgets/folder_picker_card.dart';
import 'package:jpg_slimming/widgets/manual_mode_panel.dart';

class HomeScreen extends StatefulWidget {
  /// 目前主題（由應用程式根層級提供）
  final AppTheme theme;

  /// 主題切換回呼（更新根層級 MaterialApp 主題）
  final ValueChanged<AppTheme>? onThemeChanged;

  const HomeScreen({
    super.key,
    this.theme = AppTheme.light,
    this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSettings _settings = const AppSettings();
  final List<FileItem> _files = [];
  final List<String> _watchQueue = []; // 即時監測待處理佇列
  bool _watchQueueProcessing = false; // 防止並行處理佇列（核心防重複）
  bool _processing = false;
  bool _scanning = false;
  bool _watching = false;
  bool _paused = false; // 暫停處理（暫停時迴圈等待，不繼續）
  bool _stopRequested = false; // 使用者要求停止處理
  int _totalFiles = 0; // 本次批次處理的總數（用於顯示進度）
  int _completed = 0;
  int _success = 0;
  int _failed = 0;

  AppStrings get _s => AppStrings.of(_settings.languageCode);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    BackgroundService.initNotifications();
    PermissionService.requestAllPermissions();
  }

  @override
  void dispose() {
    FolderWatcherService().stopWatching();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.load();
      if (!mounted) return;
      setState(() => _settings = settings);
      // 若監測模式包含即時監測且已設定來源資料夾，自動啟動即時監測
      if ((settings.monitorMode == MonitorMode.realtime ||
              settings.monitorMode == MonitorMode.both) &&
          settings.sourceFolderPath != null &&
          settings.sourceFolderPath!.isNotEmpty) {
        _startWatching();
      }
    } catch (e) {
      debugPrint('載入設定失敗: $e');
    }
  }

  /// 啟動即時監測來源資料夾
  void _startWatching() {
    final source = _settings.sourceFolderPath;
    if (source == null || source.isEmpty || _watching) return;

    FolderWatcherService().startWatching(
      folderPath: source,
      onNewJpg: (jpgPath) {
        // 新 JPG 檔案出現 → 加入佇列（去重 + 串行處理）
        if (!mounted) return;
        // 去重：若已在佇列中，忽略重複事件
        if (_watchQueue.contains(jpgPath)) return;
        _watchQueue.add(jpgPath);
        _processWatchQueue();
      },
    );
    if (!mounted) return;
    setState(() => _watching = FolderWatcherService().isWatching);
    // 監控中狀態通知（持續顯示，不打擾使用者）
    BackgroundService.showStatusNotification(
      id: statusNotificationMonitoring,
      title: _s.appTitle,
      body: _s.watching,
    );
    _message(_s.startWatching);
  }

  /// 停止即時監測
  void _stopWatching() {
    FolderWatcherService().stopWatching();
    if (!mounted) return;
    setState(() => _watching = false);
    // 清除「監控中」狀態通知
    BackgroundService.cancelStatusNotification(statusNotificationMonitoring);
    _message(_s.stopWatching);
  }

  /// 依序處理即時監測佇列（串行處理，一次只處理一個，杜絕重複處理）
  Future<void> _processWatchQueue() async {
    if (_watchQueueProcessing) return;
    _watchQueueProcessing = true;

    try {
      // 若「不重新處理」，先列出輸出資料夾檔名集合一次，供佇列比對
      final outputNames = !_settings.reprocessFiles
          ? await ImageProcessService.listOutputFileNames(
              _settings.outputFolderPath)
          : const <String>{};

      while (_watchQueue.isNotEmpty && mounted) {
        final jpgPath = _watchQueue.removeAt(0);

        if (_files.any((f) => f.path == jpgPath)) {
          continue;
        }

        // 不重新處理：輸出資料夾檔名已包含此來源檔名 → 跳過
        if (!_settings.reprocessFiles) {
          final queuedName = jpgPath.split(Platform.pathSeparator).last;
          if (ImageProcessService.outputNameContainsSource(
                  queuedName,
                  outputFileNames: outputNames)) {
            continue;
          }
        }

        final size = await FileItem.fileSizeBytes(jpgPath);
        final item = FileItem(
          path: jpgPath,
          fileName: jpgPath.split(Platform.pathSeparator).last,
          originalSizeBytes: size,
        );

        if (!mounted) return;
        setState(() {
          _files.add(item);
          _processing = true;
          _completed = 0;
          _success = 0;
          _failed = 0;
          // 本次批次總數 = 目前這一個 + 佇列剩餘（避免暫停時通知顯示 0/0）
          _totalFiles = _watchQueue.length + 1;
        });

        await ImageProcessService.processFile(
          item: item,
          settings: _settings,
          outputFolderPath: _settings.outputFolderPath,
        );

        if (!mounted) return;
        setState(() {
          _processing = false;
          final idx = _files.indexWhere((e) => e.path == item.path);
          if (idx >= 0) _files[idx] = item;
        });
        if (item.status == ProcessingStatus.success) {
          _message('${_s.newJpgDetected}：${item.fileName}');
        } else if (item.status == ProcessingStatus.skipped) {
          _message('${_s.skipped}：${item.fileName}');
        } else {
          _message('${_s.failed}：${item.fileName}', error: true);
        }
      }
      // 佇列處理完畢：清除「處理中」狀態通知，避免殘留在通知欄
      if (mounted) {
        await BackgroundService.cancelStatusNotification(
            statusNotificationProcessing);
      }
    } finally {
      _watchQueueProcessing = false;
    }
  }

  /// 立即處理來源資料夾中所有 JPG（使用 MonitorMode 檢查）
  Future<void> _processNow() async {
    final source = _settings.sourceFolderPath;
    if (source == null || source.isEmpty) {
      _message(_s.errorNotFoundSource, error: true);
      return;
    }
    if (_processing) {
      _message(_s.scanFolder, error: true);
      return;
    }
    await _scanAndProcess();
  }

  /// 掃描來源資料夾並立即處理（掃描完 → 列表 → 依序逐一處理）
  Future<void> _scanAndProcess() async {
    final source = _settings.sourceFolderPath;
    if (source == null || source.isEmpty) return;

    setState(() {
      _scanning = true;
      _processing = true;
      _paused = false;
      _stopRequested = false;
      _completed = 0;
      _success = 0;
      _failed = 0;
    });

    // 1. 掃描來源資料夾，先列成清單
    final files = await FileService.scanFolderForJpgs(source);
    if (!mounted) return;

    // 2. 過濾：已存在清單且已處理（且不重複處理）者跳過
    // 　　 另比對「輸出資料夾檔名是否包含來源檔名」跳過已處理者
    final outputNames = !_settings.reprocessFiles
        ? await ImageProcessService.listOutputFileNames(
            _settings.outputFolderPath)
        : const <String>{};
    final pending = files.where((f) {
      final existingIndex = _files.indexWhere((e) => e.path == f.path);
      if (existingIndex >= 0) {
        final existing = _files[existingIndex];
        if (existing.status == ProcessingStatus.processing) {
          return false;
        }
        // 當「重新處理」關閉時，跳過已處理（成功/已跳過）的檔案
        if (!_settings.reprocessFiles &&
            (existing.status == ProcessingStatus.success ||
                existing.status == ProcessingStatus.skipped)) {
          return false;
        }
      }
      // 當「重新處理」關閉時，輸出資料夾已有「包含來源檔名」的檔案 → 跳過
      if (!_settings.reprocessFiles &&
          ImageProcessService.outputNameContainsSource(
              f.fileName,
              outputFileNames: outputNames)) {
        return false;
      }
      return true;
    }).toList();

    if (pending.isEmpty) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _processing = false;
      });
      _message(_s.complete);
      return;
    }

    setState(() => _totalFiles = pending.length);

    // 3. 依序（一個一個）處理，支援暫停/停止，並回報狀態通知進度
    await _processSequentially(pending);

    if (!mounted) return;
    final wasStopped = _stopRequested;
    setState(() {
      _scanning = false;
      _processing = false;
      _paused = false;
      for (final item in pending) {
        final idx = _files.indexWhere((e) => e.path == item.path);
        if (idx >= 0) {
          _files[idx] = item;
        } else {
          _files.add(item);
        }
      }
    });
    // 清除「處理中」狀態通知
    await BackgroundService.cancelStatusNotification(
        statusNotificationProcessing);
    _message('${_s.complete}${wasStopped ? '（${_s.stopped}）' : ''}：'
            '${_s.success} $_success，${_s.failed} $_failed',
        error: _failed > 0);
  }

  Future<void> _saveSettings() async {
    try {
      await SettingsService.save(_settings);
      // 依監測模式註冊或取消定時任務（scheduled 或 both 都需要定時）
      if (_settings.monitorMode == MonitorMode.scheduled ||
          _settings.monitorMode == MonitorMode.both) {
        await BackgroundService.registerPeriodicTask(
          intervalMinutes: _settings.backgroundScanIntervalMinutes,
          settings: _settings,
        );
      } else {
        await BackgroundService.cancelTask();
      }
    } catch (e) {
      debugPrint('儲存設定失敗: $e');
    }
  }

  void _updateSettings(AppSettings settings) {
    setState(() => _settings = settings);
    _saveSettings();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _pickFiles() async {
    if (_processing) return;
    await PermissionService.requestAllPermissions();
    final files = await FileService.pickJpgFiles();
    if (files.isEmpty) return;
    setState(() => _files.addAll(files));
  }

  Future<void> _scanSourceFolder() async {
    if (_processing || _scanning) return;
    final source = _settings.sourceFolderPath;
    if (source == null || source.isEmpty) {
      _message(_s.errorNotFoundSource, error: true);
      return;
    }
    setState(() => _scanning = true);
    final files = await FileService.scanFolderForJpgs(source);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _files
        ..clear()
        ..addAll(files);
    });
    _message(files.isEmpty ? _s.complete : '${_s.selectJpg} ${files.length}');
  }

  /// 開始處理清單中的檔案（先列出可處理者 → 依序逐一處理）
  Future<void> _processFiles() async {
    if (_processing) return;
    if (_files.isEmpty) {
      _message('${_s.selectJpg}\n${_s.scanFolder}', error: true);
      return;
    }

    // 過濾出可以處理的檔案（先列表）
    final outputNames = !_settings.reprocessFiles
        ? await ImageProcessService.listOutputFileNames(
            _settings.outputFolderPath)
        : const <String>{};
    final existing = <FileItem>[];
    for (final item in _files) {
      // 進行中的項目永遠不重複處理
      if (item.status == ProcessingStatus.processing) continue;
      // 當「重新處理」關閉時，跳過已處理（成功/已跳過）的檔案
      if (!_settings.reprocessFiles &&
          (item.status == ProcessingStatus.success ||
              item.status == ProcessingStatus.skipped)) {
        continue;
      }
      // 當「重新處理」關閉時，輸出資料夾已有「包含來源檔名」的檔案 → 跳過
      if (!_settings.reprocessFiles &&
          ImageProcessService.outputNameContainsSource(
              item.fileName,
              outputFileNames: outputNames)) {
        continue;
      }
      if (await File(item.path).exists()) {
        existing.add(item);
      } else {
        item.status = ProcessingStatus.failed;
        item.errorMessage = _s.errorNotFoundSource;
      }
    }

    if (existing.isEmpty) {
      _message(_s.complete);
      return;
    }

    setState(() {
      _processing = true;
      _paused = false;
      _stopRequested = false;
      _completed = 0;
      _success = 0;
      _failed = 0;
      _totalFiles = existing.length;
    });

    // 依序（一個一個）處理
    await _processSequentially(existing);

    if (!mounted) return;
    final wasStopped = _stopRequested;
    setState(() {
      _processing = false;
      _paused = false;
    });
    // 清除「處理中」狀態通知
    await BackgroundService.cancelStatusNotification(
        statusNotificationProcessing);
    _message('${_s.complete}${wasStopped ? '（${_s.stopped}）' : ''}：'
            '${_s.success} $_success，${_s.failed} $_failed',
        error: _failed > 0);
  }

  /// 依序（一個一個）處理檔案，支援暫停/繼續與停止。
  ///
  /// - 暫停時會停在「下一個檔案的等待迴圈」，不繼續處理（可隨時繼續/停止）。
  /// - 停止時迴圈立即跳出，尚未處理的檔案維持 pending。
  /// - 每處理完一個檔案就更新 UI 統計與「處理中」狀態通知進度。
  Future<void> _processSequentially(List<FileItem> items) async {
    if (!mounted) return;
    var index = 0;
    for (final item in items) {
      // 停止檢查
      if (_stopRequested) break;
      // 暫停等待（不繼續處理下一個）
      while (_paused && mounted && !_stopRequested) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (_stopRequested) break;
      if (!mounted) {
        _stopRequested = true;
        break;
      }

      // 標記處理中（UI 顯示橙色圖示）
      item.status = ProcessingStatus.processing;
      setState(() {});

      index++;
      // 狀態通知：開始處理這一個
      await BackgroundService.showStatusNotification(
        id: statusNotificationProcessing,
        title: _paused ? _s.paused : _s.processing,
        body: '$index / ${items.length}：${item.fileName}',
      );

      await ImageProcessService.processFile(
        item: item,
        settings: _settings,
        outputFolderPath: _settings.outputFolderPath,
      );

      if (!mounted) return;
      setState(() {
        _completed++;
        if (item.status == ProcessingStatus.success) _success++;
        if (item.status == ProcessingStatus.failed) _failed++;
      });

      // 更新狀態通知進度
      await BackgroundService.showStatusNotification(
        id: statusNotificationProcessing,
        title: _paused ? _s.paused : _s.processing,
        body: '$index / ${items.length}',
      );
    }
  }

  /// 暫停 / 繼續處理
  void _togglePause() {
    if (!_processing) return;
    setState(() => _paused = !_paused);
    // 同步更新狀態通知標題（已暫停 / 處理中）。
    // 兜底：若 _totalFiles 尚未正確初始化（例如即時監測批次），改用清單長度，避免顯示「0/0」。
    final total = _totalFiles > 0 ? _totalFiles : _files.length;
    BackgroundService.showStatusNotification(
      id: statusNotificationProcessing,
      title: _paused ? _s.paused : _s.processing,
      body: '$_completed / $total',
    );
  }

  /// 停止處理（已處理的保留，其餘維持 pending）
  void _stopProcessing() {
    if (!_processing) return;
    setState(() {
      _stopRequested = true;
      _paused = false;
    });
  }

  /// 切換語言
  void _toggleLanguage() {
    final newLang = _settings.languageCode == 'zh' ? 'en' : 'zh';
    _updateSettings(_settings.copyWith(languageCode: newLang));
  }

  /// 切換明暗主題
  void _toggleTheme() {
    final newTheme =
        _settings.theme == AppTheme.dark ? AppTheme.light : AppTheme.dark;
    _updateSettings(_settings.copyWith(theme: newTheme));
    widget.onThemeChanged?.call(newTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.appTitle),
        centerTitle: true,
        actions: [
          // 明暗主題切換按鈕
          IconButton(
            tooltip: _s.themeTooltip,
            icon: Icon(
              _settings.theme == AppTheme.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: _toggleTheme,
          ),
          // 語言切換按鈕
          IconButton(
            tooltip: _s.languageName,
            icon: const Icon(Icons.language),
            onPressed: _toggleLanguage,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildModeSelector(),
          const SizedBox(height: 12),
          if (_settings.isAutoMode)
            AutoModePanel(
              targetSizeMB: _settings.targetSizeMB,
              minQuality: _settings.minQuality,
              minResolution: _settings.minResolution,
              capacityStrategy: _settings.capacityStrategy,
              onTargetSizeChanged: (value) =>
                  _updateSettings(_settings.copyWith(targetSizeMB: value)),
              onMinQualityChanged: (value) =>
                  _updateSettings(_settings.copyWith(minQuality: value)),
              onMinResolutionChanged: (value) => _updateSettings(
                _settings.copyWith(minResolution: value),
              ),
              onCapacityStrategyChanged: (value) =>
                  _updateSettings(_settings.copyWith(capacityStrategy: value)),
              strings: _s,
            )
          else
            ManualModePanel(
              quality: _settings.quality,
              resolution: _settings.resolution,
              onQualityChanged: (value) =>
                  _updateSettings(_settings.copyWith(quality: value)),
              onResolutionChanged: (value) =>
                  _updateSettings(_settings.copyWith(resolution: value)),
              strings: _s,
            ),
          const SizedBox(height: 12),
          FolderPickerCard(
            sourceFolderPath: _settings.sourceFolderPath,
            outputFolderPath: _settings.outputFolderPath,
            onPickSource: () async {
              final path = await FileService.pickSourceFolder();
              if (path != null) {
                _updateSettings(_settings.copyWith(sourceFolderPath: path));
              }
            },
            onPickOutput: () async {
              final path = await FileService.pickOutputFolder();
              if (path != null) {
                _updateSettings(_settings.copyWith(outputFolderPath: path));
              }
            },
            strings: _s,
          ),
          const SizedBox(height: 12),
          BackgroundAutoCard(
            monitorMode: _settings.monitorMode,
            intervalMinutes: _settings.backgroundScanIntervalMinutes,
            onMonitorModeChanged: (mode) {
              _updateSettings(_settings.copyWith(monitorMode: mode));
              // 依模式啟動/停止即時監測
              if (mode == MonitorMode.realtime ||
                  mode == MonitorMode.both) {
                _startWatching();
              } else {
                _stopWatching();
              }
            },
            onIntervalChanged: (value) => _updateSettings(
              _settings.copyWith(backgroundScanIntervalMinutes: value),
            ),
            strings: _s,
          ),
          const SizedBox(height: 12),
          _buildRealTimeCard(),
          const SizedBox(height: 12),
          _buildFileActions(),
          const SizedBox(height: 12),
          _buildProcessControls(),
          const SizedBox(height: 12),
          FileListPanel(
            files: _files,
            isProcessing: _processing,
            onRemove: (item) => setState(() => _files.remove(item)),
            strings: _s,
          ),
          const SizedBox(height: 12),
          // 廣告位（暫時註解掉，待日後掛接 AdMob 等 SDK 時再啟用）
          // _buildAdSlot(),
          const SizedBox(height: 120),
        ],
      ),
      bottomNavigationBar: _files.isEmpty ? null : _buildProcessBar(),
    );
  }

  /// 即時監測與立即處理卡片
  Widget _buildRealTimeCard() {
    // 僅在即時監測模式下顯示監測中狀態
    final isRealtime = _settings.monitorMode == MonitorMode.realtime ||
        _settings.monitorMode == MonitorMode.both;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRealtime && _watching
                      ? Icons.radar
                      : Icons.radar_outlined,
                  color: isRealtime && _watching ? Colors.teal : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _s.realtimeMonitoring,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isRealtime && _watching)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(_s.watching,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.teal)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isRealtime
                  ? _s.realtimeImmediate
                  : _s.scheduledRealTime,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _processing ? null : _processNow,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_s.process),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isRealtime && _watching)
                        ? _stopWatching
                        : _startWatching,
                    icon: Icon(
                        (isRealtime && _watching)
                            ? Icons.stop
                            : Icons.visibility_outlined),
                    label: Text((isRealtime && _watching)
                        ? _s.stopWatching
                        : _s.startWatching),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s.compressMode, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.tune), label: Text(_s.manualMode)),
                ButtonSegment(value: true, icon: const Icon(Icons.auto_awesome), label: Text(_s.autoMode)),
              ],
              selected: {_settings.isAutoMode},
              onSelectionChanged: (value) =>
                  _updateSettings(_settings.copyWith(isAutoMode: value.first)),
            ),
          ],
        ),
      ),
    );
  }

  /// 處理控制列：停止／暫停·繼續＋「是否重新處理相同檔案」開關
  ///
  /// 放在「選擇來源」與「處理區塊」之間，讓使用者在上方預先設定
  /// 是否要重新處理（預設關閉），並在處理中可隨時暫停/繼續或停止。
  Widget _buildProcessControls() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一列：停止 / 暫停·繼續（僅在處理中可操作）
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _processing ? _stopProcessing : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(_s.stopProcessing),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? _togglePause : null,
                    icon: Icon(
                      _paused ? Icons.play_arrow : Icons.pause_circle_outlined,
                    ),
                    label: Text(
                      _paused ? _s.resumeProcessing : _s.pauseProcessing,
                    ),
                  ),
                ),
              ],
            ),
            // 暫停提示
            if (_paused) ...[
              const SizedBox(height: 6),
              Text(
                _s.paused,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            // 第二列：「是否重新處理相同檔案」開關（可預先設定，預設關閉）
            Row(
              children: [
                Expanded(
                  child: Text(
                    _s.reprocessSameFile,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _settings.reprocessFiles,
                  onChanged: (value) =>
                      _updateSettings(_settings.copyWith(reprocessFiles: value)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s.selectSource, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _processing ? null : _pickFiles,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_s.selectJpg),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _scanSourceFolder,
                    icon: _scanning
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: Text(_s.scanFolder),
                  ),
                ),
              ],
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _processing ? null : () => setState(_files.clear),
                  icon: const Icon(Icons.clear_all),
                  label: Text(_s.clearList),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 廣告位（暫時註解掉，待日後掛接 AdMob 等 SDK 時再啟用）
  // ---------------------------------------------------------------------------
  // 在頁面底部保留固定高度的空間給廣告 Banner（佔位框）。
  // Widget _buildAdSlot() {
  //   return Container(
  //     height: 60,
  //     width: double.infinity,
  //     alignment: Alignment.center,
  //     decoration: BoxDecoration(
  //       color: Theme.of(context).colorScheme.surfaceContainerHighest
  //           .withValues(alpha: 0.4),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(
  //         color: Theme.of(context).colorScheme.outlineVariant,
  //       ),
  //     ),
  //     child: Text(
  //       _s.adSlotPlaceholder,
  //       style: Theme.of(context).textTheme.bodySmall?.copyWith(
  //             color: Theme.of(context).colorScheme.outline,
  //           ),
  //     ),
  //   );
  // }

  Widget _buildProcessBar() {
    final progress = _files.isEmpty ? 0.0 : _completed / _files.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_processing) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text('${_s.processing} $_completed / ${_files.length}'),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: _processing ? null : _processFiles,
              icon: const Icon(Icons.compress),
              label: Text(_processing ? _s.processing : '${_s.process} ${_files.length}'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
