import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/app_models.dart';

class FrameAnalysisService {
  /// Analyzes extracted frames for blur and duplicate detection.
  /// Uses Dart isolates for CPU-intensive pixel analysis.
  Future<Map<String, FrameAnalysis>> analyzeFrames({
    required List<FrameFile> frames,
    void Function(double progress)? onProgress,
  }) async {
    if (frames.isEmpty) return {};

    final results = <String, FrameAnalysis>{};
    Uint8List? previousHash;

    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final file = File(frame.path);

      if (!await file.exists()) {
        results[frame.path] = FrameAnalysis(
          framePath: frame.path,
          blurScore: 0,
          isDuplicate: false,
          qualityRank: i,
        );
        onProgress?.call((i + 1) / frames.length);
        continue;
      }

      // Read the file bytes
      final bytes = await file.readAsBytes();

      // Run analysis in an isolate to avoid blocking the UI
      final analysisResult = await Isolate.run(() {
        return _analyzeFrame(bytes);
      });

      final blurScore = analysisResult.blurScore;
      final currentHash = analysisResult.hash;

      // Check for duplicate by comparing average hashes
      bool isDuplicate = false;
      if (previousHash != null) {
        final distance = _hammingDistance(previousHash, currentHash);
        // Threshold: if fewer than 5 bits differ in the 64-bit hash,
        // frames are near-identical
        isDuplicate = distance < 5;
      }
      previousHash = currentHash;

      results[frame.path] = FrameAnalysis(
        framePath: frame.path,
        blurScore: blurScore,
        isDuplicate: isDuplicate,
        qualityRank: i,
      );

      onProgress?.call((i + 1) / frames.length);
    }

    // Assign quality ranks based on blur score (higher = sharper = better)
    final sorted = results.entries.toList()
      ..sort((a, b) => b.value.blurScore.compareTo(a.value.blurScore));

    final ranked = <String, FrameAnalysis>{};
    for (var i = 0; i < sorted.length; i++) {
      final entry = sorted[i];
      ranked[entry.key] = FrameAnalysis(
        framePath: entry.value.framePath,
        blurScore: entry.value.blurScore,
        isDuplicate: entry.value.isDuplicate,
        qualityRank: i + 1,
      );
    }

    return ranked;
  }

  /// Computes hamming distance between two hash byte arrays.
  static int _hammingDistance(Uint8List a, Uint8List b) {
    var distance = 0;
    final len = math.min(a.length, b.length);
    for (var i = 0; i < len; i++) {
      var xor = a[i] ^ b[i];
      while (xor > 0) {
        distance += xor & 1;
        xor >>= 1;
      }
    }
    return distance;
  }
}

/// Result from frame analysis in an isolate.
class _FrameAnalysisResult {
  const _FrameAnalysisResult({required this.blurScore, required this.hash});

  final double blurScore;
  final Uint8List hash;
}

/// Analyzes a single frame for blur detection and generates an average hash.
/// This runs in an isolate for performance.
_FrameAnalysisResult _analyzeFrame(Uint8List bytes) {
  // Simple blur detection using byte variance as a proxy
  // Higher variance = more detail = less blur
  // This is a simplified approach that works on raw file bytes
  final blurScore = _computeVariance(bytes);

  // Compute average hash (aHash) from the raw bytes
  // We sample bytes at regular intervals to build a 64-bit hash
  final hash = _computeAverageHash(bytes);

  return _FrameAnalysisResult(blurScore: blurScore, hash: hash);
}

/// Computes byte-level variance as a blur proxy metric.
/// Sharp images have higher variance (more byte-level variation).
double _computeVariance(Uint8List bytes) {
  if (bytes.isEmpty) return 0;

  // Sample every Nth byte for performance (skip headers)
  final sampleSize = math.min(bytes.length, 50000);
  final step = math.max(1, bytes.length ~/ sampleSize);
  final headerOffset = math.min(100, bytes.length ~/ 10);

  var sum = 0.0;
  var sumSq = 0.0;
  var count = 0;

  for (var i = headerOffset; i < bytes.length; i += step) {
    final v = bytes[i].toDouble();
    sum += v;
    sumSq += v * v;
    count++;
  }

  if (count == 0) return 0;

  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  return variance.abs();
}

/// Computes an 8-byte average hash of the image bytes.
Uint8List _computeAverageHash(Uint8List bytes) {
  if (bytes.isEmpty) return Uint8List(8);

  // Sample 64 evenly-spaced byte values from the file (skipping headers)
  final headerOffset = math.min(100, bytes.length ~/ 10);
  final usableLength = bytes.length - headerOffset;
  if (usableLength <= 64) return Uint8List(8);

  final step = usableLength ~/ 64;
  final samples = Uint8List(64);

  var sum = 0;
  for (var i = 0; i < 64; i++) {
    samples[i] = bytes[headerOffset + i * step];
    sum += samples[i];
  }

  final mean = sum ~/ 64;
  final hash = Uint8List(8);

  for (var i = 0; i < 64; i++) {
    if (samples[i] >= mean) {
      hash[i ~/ 8] |= (1 << (7 - (i % 8)));
    }
  }

  return hash;
}
