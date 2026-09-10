enum MonitorMode {
  /// 關閉自動化
  off,

  /// 定時監測（WorkManager 週期掃描）
  scheduled,

  /// 即時監測（Directory.watch 即時偵測）
  realtime,

  /// 定時 + 即時（兩者同時運作）
  both,
}

/// 應用程式主題（明 / 暗）
enum AppTheme {
  /// 明亮主題
  light,

  /// 暗色主題
  dark,
}

/// 容量策略（自動模式無法達到目標容量時的處理方式）
enum CapacityStrategy {
  /// A：跳過下限限制（突破品質/解析度下限，盡量達到目標容量）
  skipLimits,

  /// B：以下限為主（維持品質/解析度下限，即使超過目標容量）
  keepLimits,
}

/// 應用程式設定
class AppSettings {
  static const int autoTargetSizeBytes = 10 * 1024 * 1024;
  static const double defaultTargetSizeMB = 10.0;

  /// 操作模式：手動 / 自動(目標容量)
  final bool isAutoMode;

  // ---- 手動模式設定 ----
  /// 品質百分比 (1-100)
  final int quality;
  /// 解析度百分比 (1-100)
  final int resolution;

  // ---- 自動模式設定 ----
  /// 目標輸出大小 (MB)，使用者可輸入，預設 10MB，可低於 1MB
  final double targetSizeMB;
  /// 品質最低下限 (1-100，預設 80)
  final int minQuality;
  /// 解析度最低下限 (1-100，預設 75)
  final int minResolution;
  /// 容量策略（預設 B：以下限為主）
  final CapacityStrategy capacityStrategy;

  // ---- 共用設定 ----
  /// 預設來源資料夾
  final String? sourceFolderPath;
  /// 預設輸出資料夾
  final String? outputFolderPath;
  /// 監測模式（off / scheduled / realtime / both）
  final MonitorMode monitorMode;
  /// 背景自動化掃描間隔 (分鐘)
  final int backgroundScanIntervalMinutes;
  /// 語言代碼（'zh' = 繁體中文 / 'en' = English）
  final String languageCode;

  /// 主題（light / dark）
  final AppTheme theme;

  /// 是否重複處理相同檔案（預設 false：關閉時跳過已處理/有輸出的檔案）
  final bool reprocessFiles;

  const AppSettings({
    this.isAutoMode = false,
    this.quality = 85,
    this.resolution = 100,
    this.targetSizeMB = defaultTargetSizeMB,
    this.minQuality = 80,
    this.minResolution = 75,
    this.capacityStrategy = CapacityStrategy.keepLimits,
    this.sourceFolderPath,
    this.outputFolderPath,
    this.monitorMode = MonitorMode.off,
    this.backgroundScanIntervalMinutes = 30,
    this.languageCode = 'zh',
    this.theme = AppTheme.light,
    this.reprocessFiles = false,
  });

  /// 目標容量換算成 bytes
  int get targetSizeBytes => (targetSizeMB * 1024 * 1024).round();

  AppSettings copyWith({
    bool? isAutoMode,
    int? quality,
    int? resolution,
    double? targetSizeMB,
    int? minQuality,
    int? minResolution,
    CapacityStrategy? capacityStrategy,
    String? sourceFolderPath,
    String? outputFolderPath,
    MonitorMode? monitorMode,
    int? backgroundScanIntervalMinutes,
    String? languageCode,
    AppTheme? theme,
    bool? reprocessFiles,
  }) {
    return AppSettings(
      isAutoMode: isAutoMode ?? this.isAutoMode,
      quality: quality ?? this.quality,
      resolution: resolution ?? this.resolution,
      targetSizeMB: targetSizeMB ?? this.targetSizeMB,
      minQuality: (minQuality ?? this.minQuality).clamp(10, 100).toInt(),
      minResolution:
          (minResolution ?? this.minResolution).clamp(10, 100).toInt(),
      capacityStrategy: capacityStrategy ?? this.capacityStrategy,
      sourceFolderPath: sourceFolderPath ?? this.sourceFolderPath,
      outputFolderPath: outputFolderPath ?? this.outputFolderPath,
      monitorMode: monitorMode ?? this.monitorMode,
      backgroundScanIntervalMinutes:
          backgroundScanIntervalMinutes ?? this.backgroundScanIntervalMinutes,
      languageCode: languageCode ?? this.languageCode,
      theme: theme ?? this.theme,
      reprocessFiles: reprocessFiles ?? this.reprocessFiles,
    );
  }

  /// 轉為 Map 以便序列化儲存
  Map<String, dynamic> toJson() {
    return {
      'isAutoMode': isAutoMode,
      'quality': quality,
      'resolution': resolution,
      'targetSizeMB': targetSizeMB,
      'minQuality': minQuality,
      'minResolution': minResolution,
      'capacityStrategy': capacityStrategy.name,
      'sourceFolderPath': sourceFolderPath,
      'outputFolderPath': outputFolderPath,
      'monitorMode': monitorMode.name,
      'backgroundScanIntervalMinutes': backgroundScanIntervalMinutes,
      'languageCode': languageCode,
      'theme': theme.name,
      'reprocessFiles': reprocessFiles,
    };
  }

  /// 由 Map 還原設定
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // 舊版相容：若無 monitorMode，由 enableBackgroundAuto 推導
    final legacyEnabled = json['enableBackgroundAuto'] as bool? ?? false;
    var monitorMode = MonitorMode.off;
    final rawMode = json['monitorMode'] as String?;
    if (rawMode != null) {
      monitorMode = MonitorMode.values.asNameMap()[rawMode] ?? MonitorMode.off;
    } else if (legacyEnabled) {
      // 舊版預設為定時監測
      monitorMode = MonitorMode.scheduled;
    }

    // 舊版相容：若無 targetSizeMB，由 targetSizeBytes 推導（預設 10MB）
    var targetMB = (json['targetSizeMB'] as num?)?.toDouble() ??
        defaultTargetSizeMB;
    if (json.containsKey('targetSizeBytes') &&
        !json.containsKey('targetSizeMB')) {
      final bytes = json['targetSizeBytes'] as int?;
      if (bytes != null && bytes > 0) {
        targetMB = bytes / (1024 * 1024);
      }
    }

    // 容量策略（預設 B：keepLimits）
    var capacityStrategy = CapacityStrategy.keepLimits;
    final rawStrategy = json['capacityStrategy'] as String?;
    if (rawStrategy != null) {
      capacityStrategy =
          CapacityStrategy.values.asNameMap()[rawStrategy] ??
              CapacityStrategy.keepLimits;
    }

    // 主題（預設 light）
    var theme = AppTheme.light;
    final rawTheme = json['theme'] as String?;
    if (rawTheme != null) {
      theme = AppTheme.values.asNameMap()[rawTheme] ?? AppTheme.light;
    }

    return AppSettings(
      isAutoMode: json['isAutoMode'] as bool? ?? false,
      quality: json['quality'] as int? ?? 85,
      resolution: json['resolution'] as int? ?? 100,
      targetSizeMB: targetMB,
      minQuality: (json['minQuality'] as int? ?? 80).clamp(10, 100).toInt(),
      minResolution:
          (json['minResolution'] as int? ?? 75).clamp(10, 100).toInt(),
      capacityStrategy: capacityStrategy,
      sourceFolderPath: json['sourceFolderPath'] as String?,
      outputFolderPath: json['outputFolderPath'] as String?,
      monitorMode: monitorMode,
      backgroundScanIntervalMinutes:
          json['backgroundScanIntervalMinutes'] as int? ?? 30,
      languageCode: json['languageCode'] as String? ?? 'zh',
      theme: theme,
      reprocessFiles: json['reprocessFiles'] as bool? ?? false,
    );
  }
}

/// 檔案處理狀態
enum ProcessingStatus {
  pending,
  processing,
  success,
  failed,
  skipped, // 已存在相同輸出
}
