import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';

class CompressionService {
  Process? _process;

  /// Compresses/transcodes a video using FFmpeg with configurable settings.
  Future<String> compress({
    required String videoPath,
    required String ffmpegPath,
    required String outputPath,
    required CompressionSettings settings,
    required Duration videoDuration,
    void Function(CompressionProgress progress)? onProgress,
  }) async {
    final args = <String>['-hide_banner', '-y', '-i', videoPath];

    // Video codec and quality
    args.addAll(['-c:v', settings.codec.ffmpegName]);

    // CRF for quality control (not applicable for all codecs in same way)
    if (settings.codec == CompressionCodec.vp9) {
      args.addAll(['-crf', '${settings.crf}', '-b:v', '0']);
    } else {
      args.addAll(['-crf', '${settings.crf}']);
    }

    // Encoding preset (not applicable for VP9)
    if (settings.codec != CompressionCodec.vp9) {
      args.addAll(['-preset', settings.preset.ffmpegName]);
    }

    // Scale if not 100%
    if (settings.scalePercent < 100) {
      final scale = settings.scalePercent / 100;
      args.addAll([
        '-vf',
        'scale=trunc(iw*$scale/2)*2:trunc(ih*$scale/2)*2',
      ]);
    }

    // Audio
    args.addAll(['-c:a', 'aac', '-b:a', '${settings.audioBitrate}k']);

    args.add(outputPath);

    _process = await Process.start(ffmpegPath, args);

    final completer = Completer<void>();
    _process!.stderr.transform(utf8.decoder).listen((chunk) {
      final timeMatch =
          RegExp(r'time=\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(chunk);
      final sizeMatch =
          RegExp(r'size=\s*(\d+)kB').firstMatch(chunk);
      final speedMatch =
          RegExp(r'speed=\s*([\d.]+)x').firstMatch(chunk);

      if (timeMatch != null && videoDuration.inMilliseconds > 0) {
        final hours = int.tryParse(timeMatch.group(1)!) ?? 0;
        final minutes = int.tryParse(timeMatch.group(2)!) ?? 0;
        final seconds = int.tryParse(timeMatch.group(3)!) ?? 0;
        final hundredths = int.tryParse(timeMatch.group(4)!) ?? 0;
        final currentMs =
            (hours * 3600 + minutes * 60 + seconds) * 1000 +
            hundredths * 10;
        final currentDuration = Duration(milliseconds: currentMs);

        final sizeKb = int.tryParse(sizeMatch?.group(1) ?? '0') ?? 0;
        final speed = speedMatch?.group(1) ?? '';

        onProgress?.call(CompressionProgress(
          percent: (currentMs / videoDuration.inMilliseconds).clamp(0.0, 1.0),
          currentTime: currentDuration,
          speed: speed.isEmpty ? '' : '${speed}x',
          outputSizeBytes: sizeKb * 1024,
          message: 'Compressing',
        ));
      }
    }, onDone: completer.complete);

    final exitCode = await _process!.exitCode;
    await completer.future;
    _process = null;

    if (exitCode != 0) {
      throw ProcessException(
        'ffmpeg',
        args,
        'Video compression failed with exit code $exitCode.',
        exitCode,
      );
    }

    if (!await File(outputPath).exists()) {
      throw const FileSystemException('Compressed file was not created.');
    }

    final stat = await File(outputPath).stat();
    onProgress?.call(CompressionProgress(
      percent: 1.0,
      currentTime: videoDuration,
      speed: '',
      outputSizeBytes: stat.size,
      message: 'Completed',
    ));

    return outputPath;
  }

  void cancel() {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }
}
