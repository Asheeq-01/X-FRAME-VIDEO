import 'dart:io';

enum OutputFormat {
  png('PNG', 'png', 'Best Quality'),
  jpg('JPG', 'jpg', 'Smaller Size'),
  webp('WEBP', 'webp', 'Best Compression');

  const OutputFormat(this.label, this.extension, this.recommendation);

  final String label;
  final String extension;
  final String recommendation;
}

enum JobStatus { pending, processing, paused, completed, failed, canceled }

enum ThemePreference { system, light, dark }

enum CompressionCodec {
  h264('H.264', 'libx264'),
  h265('H.265', 'libx265'),
  vp9('VP9', 'libvpx-vp9');

  const CompressionCodec(this.label, this.ffmpegName);

  final String label;
  final String ffmpegName;
}

enum CompressionPreset {
  ultrafast('Ultra Fast', 'ultrafast'),
  fast('Fast', 'fast'),
  medium('Medium', 'medium'),
  slow('Slow (Better Quality)', 'slow');

  const CompressionPreset(this.label, this.ffmpegName);

  final String label;
  final String ffmpegName;
}

class VideoMetadata {
  const VideoMetadata({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
    required this.codec,
    required this.format,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final Duration duration;
  final int width;
  final int height;
  final double fps;
  final int bitrate;
  final String codec;
  final String format;
}

class ExtractionSettings {
  const ExtractionSettings({
    this.fps = 2,
    this.format = OutputFormat.png,
    this.outputDirectory,
    this.startTime,
    this.endTime,
  });

  final double fps;
  final OutputFormat format;
  final String? outputDirectory;
  final Duration? startTime;
  final Duration? endTime;

  ExtractionSettings copyWith({
    double? fps,
    OutputFormat? format,
    String? outputDirectory,
    Duration? startTime,
    Duration? endTime,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return ExtractionSettings(
      fps: fps ?? this.fps,
      format: format ?? this.format,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      startTime: clearStart ? null : startTime ?? this.startTime,
      endTime: clearEnd ? null : endTime ?? this.endTime,
    );
  }
}

class FrameFile {
  const FrameFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    this.width,
    this.height,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final int? width;
  final int? height;

  static Future<FrameFile> fromFile(
    File file, {
    int? width,
    int? height,
  }) async {
    final stat = await file.stat();
    return FrameFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      sizeBytes: stat.size,
      createdAt: stat.changed,
      width: width,
      height: height,
    );
  }
}

class ExtractionProgress {
  const ExtractionProgress({
    this.percent = 0,
    this.framesExtracted = 0,
    this.elapsed = Duration.zero,
    this.remaining,
    this.speedFps = 0,
    this.outputSizeBytes = 0,
    this.message = 'Idle',
  });

  final double percent;
  final int framesExtracted;
  final Duration elapsed;
  final Duration? remaining;
  final double speedFps;
  final int outputSizeBytes;
  final String message;

  ExtractionProgress copyWith({
    double? percent,
    int? framesExtracted,
    Duration? elapsed,
    Duration? remaining,
    double? speedFps,
    int? outputSizeBytes,
    String? message,
  }) {
    return ExtractionProgress(
      percent: percent ?? this.percent,
      framesExtracted: framesExtracted ?? this.framesExtracted,
      elapsed: elapsed ?? this.elapsed,
      remaining: remaining ?? this.remaining,
      speedFps: speedFps ?? this.speedFps,
      outputSizeBytes: outputSizeBytes ?? this.outputSizeBytes,
      message: message ?? this.message,
    );
  }
}

class BatchJob {
  const BatchJob({
    required this.id,
    required this.path,
    required this.name,
    this.status = JobStatus.pending,
    this.error,
    this.progress = 0,
  });

  final String id;
  final String path;
  final String name;
  final JobStatus status;
  final String? error;
  final double progress;

  BatchJob copyWith({JobStatus? status, String? error, double? progress}) {
    return BatchJob(
      id: id,
      path: path,
      name: name,
      status: status ?? this.status,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.videoName,
    required this.date,
    required this.fps,
    required this.format,
    required this.framesGenerated,
    required this.outputLocation,
    required this.status,
  });

  final String id;
  final String videoName;
  final DateTime date;
  final double fps;
  final OutputFormat format;
  final int framesGenerated;
  final String outputLocation;
  final JobStatus status;

  Map<String, Object?> toJson() => {
    'id': id,
    'videoName': videoName,
    'date': date.toIso8601String(),
    'fps': fps,
    'format': format.name,
    'framesGenerated': framesGenerated,
    'outputLocation': outputLocation,
    'status': status.name,
  };

  static HistoryEntry fromJson(Map<String, Object?> json) {
    return HistoryEntry(
      id: json['id'] as String,
      videoName: json['videoName'] as String,
      date: DateTime.parse(json['date'] as String),
      fps: (json['fps'] as num).toDouble(),
      format: OutputFormat.values.byName(json['format'] as String),
      framesGenerated: json['framesGenerated'] as int,
      outputLocation: json['outputLocation'] as String,
      status: JobStatus.values.byName(json['status'] as String),
    );
  }
}

class UserSettings {
  const UserSettings({
    this.defaultFps = 2,
    this.defaultFormat = OutputFormat.png,
    this.defaultOutputFolder,
    this.theme = ThemePreference.system,
    this.thumbnailSize = 160,
    this.maxConcurrentTasks = 1,
  });

  final double defaultFps;
  final OutputFormat defaultFormat;
  final String? defaultOutputFolder;
  final ThemePreference theme;
  final double thumbnailSize;
  final int maxConcurrentTasks;

  UserSettings copyWith({
    double? defaultFps,
    OutputFormat? defaultFormat,
    String? defaultOutputFolder,
    ThemePreference? theme,
    double? thumbnailSize,
    int? maxConcurrentTasks,
  }) {
    return UserSettings(
      defaultFps: defaultFps ?? this.defaultFps,
      defaultFormat: defaultFormat ?? this.defaultFormat,
      defaultOutputFolder: defaultOutputFolder ?? this.defaultOutputFolder,
      theme: theme ?? this.theme,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
    );
  }

  Map<String, Object?> toJson() => {
    'defaultFps': defaultFps,
    'defaultFormat': defaultFormat.name,
    'defaultOutputFolder': defaultOutputFolder,
    'theme': theme.name,
    'thumbnailSize': thumbnailSize,
    'maxConcurrentTasks': maxConcurrentTasks,
  };

  static UserSettings fromJson(Map<String, Object?> json) {
    return UserSettings(
      defaultFps: ((json['defaultFps'] as num?) ?? 2).toDouble(),
      defaultFormat: OutputFormat.values.byName(
        (json['defaultFormat'] as String?) ?? 'png',
      ),
      defaultOutputFolder: json['defaultOutputFolder'] as String?,
      theme: ThemePreference.values.byName(
        (json['theme'] as String?) ?? 'system',
      ),
      thumbnailSize: ((json['thumbnailSize'] as num?) ?? 160).toDouble(),
      maxConcurrentTasks: ((json['maxConcurrentTasks'] as num?) ?? 1).toInt(),
    );
  }
}

// ── Phase 4 Models ──────────────────────────────────────────────────────────

class SceneDetectionSettings {
  const SceneDetectionSettings({
    this.threshold = 0.3,
    this.minSceneDurationSeconds = 1.0,
  });

  final double threshold;
  final double minSceneDurationSeconds;

  SceneDetectionSettings copyWith({
    double? threshold,
    double? minSceneDurationSeconds,
  }) {
    return SceneDetectionSettings(
      threshold: threshold ?? this.threshold,
      minSceneDurationSeconds:
          minSceneDurationSeconds ?? this.minSceneDurationSeconds,
    );
  }
}

class SceneInfo {
  const SceneInfo({
    required this.timestamp,
    required this.score,
    required this.index,
  });

  final Duration timestamp;
  final double score;
  final int index;
}

class ContactSheetSettings {
  const ContactSheetSettings({
    this.columns = 4,
    this.rows = 4,
    this.thumbWidth = 320,
    this.showTimestamps = true,
    this.format = OutputFormat.jpg,
  });

  final int columns;
  final int rows;
  final int thumbWidth;
  final bool showTimestamps;
  final OutputFormat format;

  ContactSheetSettings copyWith({
    int? columns,
    int? rows,
    int? thumbWidth,
    bool? showTimestamps,
    OutputFormat? format,
  }) {
    return ContactSheetSettings(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      thumbWidth: thumbWidth ?? this.thumbWidth,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      format: format ?? this.format,
    );
  }
}

class GifSettings {
  const GifSettings({
    this.fps = 10,
    this.width = 480,
    this.startTime,
    this.endTime,
  });

  final double fps;
  final int width;
  final Duration? startTime;
  final Duration? endTime;

  GifSettings copyWith({
    double? fps,
    int? width,
    Duration? startTime,
    Duration? endTime,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return GifSettings(
      fps: fps ?? this.fps,
      width: width ?? this.width,
      startTime: clearStart ? null : startTime ?? this.startTime,
      endTime: clearEnd ? null : endTime ?? this.endTime,
    );
  }
}

class CompressionSettings {
  const CompressionSettings({
    this.codec = CompressionCodec.h264,
    this.preset = CompressionPreset.medium,
    this.crf = 23,
    this.scalePercent = 100,
    this.audioBitrate = 128,
  });

  final CompressionCodec codec;
  final CompressionPreset preset;
  final int crf;
  final int scalePercent;
  final int audioBitrate;

  CompressionSettings copyWith({
    CompressionCodec? codec,
    CompressionPreset? preset,
    int? crf,
    int? scalePercent,
    int? audioBitrate,
  }) {
    return CompressionSettings(
      codec: codec ?? this.codec,
      preset: preset ?? this.preset,
      crf: crf ?? this.crf,
      scalePercent: scalePercent ?? this.scalePercent,
      audioBitrate: audioBitrate ?? this.audioBitrate,
    );
  }
}

class CompressionProgress {
  const CompressionProgress({
    this.percent = 0,
    this.currentTime = Duration.zero,
    this.speed = '',
    this.outputSizeBytes = 0,
    this.message = 'Idle',
  });

  final double percent;
  final Duration currentTime;
  final String speed;
  final int outputSizeBytes;
  final String message;
}

class FrameAnalysis {
  const FrameAnalysis({
    required this.framePath,
    this.blurScore = 0,
    this.isDuplicate = false,
    this.qualityRank = 0,
  });

  final String framePath;
  final double blurScore;
  final bool isDuplicate;
  final int qualityRank;
}

// ── App State ───────────────────────────────────────────────────────────────

class AppState {
  const AppState({
    this.metadata,
    this.settings = const ExtractionSettings(),
    this.progress = const ExtractionProgress(),
    this.frames = const [],
    this.queue = const [],
    this.history = const [],
    this.userSettings = const UserSettings(),
    this.isLoadingMetadata = false,
    this.isExtracting = false,
    this.isPaused = false,
    this.isExportingZip = false,
    this.zipProgress = 0,
    this.selectedTab = 0,
    this.errorMessage,
    this.infoMessage,
    // Phase 4 state
    this.sceneSettings = const SceneDetectionSettings(),
    this.detectedScenes = const [],
    this.isDetectingScenes = false,
    this.sceneDetectionProgress = 0,
    this.contactSheetSettings = const ContactSheetSettings(),
    this.isGeneratingContactSheet = false,
    this.contactSheetPath,
    this.gifSettings = const GifSettings(),
    this.isCreatingGif = false,
    this.gifProgress = 0,
    this.gifOutputPath,
    this.compressionSettings = const CompressionSettings(),
    this.compressionProgress = const CompressionProgress(),
    this.isCompressing = false,
    this.compressedOutputPath,
    this.frameAnalyses = const {},
    this.isAnalyzingFrames = false,
    this.analysisProgress = 0,
  });

  final VideoMetadata? metadata;
  final ExtractionSettings settings;
  final ExtractionProgress progress;
  final List<FrameFile> frames;
  final List<BatchJob> queue;
  final List<HistoryEntry> history;
  final UserSettings userSettings;
  final bool isLoadingMetadata;
  final bool isExtracting;
  final bool isPaused;
  final bool isExportingZip;
  final double zipProgress;
  final int selectedTab;
  final String? errorMessage;
  final String? infoMessage;

  // Phase 4 state
  final SceneDetectionSettings sceneSettings;
  final List<SceneInfo> detectedScenes;
  final bool isDetectingScenes;
  final double sceneDetectionProgress;
  final ContactSheetSettings contactSheetSettings;
  final bool isGeneratingContactSheet;
  final String? contactSheetPath;
  final GifSettings gifSettings;
  final bool isCreatingGif;
  final double gifProgress;
  final String? gifOutputPath;
  final CompressionSettings compressionSettings;
  final CompressionProgress compressionProgress;
  final bool isCompressing;
  final String? compressedOutputPath;
  final Map<String, FrameAnalysis> frameAnalyses;
  final bool isAnalyzingFrames;
  final double analysisProgress;

  AppState copyWith({
    VideoMetadata? metadata,
    ExtractionSettings? settings,
    ExtractionProgress? progress,
    List<FrameFile>? frames,
    List<BatchJob>? queue,
    List<HistoryEntry>? history,
    UserSettings? userSettings,
    bool? isLoadingMetadata,
    bool? isExtracting,
    bool? isPaused,
    bool? isExportingZip,
    double? zipProgress,
    int? selectedTab,
    String? errorMessage,
    String? infoMessage,
    bool clearMetadata = false,
    bool clearMessages = false,
    // Phase 4
    SceneDetectionSettings? sceneSettings,
    List<SceneInfo>? detectedScenes,
    bool? isDetectingScenes,
    double? sceneDetectionProgress,
    ContactSheetSettings? contactSheetSettings,
    bool? isGeneratingContactSheet,
    String? contactSheetPath,
    bool clearContactSheet = false,
    GifSettings? gifSettings,
    bool? isCreatingGif,
    double? gifProgress,
    String? gifOutputPath,
    bool clearGifOutput = false,
    CompressionSettings? compressionSettings,
    CompressionProgress? compressionProgress,
    bool? isCompressing,
    String? compressedOutputPath,
    bool clearCompressedOutput = false,
    Map<String, FrameAnalysis>? frameAnalyses,
    bool? isAnalyzingFrames,
    double? analysisProgress,
  }) {
    return AppState(
      metadata: clearMetadata ? null : metadata ?? this.metadata,
      settings: settings ?? this.settings,
      progress: progress ?? this.progress,
      frames: frames ?? this.frames,
      queue: queue ?? this.queue,
      history: history ?? this.history,
      userSettings: userSettings ?? this.userSettings,
      isLoadingMetadata: isLoadingMetadata ?? this.isLoadingMetadata,
      isExtracting: isExtracting ?? this.isExtracting,
      isPaused: isPaused ?? this.isPaused,
      isExportingZip: isExportingZip ?? this.isExportingZip,
      zipProgress: zipProgress ?? this.zipProgress,
      selectedTab: selectedTab ?? this.selectedTab,
      errorMessage: clearMessages ? null : errorMessage,
      infoMessage: clearMessages ? null : infoMessage,
      // Phase 4
      sceneSettings: sceneSettings ?? this.sceneSettings,
      detectedScenes: detectedScenes ?? this.detectedScenes,
      isDetectingScenes: isDetectingScenes ?? this.isDetectingScenes,
      sceneDetectionProgress:
          sceneDetectionProgress ?? this.sceneDetectionProgress,
      contactSheetSettings:
          contactSheetSettings ?? this.contactSheetSettings,
      isGeneratingContactSheet:
          isGeneratingContactSheet ?? this.isGeneratingContactSheet,
      contactSheetPath: clearContactSheet
          ? null
          : contactSheetPath ?? this.contactSheetPath,
      gifSettings: gifSettings ?? this.gifSettings,
      isCreatingGif: isCreatingGif ?? this.isCreatingGif,
      gifProgress: gifProgress ?? this.gifProgress,
      gifOutputPath:
          clearGifOutput ? null : gifOutputPath ?? this.gifOutputPath,
      compressionSettings:
          compressionSettings ?? this.compressionSettings,
      compressionProgress:
          compressionProgress ?? this.compressionProgress,
      isCompressing: isCompressing ?? this.isCompressing,
      compressedOutputPath: clearCompressedOutput
          ? null
          : compressedOutputPath ?? this.compressedOutputPath,
      frameAnalyses: frameAnalyses ?? this.frameAnalyses,
      isAnalyzingFrames: isAnalyzingFrames ?? this.isAnalyzingFrames,
      analysisProgress: analysisProgress ?? this.analysisProgress,
    );
  }
}
