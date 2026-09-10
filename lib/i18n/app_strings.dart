enum AppLanguage { zhTW, en }

/// 中英文對照字串
class AppStrings {
  final String appTitle;
  final String compressMode;
  final String manualMode;
  final String autoMode;
  final String quality;
  final String resolution;
  final String targetSize;
  final String targetSizeHint;
  final String minQuality;
  final String minResolution;
  final String sourceFolder;
  final String outputFolder;
  final String pickFolder;
  final String startWatching;
  final String stopWatching;
  final String watching;
  final String realtimeMonitoring;
  final String scheduledMonitoring;
  final String monitoringOff;
  final String backgroundAuto;
  final String scanningInterval;
  final String selectJpg;
  final String scanFolder;
  final String clearList;
  final String processing;
  final String process;
  final String autoTitle;
  final String manualTitle;
  final String monitoringBadge;
  final String languageName;
  final String realtimeImmediate;
  final String scheduledRealTime;
  final String none;
  final String monitorMode;
  final String inputTargetSize;
  final String minQualityLabel;
  final String minResolutionLabel;
  final String newJpgDetected;
  final String skipped;
  final String success;
  final String failed;
  final String complete;
  final String errorNotFoundSource;
  final String capacityStrategyLabel;
  final String capacityStrategyA;
  final String capacityStrategyB;
  final String capacityStrategyADesc;
  final String capacityStrategyBDesc;
  final String scheduledRealtime;
  final String adSlotPlaceholder;
  final String themeTooltip;
  final String reprocessSameFile;
  final String pageSizeLabel;
  final String selectSource;
  final String fileListTitle;
  final String stopProcessing;
  final String pauseProcessing;
  final String resumeProcessing;
  final String paused;
  final String stopped;

  const AppStrings({
    required this.appTitle,
    required this.compressMode,
    required this.manualMode,
    required this.autoMode,
    required this.quality,
    required this.resolution,
    required this.targetSize,
    required this.targetSizeHint,
    required this.minQuality,
    required this.minResolution,
    required this.sourceFolder,
    required this.outputFolder,
    required this.pickFolder,
    required this.startWatching,
    required this.stopWatching,
    required this.watching,
    required this.realtimeMonitoring,
    required this.scheduledMonitoring,
    required this.monitoringOff,
    required this.backgroundAuto,
    required this.scanningInterval,
    required this.selectJpg,
    required this.scanFolder,
    required this.clearList,
    required this.processing,
    required this.process,
    required this.autoTitle,
    required this.manualTitle,
    required this.monitoringBadge,
    required this.languageName,
    required this.realtimeImmediate,
    required this.scheduledRealTime,
    required this.none,
    required this.monitorMode,
    required this.inputTargetSize,
    required this.minQualityLabel,
    required this.minResolutionLabel,
    required this.newJpgDetected,
    required this.skipped,
    required this.success,
    required this.failed,
    required this.complete,
    required this.errorNotFoundSource,
    required this.capacityStrategyLabel,
    required this.capacityStrategyA,
    required this.capacityStrategyB,
    required this.capacityStrategyADesc,
    required this.capacityStrategyBDesc,
    required this.scheduledRealtime,
    required this.adSlotPlaceholder,
    required this.themeTooltip,
    required this.reprocessSameFile,
    required this.pageSizeLabel,
    required this.selectSource,
    required this.fileListTitle,
    required this.stopProcessing,
    required this.pauseProcessing,
    required this.resumeProcessing,
    required this.paused,
    required this.stopped,
  });

  /// 正體中文
  static const AppStrings zh = AppStrings(
    appTitle: 'JPG 瘦身工具',
    compressMode: '壓縮模式',
    manualMode: '手動設定',
    autoMode: '自動 10MB',
    quality: '品質',
    resolution: '解析度',
    targetSize: '目標容量 (MB)',
    targetSizeHint: '輸入輸出檔案大小上限，可低於 1MB，例如 0.5 = 500KB',
    minQuality: '品質最低下限',
    minResolution: '解析度最低下限',
    sourceFolder: '來源資料夾',
    outputFolder: '輸出資料夾',
    pickFolder: '選擇',
    startWatching: '開始監測',
    stopWatching: '停止監測',
    watching: '監測中',
    realtimeMonitoring: '即時監測',
    scheduledMonitoring: '定時監測',
    monitoringOff: '關閉監測',
    backgroundAuto: '背景自動化',
    scanningInterval: '掃描間隔（分鐘）',
    selectJpg: '選擇要處理的 JPG',
    scanFolder: '掃描來源資料夾',
    clearList: '清除清單',
    processing: '處理中…',
    process: '開始處理',
    autoTitle: '自動設定：目標容量',
    manualTitle: '手動設定',
    monitoringBadge: '監測模式',
    languageName: 'English',
    realtimeImmediate: '即時處理',
    scheduledRealTime: '定時處理',
    none: '關閉',
    monitorMode: '監測方式',
    inputTargetSize: '目標大小 (MB)',
    minQualityLabel: '品質下限',
    minResolutionLabel: '解析度下限',
    newJpgDetected: '偵測到新檔案，已立即處理',
    skipped: '已跳過',
    success: '成功',
    failed: '失敗',
    complete: '處理完成',
    errorNotFoundSource: '來源資料夾不存在',
    capacityStrategyLabel: '容量策略',
    capacityStrategyA: 'A：跳過下限',
    capacityStrategyB: 'B：以下限為主',
    capacityStrategyADesc: '若無法達到目標容量，突破品質/解析度下限，盡量達到目標。',
    capacityStrategyBDesc: '若無法達到目標容量，維持品質/解析度下限，即使超過目標。',
    scheduledRealtime: '定時 + 即時（兩者同時運作）',
    adSlotPlaceholder: '廣告位區（暫留）',
    themeTooltip: '切換明暗主題',
    reprocessSameFile: '重新處理相同檔案',
    pageSizeLabel: '每頁',
    selectSource: '選擇來源',
    fileListTitle: '處理區塊',
    stopProcessing: '停止',
    pauseProcessing: '暫停',
    resumeProcessing: '繼續',
    paused: '已暫停',
    stopped: '已停止',
  );

  /// English (US)
  static const AppStrings en = AppStrings(
    appTitle: 'JPG Slimming Tool',
    compressMode: 'Compress Mode',
    manualMode: 'Manual',
    autoMode: 'Auto 10MB',
    quality: 'Quality',
    resolution: 'Resolution',
    targetSize: 'Target Size (MB)',
    targetSizeHint: 'Enter the max output size (can be below 1MB, e.g. 0.5 = 500KB)',
    minQuality: 'Min Quality',
    minResolution: 'Min Resolution',
    sourceFolder: 'Source Folder',
    outputFolder: 'Output Folder',
    pickFolder: 'Pick',
    startWatching: 'Start Watching',
    stopWatching: 'Stop Watching',
    watching: 'Watching',
    realtimeMonitoring: 'Realtime Monitoring',
    scheduledMonitoring: 'Scheduled Monitoring',
    monitoringOff: 'Monitoring Off',
    backgroundAuto: 'Background Auto',
    scanningInterval: 'Scan Interval (min)',
    selectJpg: 'Select JPG',
    scanFolder: 'Scan Source Folder',
    clearList: 'Clear List',
    processing: 'Processing…',
    process: 'Process',
    autoTitle: 'Auto Mode: Target Size',
    manualTitle: 'Manual Mode',
    monitoringBadge: 'Monitoring Mode',
    languageName: '繁體中文 (TW)',
    realtimeImmediate: 'Process Immediately',
    scheduledRealTime: 'Scheduled Process',
    none: 'Off',
    monitorMode: 'Monitoring Mode',
    inputTargetSize: 'Target Size (MB)',
    minQualityLabel: 'Min Quality',
    minResolutionLabel: 'Min Resolution',
    newJpgDetected: 'New JPG detected - processed',
    skipped: 'Skipped',
    success: 'Success',
    failed: 'Failed',
    complete: 'Complete',
    errorNotFoundSource: 'Source folder not found',
    capacityStrategyLabel: 'Capacity Strategy',
    capacityStrategyA: 'A: Skip Limits',
    capacityStrategyB: 'B: Keep Limits',
    capacityStrategyADesc: 'If target cannot be met, break quality/resolution limits to reach the target.',
    capacityStrategyBDesc: 'If target cannot be met, keep quality/resolution limits even if exceeding the target.',
    scheduledRealtime: 'Scheduled + Realtime (both running)',
    adSlotPlaceholder: 'Ad Slot (Reserved)',
    themeTooltip: 'Toggle Light/Dark',
    reprocessSameFile: 'Reprocess same file',
    pageSizeLabel: 'Per page',
    selectSource: 'Select Source',
    fileListTitle: 'Process Block',
    stopProcessing: 'Stop',
    pauseProcessing: 'Pause',
    resumeProcessing: 'Resume',
    paused: 'Paused',
    stopped: 'Stopped',
  );

  /// 依語言代碼取得字串
  static AppStrings of(String languageCode) =>
      languageCode == 'en' ? en : zh;
}
