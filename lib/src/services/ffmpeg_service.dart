import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../core/formatters.dart';
import '../models/app_models.dart';

class ExtractionResult {
  const ExtractionResult({required this.outputDirectory, required this.frames});

  final String outputDirectory;
  final List<FrameFile> frames;
}

class FfmpegService {
  Process? _process;
  DateTime? _startedAt;
  bool _paused = false;
  String? _ffmpegPath;
  String? _ffprobePath;

  /// Public getters so other services can reuse the resolved paths.
  String? get ffmpegPath => _ffmpegPath;
  String? get ffprobePath => _ffprobePath;

  Future<void> ensureAvailable() async {
    _ffmpegPath ??= await _resolveExecutable('ffmpeg');
    _ffprobePath ??= await _resolveExecutable('ffprobe');
    if (_ffmpegPath == null || _ffprobePath == null) {
      throw const FileSystemException(
        'FFmpeg and ffprobe must be installed and available in PATH or a standard install location.',
      );
    }
  }

  Future<VideoMetadata> readMetadata(String path) async {
    await ensureAvailable();
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('The selected video could not be read.', path);
    }

    final result = await Process.run(_ffprobePath!, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      path,
    ]);

    if (result.exitCode != 0) {
      throw FormatException('Unable to read video metadata: ${result.stderr}');
    }

    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final streams = (json['streams'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final videoStream = streams.firstWhere(
      (stream) => stream['codec_type'] == 'video',
      orElse: () => throw const FormatException(
        'The file does not contain a readable video stream.',
      ),
    );
    final format = json['format'] as Map<String, dynamic>;
    final stat = await file.stat();
    final durationSeconds =
        double.tryParse(
          '${format['duration'] ?? videoStream['duration'] ?? 0}',
        ) ??
        0;

    return VideoMetadata(
      name: pathName(path),
      path: path,
      sizeBytes: stat.size,
      duration: Duration(milliseconds: (durationSeconds * 1000).round()),
      width: (videoStream['width'] as num?)?.toInt() ?? 0,
      height: (videoStream['height'] as num?)?.toInt() ?? 0,
      fps: _parseFps(
        '${videoStream['avg_frame_rate'] ?? videoStream['r_frame_rate'] ?? '0/1'}',
      ),
      bitrate:
          int.tryParse(
            '${format['bit_rate'] ?? videoStream['bit_rate'] ?? 0}',
          ) ??
          0,
      codec: '${videoStream['codec_name'] ?? 'Unknown'}'.toUpperCase(),
      format: '${format['format_name'] ?? 'Unknown'}'
          .split(',')
          .first
          .toUpperCase(),
    );
  }

  Future<ExtractionResult> extractFrames({
    required VideoMetadata metadata,
    required ExtractionSettings settings,
    required String outputDirectory,
    required int expectedFrames,
    required void Function(ExtractionProgress progress) onProgress,
  }) async {
    await ensureAvailable();
    final source = File(metadata.path);
    final targetRoot = Directory(outputDirectory);
    if (!await source.exists()) {
      throw FileSystemException(
        'The source video no longer exists.',
        metadata.path,
      );
    }
    if (!await targetRoot.exists()) {
      await targetRoot.create(recursive: true);
    }

    final videoBase = sanitizeFileName(
      metadata.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final target = Directory(
      '${targetRoot.path}${Platform.pathSeparator}${videoBase}_frames_$timestamp',
    );
    await target.create(recursive: true);

    final pattern =
        '${target.path}${Platform.pathSeparator}frame_%06d.${settings.format.extension}';
    final args = <String>['-hide_banner', '-y'];
    if (settings.startTime != null) {
      args.addAll(['-ss', _ffmpegTime(settings.startTime!)]);
    }
    args.addAll(['-i', metadata.path]);
    if (settings.startTime != null && settings.endTime != null) {
      args.addAll(['-t', _ffmpegTime(settings.endTime! - settings.startTime!)]);
    } else if (settings.endTime != null) {
      args.addAll(['-to', _ffmpegTime(settings.endTime!)]);
    }
    args.addAll(['-vf', 'fps=${settings.fps}', '-vsync', '0']);
    switch (settings.format) {
      case OutputFormat.png:
        args.addAll(['-pix_fmt', 'rgb24', '-compression_level', '3']);
      case OutputFormat.jpg:
        args.addAll(['-pix_fmt', 'yuvj444p', '-q:v', '1']);
      case OutputFormat.webp:
        args.addAll(['-lossless', '1']);
    }
    args.add(pattern);

    _startedAt = DateTime.now();
    _paused = false;
    _process = await Process.start(_ffmpegPath!, args);
    final stderrDone = Completer<void>();

    _process!.stderr.transform(utf8.decoder).listen((chunk) async {
      final elapsed = DateTime.now().difference(_startedAt!);
      final frame = _parseFrame(chunk);
      final speed = frame == null || elapsed.inMilliseconds == 0
          ? 0.0
          : frame / (elapsed.inMilliseconds / 1000);
      final percent = expectedFrames <= 0 ? 0.0 : (frame ?? 0) / expectedFrames;
      final remaining = speed <= 0 || expectedFrames <= 0
          ? null
          : Duration(
              seconds: ((expectedFrames - (frame ?? 0)) / speed)
                  .clamp(0, 999999)
                  .round(),
            );
      onProgress(
        ExtractionProgress(
          percent: percent.clamp(0, 1),
          framesExtracted: frame ?? 0,
          elapsed: elapsed,
          remaining: remaining,
          speedFps: speed,
          outputSizeBytes: await _directorySize(target.path),
          message: _paused ? 'Paused' : 'Extracting frames',
        ),
      );
    }, onDone: stderrDone.complete);

    final exitCode = await _process!.exitCode;
    await stderrDone.future;
    _process = null;

    if (exitCode != 0) {
      throw ProcessException(
        'ffmpeg',
        args,
        'FFmpeg failed with exit code $exitCode.',
        exitCode,
      );
    }

    final frames = await _scanFrames(target, metadata.width, metadata.height);
    onProgress(
      ExtractionProgress(
        percent: 1,
        framesExtracted: frames.length,
        elapsed: DateTime.now().difference(_startedAt!),
        speedFps:
            frames.length /
            (DateTime.now().difference(_startedAt!).inMilliseconds / 1000)
                .clamp(0.1, 999999),
        outputSizeBytes: await _directorySize(target.path),
        message: 'Completed',
      ),
    );
    return ExtractionResult(outputDirectory: target.path, frames: frames);
  }

  void cancel() {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }

  bool pause() {
    if (_process == null || Platform.isWindows) return false;
    _process!.kill(ProcessSignal.sigstop);
    _paused = true;
    return true;
  }

  bool resume() {
    if (_process == null || Platform.isWindows) return false;
    _process!.kill(ProcessSignal.sigcont);
    _paused = false;
    return true;
  }

  Future<String?> _resolveExecutable(String name) async {
    final candidates = <String>[
      name,
      if (Platform.isMacOS) ...[
        '/opt/homebrew/bin/$name',
        '/usr/local/bin/$name',
        '/usr/bin/$name',
      ],
      if (Platform.isLinux) ...[
        '/usr/bin/$name',
        '/usr/local/bin/$name',
        '/snap/bin/$name',
      ],
      if (Platform.isWindows) ...[
        name.endsWith('.exe') ? name : '$name.exe',
        '${Platform.environment['ProgramFiles'] ?? r'C:\Program Files'}\\ffmpeg\\bin\\$name.exe',
        '${Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)'}\\ffmpeg\\bin\\$name.exe',
      ],
    ];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, ['-version']);
        if (result.exitCode == 0) return candidate;
      } catch (_) {
        // Try the next known location.
      }
    }
    return null;
  }

  Future<List<FrameFile>> _scanFrames(
    Directory directory,
    int width,
    int height,
  ) async {
    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return Future.wait(
      files.map(
        (file) => FrameFile.fromFile(file, width: width, height: height),
      ),
    );
  }

  /// Made static so it can run inside Isolate.run.
  static Future<int> _directorySize(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // Ignore files that are still being written.
        }
      }
    }
    return total;
  }

  double _parseFps(String value) {
    final parts = value.split('/');
    if (parts.length == 2) {
      final numerator = double.tryParse(parts[0]) ?? 0;
      final denominator = double.tryParse(parts[1]) ?? 1;
      return denominator == 0 ? 0 : numerator / denominator;
    }
    return double.tryParse(value) ?? 0;
  }

  int? _parseFrame(String chunk) {
    final matches = RegExp(r'frame=\s*(\d+)').allMatches(chunk).toList();
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(1)!);
  }

  String _ffmpegTime(Duration duration) {
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
