import 'dart:io';

import '../models/app_models.dart';

class ContactSheetService {
  /// Generates a contact sheet (thumbnail montage) from a video using
  /// FFmpeg's tile filter. Produces a single image with a grid of thumbnails.
  Future<String> generate({
    required String videoPath,
    required String ffmpegPath,
    required String outputPath,
    required Duration videoDuration,
    required ContactSheetSettings settings,
    void Function(double progress)? onProgress,
  }) async {
    final totalFrames = settings.columns * settings.rows;
    final intervalSeconds = videoDuration.inSeconds / (totalFrames + 1);

    // Build the FFmpeg filter for creating a contact sheet
    // 1. Select frames at regular intervals
    // 2. Scale to thumbnail size
    // 3. Tile into a grid
    final selectExpr =
        'isnan(prev_selected_t)+gte(t-prev_selected_t,$intervalSeconds)';
    final scaleFilter = 'scale=${settings.thumbWidth}:-1';
    final tileFilter =
        'tile=${settings.columns}x${settings.rows}:padding=4:margin=8:color=0x1a1a2e';

    String filterChain;
    if (settings.showTimestamps) {
      // Add timestamp overlay on each thumbnail
      filterChain =
          "select='$selectExpr',$scaleFilter,"
          "drawtext=text='%{pts\\:hms}':fontsize=14:fontcolor=white:"
          "borderw=2:bordercolor=black:x=5:y=h-20,"
          '$tileFilter';
    } else {
      filterChain = "select='$selectExpr',$scaleFilter,$tileFilter";
    }

    onProgress?.call(0.1);

    final formatArgs = switch (settings.format) {
      OutputFormat.png => ['-pix_fmt', 'rgb24', '-compression_level', '3'],
      OutputFormat.jpg => ['-pix_fmt', 'yuvj444p', '-q:v', '1'],
      OutputFormat.webp => ['-lossless', '1'],
    };

    final result = await Process.run(ffmpegPath, [
      '-hide_banner',
      '-y',
      '-i', videoPath,
      '-vf', filterChain,
      '-vsync', '0',
      '-frames:v', '1',
      ...formatArgs,
      outputPath,
    ]);

    onProgress?.call(0.9);

    if (result.exitCode != 0) {
      throw ProcessException(
        'ffmpeg',
        [],
        'Contact sheet generation failed: ${result.stderr}',
        result.exitCode,
      );
    }

    if (!await File(outputPath).exists()) {
      throw const FileSystemException(
        'Contact sheet file was not created.',
      );
    }

    onProgress?.call(1.0);
    return outputPath;
  }
}
