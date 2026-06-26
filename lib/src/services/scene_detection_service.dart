import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';

class SceneDetectionService {
  Process? _process;

  /// Detects scene changes in a video using FFmpeg's scene detection filter.
  /// Returns a list of [SceneInfo] with timestamps and confidence scores.
  Future<List<SceneInfo>> detectScenes({
    required String videoPath,
    required String ffmpegPath,
    required double threshold,
    required double minSceneDuration,
    required Duration videoDuration,
    void Function(double progress)? onProgress,
  }) async {
    final scenes = <SceneInfo>[];

    // Use FFmpeg's select filter with scene change detection
    // and output timestamps via showinfo filter to stderr
    _process = await Process.start(ffmpegPath, [
      '-hide_banner',
      '-i', videoPath,
      '-vf', "select='gt(scene,$threshold)',showinfo",
      '-vsync', '0',
      '-f', 'null',
      '-',
    ]);

    final completer = Completer<void>();
    final buffer = StringBuffer();

    _process!.stderr.transform(utf8.decoder).listen((chunk) {
      buffer.write(chunk);
      final lines = buffer.toString().split('\n');
      // Keep the last incomplete line in the buffer
      buffer.clear();
      if (lines.last.isNotEmpty) {
        buffer.write(lines.last);
      }

      for (final line in lines) {
        // Parse showinfo output for timestamps
        final ptsTimeMatch = RegExp(r'pts_time:\s*([\d.]+)').firstMatch(line);
        if (ptsTimeMatch != null) {
          final timestamp = double.tryParse(ptsTimeMatch.group(1)!) ?? 0;
          // Check minimum scene duration
          if (scenes.isEmpty ||
              (timestamp - scenes.last.timestamp.inMilliseconds / 1000) >=
                  minSceneDuration) {
            scenes.add(SceneInfo(
              timestamp: Duration(
                milliseconds: (timestamp * 1000).round(),
              ),
              score: threshold,
              index: scenes.length,
            ));
          }
        }

        // Parse progress from time= output
        final timeMatch = RegExp(r'time=\s*(\d+):(\d+):(\d+)\.(\d+)')
            .firstMatch(line);
        if (timeMatch != null && videoDuration.inMilliseconds > 0) {
          final hours = int.tryParse(timeMatch.group(1)!) ?? 0;
          final minutes = int.tryParse(timeMatch.group(2)!) ?? 0;
          final seconds = int.tryParse(timeMatch.group(3)!) ?? 0;
          final currentMs =
              (hours * 3600 + minutes * 60 + seconds) * 1000;
          onProgress?.call(
            (currentMs / videoDuration.inMilliseconds).clamp(0.0, 1.0),
          );
        }
      }
    }, onDone: completer.complete);

    await _process!.exitCode;
    await completer.future;
    _process = null;

    onProgress?.call(1.0);
    return scenes;
  }

  /// Extracts key frames at the given scene timestamps.
  Future<List<String>> extractSceneFrames({
    required String videoPath,
    required String ffmpegPath,
    required List<SceneInfo> scenes,
    required String outputDirectory,
    required OutputFormat format,
    void Function(double progress)? onProgress,
  }) async {
    final outputDir = Directory(outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final paths = <String>[];

    for (var i = 0; i < scenes.length; i++) {
      final scene = scenes[i];
      final timeStr = _formatTime(scene.timestamp);
      final outputPath =
          '${outputDir.path}${Platform.pathSeparator}scene_${(i + 1).toString().padLeft(4, '0')}.${format.extension}';

      final result = await Process.run(ffmpegPath, [
        '-hide_banner',
        '-y',
        '-ss', timeStr,
        '-i', videoPath,
        '-frames:v', '1',
        if (format == OutputFormat.jpg) ...['-pix_fmt', 'yuvj444p', '-q:v', '1'],
        if (format == OutputFormat.png) ...['-pix_fmt', 'rgb24', '-compression_level', '3'],
        if (format == OutputFormat.webp) ...['-lossless', '1'],
        outputPath,
      ]);

      if (result.exitCode == 0 && await File(outputPath).exists()) {
        paths.add(outputPath);
      }

      onProgress?.call((i + 1) / scenes.length);
    }

    return paths;
  }

  void cancel() {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = duration.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }
}
