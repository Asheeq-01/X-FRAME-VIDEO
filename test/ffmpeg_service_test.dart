import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoframex_desktop/src/models/app_models.dart';
import 'package:videoframex_desktop/src/services/ffmpeg_service.dart';

void main() {
  test('reads metadata and extracts full-resolution PNG frames', () async {
    if (!await _hasFfmpeg()) {
      return;
    }

    final temp = await Directory.systemTemp.createTemp('videoframex_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final video = File('${temp.path}${Platform.pathSeparator}sample.mp4');
    final generated = await Process.run('ffmpeg', [
      '-hide_banner',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=320x180:rate=4:duration=2',
      '-pix_fmt',
      'yuv420p',
      video.path,
    ]);
    expect(generated.exitCode, 0, reason: generated.stderr.toString());

    final service = FfmpegService();
    final metadata = await service.readMetadata(video.path);
    expect(metadata.width, 320);
    expect(metadata.height, 180);
    expect(metadata.duration.inSeconds, greaterThanOrEqualTo(1));

    final result = await service.extractFrames(
      metadata: metadata,
      settings: ExtractionSettings(
        fps: 2,
        format: OutputFormat.png,
        outputDirectory: temp.path,
      ),
      outputDirectory: temp.path,
      expectedFrames: 4,
      onProgress: (_) {},
    );

    expect(result.frames.length, greaterThanOrEqualTo(3));
    expect(result.frames.every((frame) => frame.width == 320), isTrue);
    expect(result.frames.every((frame) => frame.height == 180), isTrue);
    expect(result.frames.every((frame) => frame.name.endsWith('.png')), isTrue);
  });
}

Future<bool> _hasFfmpeg() async {
  try {
    final ffmpeg = await Process.run('ffmpeg', ['-version']);
    final ffprobe = await Process.run('ffprobe', ['-version']);
    return ffmpeg.exitCode == 0 && ffprobe.exitCode == 0;
  } catch (_) {
    return false;
  }
}
