import 'dart:io';
import 'dart:math' as math;

String formatBytes(num bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final index = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    units.length - 1,
  );
  final value = bytes / math.pow(1024, index);
  return '${value.toStringAsFixed(index == 0 ? 0 : decimals)} ${units[index]}';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

Duration? parseClock(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length != 3) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  final seconds = int.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) return null;
  if (minutes > 59 || seconds > 59 || hours < 0 || minutes < 0 || seconds < 0) {
    return null;
  }
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

String pathName(String path) => path.split(Platform.pathSeparator).last;

String sanitizeFileName(String value) {
  final clean = value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  return clean.isEmpty ? 'video' : clean;
}
