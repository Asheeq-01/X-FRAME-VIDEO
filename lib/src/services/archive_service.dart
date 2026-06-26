import 'dart:io';

import 'package:archive/archive_io.dart';

import '../models/app_models.dart';

class ArchiveService {
  Future<File> createZip({
    required List<FrameFile> frames,
    required String destinationPath,
    void Function(double progress)? onProgress,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(destinationPath);
    for (var index = 0; index < frames.length; index++) {
      encoder.addFile(File(frames[index].path), frames[index].name);
      onProgress?.call((index + 1) / frames.length);
    }
    encoder.close();
    return File(destinationPath);
  }
}
