import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';

class GifService {
  Process? _process;

  /// Creates a high-quality animated GIF from a video using FFmpeg's
  /// two-pass palettegen+paletteuse approach.
  Future<String> createGif({
    required String videoPath,
    required String ffmpegPath,
    required String outputPath,
    required GifSettings settings,
    required Duration videoDuration,
    void Function(double progress)? onProgress,
  }) async {
    // Create a temporary palette file for high-quality GIF output
    final paletteDir = Directory.systemTemp.createTempSync('vfx_gif_');
    final palettePath = '${paletteDir.path}${Platform.pathSeparator}palette.png';

    try {
      onProgress?.call(0.05);

      // Build time range arguments
      final timeArgs = <String>[];
      if (settings.startTime != null) {
        timeArgs.addAll(['-ss', _formatTime(settings.startTime!)]);
      }
      if (settings.startTime != null && settings.endTime != null) {
        timeArgs.addAll([
          '-t',
          _formatTime(settings.endTime! - settings.startTime!),
        ]);
      } else if (settings.endTime != null) {
        timeArgs.addAll(['-to', _formatTime(settings.endTime!)]);
      }

      final filterBase =
          'fps=${settings.fps},scale=${settings.width}:-1:flags=lanczos';

      // Pass 1: Generate optimal palette
      final pass1 = await Process.run(ffmpegPath, [
        '-hide_banner', '-y',
        ...timeArgs,
        '-i', videoPath,
        '-vf', '$filterBase,palettegen=stats_mode=diff',
        palettePath,
      ]);

      if (pass1.exitCode != 0) {
        throw ProcessException(
          'ffmpeg',
          [],
          'GIF palette generation failed: ${pass1.stderr}',
          pass1.exitCode,
        );
      }

      onProgress?.call(0.35);

      // Pass 2: Create GIF using the generated palette
      _process = await Process.start(ffmpegPath, [
        '-hide_banner', '-y',
        ...timeArgs,
        '-i', videoPath,
        '-i', palettePath,
        '-lavfi',
        '$filterBase [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5',
        outputPath,
      ]);

      final completer = Completer<void>();
      _process!.stderr.transform(utf8.decoder).listen((chunk) {
        // Parse progress from time= output
        final timeMatch = RegExp(r'time=\s*(\d+):(\d+):(\d+)\.(\d+)')
            .firstMatch(chunk);
        if (timeMatch != null) {
          final hours = int.tryParse(timeMatch.group(1)!) ?? 0;
          final minutes = int.tryParse(timeMatch.group(2)!) ?? 0;
          final seconds = int.tryParse(timeMatch.group(3)!) ?? 0;
          final currentMs =
              (hours * 3600 + minutes * 60 + seconds) * 1000;

          final effectiveDuration = settings.endTime != null &&
                  settings.startTime != null
              ? (settings.endTime! - settings.startTime!).inMilliseconds
              : settings.endTime != null
                  ? settings.endTime!.inMilliseconds
                  : videoDuration.inMilliseconds;

          if (effectiveDuration > 0) {
            final p = (currentMs / effectiveDuration).clamp(0.0, 1.0);
            onProgress?.call(0.35 + p * 0.6);
          }
        }
      }, onDone: completer.complete);

      final exitCode = await _process!.exitCode;
      await completer.future;
      _process = null;

      if (exitCode != 0) {
        throw ProcessException(
          'ffmpeg', [], 'GIF creation failed.', exitCode,
        );
      }

      if (!await File(outputPath).exists()) {
        throw const FileSystemException('GIF file was not created.');
      }

      onProgress?.call(1.0);
      return outputPath;
    } finally {
      // Clean up palette temp dir
      try {
        if (await paletteDir.exists()) {
          await paletteDir.delete(recursive: true);
        }
      } catch (_) {}
    }
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
