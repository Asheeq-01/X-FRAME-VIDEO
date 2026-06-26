import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/formatters.dart';
import '../models/app_models.dart';
import '../services/archive_service.dart';
import '../services/compression_service.dart';
import '../services/contact_sheet_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/frame_analysis_service.dart';
import '../services/gif_service.dart';
import '../services/scene_detection_service.dart';
import '../services/storage_service.dart';

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  final _storage = StorageService();
  final _ffmpeg = FfmpegService();
  final _archive = ArchiveService();
  final _sceneDetection = SceneDetectionService();
  final _contactSheet = ContactSheetService();
  final _gifService = GifService();
  final _compression = CompressionService();
  final _frameAnalysis = FrameAnalysisService();
  var _initialized = false;
  static const _maxVideoBytes = 5 * 1024 * 1024 * 1024;
  static const _extensions = {'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'};

  @override
  AppState build() {
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_loadStoredState);
    }
    return const AppState();
  }

  int expectedFrames([AppState? source]) {
    final current = source ?? state;
    final metadata = current.metadata;
    if (metadata == null) return 0;
    final duration = _selectedDuration(current.settings, metadata.duration);
    return (duration.inMilliseconds / 1000 * current.settings.fps).ceil();
  }

  int estimatedDiskBytes([AppState? source]) {
    final current = source ?? state;
    final metadata = current.metadata;
    if (metadata == null) return 0;
    final pixels = metadata.width * metadata.height;
    final perFrame = switch (current.settings.format) {
      OutputFormat.png => pixels * 0.45,
      OutputFormat.jpg => pixels * 0.16,
      OutputFormat.webp => pixels * 0.10,
    };
    return (perFrame * expectedFrames(current)).round();
  }

  Future<void> pickVideos() async {
    const typeGroup = XTypeGroup(
      label: 'Video Files',
      extensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'],
    );
    final files = await openFiles(
      acceptedTypeGroups: const [typeGroup],
    );
    if (files.isEmpty) return;
    final paths = files.map((file) => file.path).toList();
    await addVideoPaths(paths);
  }

  Future<void> addVideoPaths(List<String> paths) async {
    try {
      final valid = <String>[];
      for (final path in paths) {
        final error = await _validateVideo(path);
        if (error != null) {
          state = state.copyWith(errorMessage: error);
        } else {
          valid.add(path);
        }
      }
      if (valid.isEmpty) return;

      final queue = [
        ...state.queue,
        ...valid.map(
          (path) => BatchJob(
            id: '${DateTime.now().microsecondsSinceEpoch}${path.hashCode}',
            path: path,
            name: pathName(path),
          ),
        ),
      ];
      state = state.copyWith(queue: queue, clearMessages: true);
      await loadVideo(valid.first);
    } catch (e, stack) {
      debugPrint('Error adding video paths: $e');
      debugPrintStack(stackTrace: stack);
      state = state.copyWith(
        errorMessage: 'Failed to add videos: ${e.toString()}',
      );
    }
  }

  Future<void> loadVideo(String path) async {
    state = state.copyWith(
      isLoadingMetadata: true,
      clearMetadata: true,
      frames: [],
      progress: const ExtractionProgress(message: 'Reading metadata'),
      clearMessages: true,
    );
    try {
      final metadata = await _ffmpeg.readMetadata(path);
      state = state.copyWith(
        metadata: metadata,
        isLoadingMetadata: false,
        progress: const ExtractionProgress(message: 'Ready'),
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMetadata: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<void> chooseOutputFolder() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    final updatedSettings = state.settings.copyWith(outputDirectory: path);
    final updatedUserSettings = state.userSettings.copyWith(
      defaultOutputFolder: path,
    );
    state = state.copyWith(
      settings: updatedSettings,
      userSettings: updatedUserSettings,
    );
    await _storage.saveSettings(updatedUserSettings);
  }

  void setFps(double fps) {
    if (fps <= 0) return;
    state = state.copyWith(settings: state.settings.copyWith(fps: fps));
  }

  void setFormat(OutputFormat format) {
    state = state.copyWith(settings: state.settings.copyWith(format: format));
  }

  void setStartTime(Duration? value) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        startTime: value,
        clearStart: value == null,
      ),
    );
  }

  void setEndTime(Duration? value) {
    state = state.copyWith(
      settings: state.settings.copyWith(
        endTime: value,
        clearEnd: value == null,
      ),
    );
  }

  Future<void> extractSelected() async {
    final metadata = state.metadata;
    final outputDirectory = state.settings.outputDirectory;
    if (metadata == null) {
      state = state.copyWith(
        errorMessage: 'Choose a video before extracting frames.',
      );
      return;
    }
    if (outputDirectory == null || outputDirectory.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Choose an output folder before extracting frames.',
      );
      return;
    }
    final validationError = _validateRange(state.settings, metadata.duration);
    if (validationError != null) {
      state = state.copyWith(errorMessage: validationError);
      return;
    }
    await _extract(metadata, outputDirectory);
  }

  Future<void> processQueue() async {
    final outputDirectory = state.settings.outputDirectory;
    if (outputDirectory == null || outputDirectory.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Choose an output folder before processing the queue.',
      );
      return;
    }

    for (final job
        in state.queue
            .where((job) => job.status == JobStatus.pending)
            .toList()) {
      _updateJob(job.id, JobStatus.processing);
      try {
        await loadVideo(job.path);
        final metadata = state.metadata;
        if (metadata == null) {
          throw const FormatException('Metadata could not be loaded.');
        }
        final success = await _extract(metadata, outputDirectory);
        if (success) {
          _updateJob(job.id, JobStatus.completed);
        } else {
          if (state.progress.message == 'Canceled') {
            _updateJob(job.id, JobStatus.canceled);
            break;
          } else {
            _updateJob(job.id, JobStatus.failed, state.errorMessage);
          }
        }
      } catch (error) {
        _updateJob(job.id, JobStatus.failed, _friendlyError(error));
      }
    }
  }

  void pauseExtraction() {
    if (!_ffmpeg.pause()) {
      state = state.copyWith(
        infoMessage: Platform.isWindows
            ? 'Pause and resume are not supported on Windows.'
            : 'No active extraction process is available to pause.',
      );
      return;
    }
    state = state.copyWith(
      isPaused: true,
      progress: state.progress.copyWith(message: 'Paused'),
    );
  }

  void resumeExtraction() {
    if (!_ffmpeg.resume()) {
      state = state.copyWith(
        infoMessage: Platform.isWindows
            ? 'Pause and resume are not supported on Windows.'
            : 'No paused extraction process is available to resume.',
      );
      return;
    }
    state = state.copyWith(
      isPaused: false,
      progress: state.progress.copyWith(message: 'Extracting frames'),
    );
  }

  void cancelExtraction() {
    _ffmpeg.cancel();
    state = state.copyWith(
      isExtracting: false,
      isPaused: false,
      progress: state.progress.copyWith(message: 'Canceled'),
    );
  }

  Future<void> exportZip() async {
    if (state.frames.isEmpty) {
      state = state.copyWith(
        errorMessage: 'No frames are available to export.',
      );
      return;
    }
    final location = await getSaveLocation(
      suggestedName:
          '${sanitizeFileName(state.metadata?.name ?? 'frames')}.zip',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ZIP archive', extensions: ['zip']),
      ],
    );
    if (location == null) return;

    state = state.copyWith(
      isExportingZip: true,
      zipProgress: 0,
      clearMessages: true,
    );
    try {
      await _archive.createZip(
        frames: state.frames,
        destinationPath: location.path,
        onProgress: (progress) => state = state.copyWith(zipProgress: progress),
      );
      state = state.copyWith(
        isExportingZip: false,
        zipProgress: 1,
        infoMessage: 'ZIP saved to ${location.path}',
      );
    } catch (error) {
      state = state.copyWith(
        isExportingZip: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<void> saveFrame(FrameFile frame) async {
    final location = await getSaveLocation(
      suggestedName: frame.name,
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Image',
          extensions: [p.extension(frame.name).replaceFirst('.', '')],
        ),
      ],
    );
    if (location == null) return;
    await File(frame.path).copy(location.path);
    state = state.copyWith(infoMessage: 'Frame saved to ${location.path}');
  }

  Future<void> deleteFrame(FrameFile frame) async {
    try {
      final file = File(frame.path);
      if (await file.exists()) await file.delete();
      state = state.copyWith(
        frames: state.frames.where((item) => item.path != frame.path).toList(),
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _friendlyError(error));
    }
  }

  Future<void> openFolder(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (error) {
      state = state.copyWith(errorMessage: _friendlyError(error));
    }
  }

  void setSelectedTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  Future<void> updateUserSettings(UserSettings settings) async {
    state = state.copyWith(
      userSettings: settings,
      settings: state.settings.copyWith(
        fps: settings.defaultFps,
        format: settings.defaultFormat,
        outputDirectory: settings.defaultOutputFolder,
      ),
    );
    await _storage.saveSettings(settings);
  }

  Future<void> deleteHistory(String id) async {
    final updated = state.history.where((entry) => entry.id != id).toList();
    state = state.copyWith(history: updated);
    await _storage.saveHistory(updated);
  }

  Future<void> clearHistory() async {
    state = state.copyWith(history: []);
    await _storage.saveHistory([]);
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  // ── Phase 3: Batch Queue Enhancements ──────────────────────────────────

  void removeFromQueue(String id) {
    state = state.copyWith(
      queue: state.queue.where((job) => job.id != id).toList(),
    );
  }

  void clearCompletedJobs() {
    state = state.copyWith(
      queue: state.queue
          .where(
            (job) =>
                job.status != JobStatus.completed &&
                job.status != JobStatus.failed &&
                job.status != JobStatus.canceled,
          )
          .toList(),
    );
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final queue = [...state.queue];
    if (newIndex > oldIndex) newIndex--;
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);
    state = state.copyWith(queue: queue);
  }

  // ── Phase 4A: Scene Detection ──────────────────────────────────────────

  void updateSceneSettings(SceneDetectionSettings settings) {
    state = state.copyWith(sceneSettings: settings);
  }

  Future<void> detectScenes() async {
    final metadata = state.metadata;
    if (metadata == null) {
      state = state.copyWith(
        errorMessage: 'Load a video before detecting scenes.',
      );
      return;
    }

    await _ffmpeg.ensureAvailable();
    final ffmpegPath = _ffmpeg.ffmpegPath;
    if (ffmpegPath == null) {
      state = state.copyWith(
        errorMessage: 'FFmpeg is not available.',
      );
      return;
    }

    state = state.copyWith(
      isDetectingScenes: true,
      sceneDetectionProgress: 0,
      detectedScenes: [],
      clearMessages: true,
    );

    try {
      final scenes = await _sceneDetection.detectScenes(
        videoPath: metadata.path,
        ffmpegPath: ffmpegPath,
        threshold: state.sceneSettings.threshold,
        minSceneDuration: state.sceneSettings.minSceneDurationSeconds,
        videoDuration: metadata.duration,
        onProgress: (p) =>
            state = state.copyWith(sceneDetectionProgress: p),
      );

      state = state.copyWith(
        isDetectingScenes: false,
        sceneDetectionProgress: 1,
        detectedScenes: scenes,
        infoMessage: 'Detected ${scenes.length} scene changes.',
      );
    } catch (error) {
      state = state.copyWith(
        isDetectingScenes: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<void> extractSceneFrames() async {
    final metadata = state.metadata;
    final outputDirectory = state.settings.outputDirectory;
    if (metadata == null || state.detectedScenes.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Detect scenes first before extracting scene frames.',
      );
      return;
    }
    if (outputDirectory == null || outputDirectory.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Choose an output folder first.',
      );
      return;
    }

    await _ffmpeg.ensureAvailable();
    final ffmpegPath = _ffmpeg.ffmpegPath!;

    final videoBase = sanitizeFileName(
      metadata.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final targetDir =
        '$outputDirectory${Platform.pathSeparator}${videoBase}_scenes_$timestamp';

    state = state.copyWith(
      isExtracting: true,
      frames: [],
      progress: const ExtractionProgress(message: 'Extracting scene frames'),
      clearMessages: true,
    );

    try {
      final paths = await _sceneDetection.extractSceneFrames(
        videoPath: metadata.path,
        ffmpegPath: ffmpegPath,
        scenes: state.detectedScenes,
        outputDirectory: targetDir,
        format: state.settings.format,
        onProgress: (p) => state = state.copyWith(
          progress: state.progress.copyWith(
            percent: p,
            framesExtracted: (p * state.detectedScenes.length).round(),
            message: 'Extracting scene frames',
          ),
        ),
      );

      final frames = <FrameFile>[];
      for (final path in paths) {
        frames.add(await FrameFile.fromFile(
          File(path),
          width: metadata.width,
          height: metadata.height,
        ));
      }

      state = state.copyWith(
        isExtracting: false,
        frames: frames,
        progress: ExtractionProgress(
          percent: 1,
          framesExtracted: frames.length,
          message: 'Completed',
        ),
        infoMessage: 'Extracted ${frames.length} scene frames to $targetDir',
      );
    } catch (error) {
      state = state.copyWith(
        isExtracting: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  // ── Phase 4B: Contact Sheet ────────────────────────────────────────────

  void updateContactSheetSettings(ContactSheetSettings settings) {
    state = state.copyWith(contactSheetSettings: settings);
  }

  Future<void> generateContactSheet() async {
    final metadata = state.metadata;
    final outputDirectory = state.settings.outputDirectory;
    if (metadata == null) {
      state = state.copyWith(
        errorMessage: 'Load a video before generating a contact sheet.',
      );
      return;
    }
    if (outputDirectory == null || outputDirectory.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Choose an output folder first.',
      );
      return;
    }

    await _ffmpeg.ensureAvailable();
    final ffmpegPath = _ffmpeg.ffmpegPath!;

    final videoBase = sanitizeFileName(
      metadata.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final csSettings = state.contactSheetSettings;
    final outputPath =
        '$outputDirectory${Platform.pathSeparator}${videoBase}_contact_sheet.${csSettings.format.extension}';

    state = state.copyWith(
      isGeneratingContactSheet: true,
      clearContactSheet: true,
      clearMessages: true,
    );

    try {
      final path = await _contactSheet.generate(
        videoPath: metadata.path,
        ffmpegPath: ffmpegPath,
        outputPath: outputPath,
        videoDuration: metadata.duration,
        settings: csSettings,
      );

      state = state.copyWith(
        isGeneratingContactSheet: false,
        contactSheetPath: path,
        infoMessage: 'Contact sheet saved to $path',
      );
    } catch (error) {
      state = state.copyWith(
        isGeneratingContactSheet: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  // ── Phase 4C: GIF Creator ──────────────────────────────────────────────

  void updateGifSettings(GifSettings settings) {
    state = state.copyWith(gifSettings: settings);
  }

  Future<void> createGif() async {
    final metadata = state.metadata;
    final outputDirectory = state.settings.outputDirectory;
    if (metadata == null) {
      state = state.copyWith(
        errorMessage: 'Load a video before creating a GIF.',
      );
      return;
    }
    if (outputDirectory == null || outputDirectory.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Choose an output folder first.',
      );
      return;
    }

    await _ffmpeg.ensureAvailable();
    final ffmpegPath = _ffmpeg.ffmpegPath!;

    final videoBase = sanitizeFileName(
      metadata.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final outputPath =
        '$outputDirectory${Platform.pathSeparator}${videoBase}_$timestamp.gif';

    state = state.copyWith(
      isCreatingGif: true,
      gifProgress: 0,
      clearGifOutput: true,
      clearMessages: true,
    );

    try {
      final path = await _gifService.createGif(
        videoPath: metadata.path,
        ffmpegPath: ffmpegPath,
        outputPath: outputPath,
        settings: state.gifSettings,
        videoDuration: metadata.duration,
        onProgress: (p) => state = state.copyWith(gifProgress: p),
      );

      state = state.copyWith(
        isCreatingGif: false,
        gifProgress: 1,
        gifOutputPath: path,
        infoMessage: 'GIF saved to $path',
      );
    } catch (error) {
      state = state.copyWith(
        isCreatingGif: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  void cancelGif() {
    _gifService.cancel();
    state = state.copyWith(
      isCreatingGif: false,
      infoMessage: 'GIF creation canceled.',
    );
  }

  // ── Phase 4D: Video Compression ────────────────────────────────────────

  void updateCompressionSettings(CompressionSettings settings) {
    state = state.copyWith(compressionSettings: settings);
  }

  Future<void> compressVideo() async {
    final metadata = state.metadata;
    final outputDirectory = state.settings.outputDirectory;
    if (metadata == null) {
      state = state.copyWith(
        errorMessage: 'Load a video before compressing.',
      );
      return;
    }
    if (outputDirectory == null || outputDirectory.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Choose an output folder first.',
      );
      return;
    }

    await _ffmpeg.ensureAvailable();
    final ffmpegPath = _ffmpeg.ffmpegPath!;

    final videoBase = sanitizeFileName(
      metadata.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final ext = state.compressionSettings.codec == CompressionCodec.vp9
        ? 'webm'
        : 'mp4';
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final outputPath =
        '$outputDirectory${Platform.pathSeparator}${videoBase}_compressed_$timestamp.$ext';

    state = state.copyWith(
      isCompressing: true,
      compressionProgress: const CompressionProgress(message: 'Starting'),
      clearCompressedOutput: true,
      clearMessages: true,
    );

    try {
      final path = await _compression.compress(
        videoPath: metadata.path,
        ffmpegPath: ffmpegPath,
        outputPath: outputPath,
        settings: state.compressionSettings,
        videoDuration: metadata.duration,
        onProgress: (p) => state = state.copyWith(compressionProgress: p),
      );

      state = state.copyWith(
        isCompressing: false,
        compressedOutputPath: path,
        compressionProgress: CompressionProgress(
          percent: 1,
          currentTime: metadata.duration,
          message: 'Completed',
          outputSizeBytes: state.compressionProgress.outputSizeBytes,
        ),
        infoMessage: 'Compressed video saved to $path',
      );
    } catch (error) {
      state = state.copyWith(
        isCompressing: false,
        compressionProgress: const CompressionProgress(message: 'Failed'),
        errorMessage: _friendlyError(error),
      );
    }
  }

  void cancelCompression() {
    _compression.cancel();
    state = state.copyWith(
      isCompressing: false,
      compressionProgress: const CompressionProgress(message: 'Canceled'),
      infoMessage: 'Compression canceled.',
    );
  }

  // ── Phase 4E: AI Frame Analysis ────────────────────────────────────────

  Future<void> analyzeFrames() async {
    if (state.frames.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Extract frames first before analyzing.',
      );
      return;
    }

    state = state.copyWith(
      isAnalyzingFrames: true,
      analysisProgress: 0,
      frameAnalyses: {},
      clearMessages: true,
    );

    try {
      final results = await _frameAnalysis.analyzeFrames(
        frames: state.frames,
        onProgress: (p) => state = state.copyWith(analysisProgress: p),
      );

      state = state.copyWith(
        isAnalyzingFrames: false,
        analysisProgress: 1,
        frameAnalyses: results,
        infoMessage:
            'Analysis complete. '
            '${results.values.where((a) => a.isDuplicate).length} duplicates, '
            '${results.values.where((a) => a.blurScore < 500).length} potentially blurry.',
      );
    } catch (error) {
      state = state.copyWith(
        isAnalyzingFrames: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<void> removeBlurryFrames(double threshold) async {
    if (state.frameAnalyses.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Run frame analysis first.',
      );
      return;
    }

    final toRemove = <String>{};
    for (final entry in state.frameAnalyses.entries) {
      if (entry.value.blurScore < threshold) {
        toRemove.add(entry.key);
      }
    }

    if (toRemove.isEmpty) {
      state = state.copyWith(
        infoMessage: 'No frames below the blur threshold.',
      );
      return;
    }

    final remaining =
        state.frames.where((f) => !toRemove.contains(f.path)).toList();
    state = state.copyWith(
      frames: remaining,
      infoMessage: 'Removed ${toRemove.length} blurry frames.',
    );
  }

  Future<void> removeDuplicateFrames() async {
    if (state.frameAnalyses.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Run frame analysis first.',
      );
      return;
    }

    final toRemove = <String>{};
    for (final entry in state.frameAnalyses.entries) {
      if (entry.value.isDuplicate) {
        toRemove.add(entry.key);
      }
    }

    if (toRemove.isEmpty) {
      state = state.copyWith(
        infoMessage: 'No duplicate frames detected.',
      );
      return;
    }

    final remaining =
        state.frames.where((f) => !toRemove.contains(f.path)).toList();
    state = state.copyWith(
      frames: remaining,
      infoMessage: 'Removed ${toRemove.length} duplicate frames.',
    );
  }

  // ── Private Methods ────────────────────────────────────────────────────

  Future<void> _loadStoredState() async {
    final settings = await _storage.loadSettings();
    final history = await _storage.loadHistory();
    state = state.copyWith(
      userSettings: settings,
      history: history,
      settings: ExtractionSettings(
        fps: settings.defaultFps,
        format: settings.defaultFormat,
        outputDirectory: settings.defaultOutputFolder,
      ),
    );
  }

  Future<bool> _extract(VideoMetadata metadata, String outputDirectory) async {
    state = state.copyWith(
      isExtracting: true,
      isPaused: false,
      frames: [],
      progress: const ExtractionProgress(message: 'Starting FFmpeg'),
      clearMessages: true,
    );
    try {
      final result = await _ffmpeg.extractFrames(
        metadata: metadata,
        settings: state.settings,
        outputDirectory: outputDirectory,
        expectedFrames: expectedFrames(),
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      final entry = HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        videoName: metadata.name,
        date: DateTime.now(),
        fps: state.settings.fps,
        format: state.settings.format,
        framesGenerated: result.frames.length,
        outputLocation: result.outputDirectory,
        status: JobStatus.completed,
      );
      final history = [entry, ...state.history].take(100).toList();
      state = state.copyWith(
        isExtracting: false,
        isPaused: false,
        frames: result.frames,
        history: history,
        infoMessage:
            'Generated ${result.frames.length} frames in ${result.outputDirectory}',
      );
      await _storage.saveHistory(history);
      return true;
    } catch (error) {
      final entry = HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        videoName: metadata.name,
        date: DateTime.now(),
        fps: state.settings.fps,
        format: state.settings.format,
        framesGenerated: state.progress.framesExtracted,
        outputLocation: outputDirectory,
        status: state.progress.message == 'Canceled'
            ? JobStatus.canceled
            : JobStatus.failed,
      );
      final history = [entry, ...state.history].take(100).toList();
      state = state.copyWith(
        isExtracting: false,
        isPaused: false,
        history: history,
        errorMessage: _friendlyError(error),
      );
      await _storage.saveHistory(history);
      return false;
    }
  }

  void _updateJob(String id, JobStatus status, [String? error]) {
    state = state.copyWith(
      queue: [
        for (final job in state.queue)
          if (job.id == id) job.copyWith(status: status, error: error) else job,
      ],
    );
  }

  Future<String?> _validateVideo(String path) async {
    try {
      final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
      if (!_extensions.contains(extension)) {
        return 'Unsupported format: .$extension. Supported formats are MP4, MOV, AVI, MKV, WEBM, and M4V.';
      }
      final file = File(path);
      if (!await file.exists()) {
        return 'The selected file does not exist.';
      }
      final size = await file.length();
      if (size > _maxVideoBytes) {
        return 'File is larger than the 5 GB limit.';
      }
      return null;
    } catch (e, stack) {
      debugPrint('Error validating video path $path: $e');
      debugPrintStack(stackTrace: stack);
      return 'Error accessing file: ${e.toString()}';
    }
  }

  String? _validateRange(ExtractionSettings settings, Duration duration) {
    final start = settings.startTime;
    final end = settings.endTime;
    if (start != null && start > duration) {
      return 'Start time is beyond the video duration.';
    }
    if (end != null && end > duration) {
      return 'End time is beyond the video duration.';
    }
    if (start != null && end != null && end <= start) {
      return 'End time must be greater than start time.';
    }
    return null;
  }

  Duration _selectedDuration(
    ExtractionSettings settings,
    Duration fullDuration,
  ) {
    final start = settings.startTime ?? Duration.zero;
    final end = settings.endTime ?? fullDuration;
    if (end <= start) {
      return Duration.zero;
    }
    return end - start;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (error is ProcessException) {
      if (error.message.contains('exit code')) {
        return 'FFmpeg failed to process this video (Exit code: ${error.errorCode}).';
      }
      return 'FFmpeg could not be found or executed: ${error.message}. Confirm FFmpeg and ffprobe are installed and available in PATH.';
    }
    if (text.contains('ffmpeg') || text.contains('ffprobe')) {
      return 'FFmpeg could not process this video. Confirm FFmpeg and ffprobe are installed and available in PATH.';
    }
    if (text.contains('Permission')) {
      return 'Permission denied. Choose another output folder.';
    }
    if (text.contains('No space')) {
      return 'Insufficient disk space for frame extraction.';
    }
    if (text.contains('video stream')) {
      return 'This file does not contain a readable video stream.';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
