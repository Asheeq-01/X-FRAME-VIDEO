import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../core/formatters.dart';
import '../models/app_models.dart';
import '../state/app_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);

    ref.listen(appControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (previous?.errorMessage != next.errorMessage &&
          next.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: controller.clearMessages,
            ),
          ),
        );
      }
      if (previous?.infoMessage != next.infoMessage &&
          next.infoMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(next.infoMessage!),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: controller.clearMessages,
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: state.selectedTab,
            onDestinationSelected: controller.setSelectedTab,
            labelType: NavigationRailLabelType.all,
            minWidth: 92,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.video_file_outlined),
                selectedIcon: Icon(Icons.video_file),
                label: Text('Extract'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_awesome_motion_outlined),
                selectedIcon: Icon(Icons.auto_awesome_motion),
                label: Text('Scenes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.compress_outlined),
                selectedIcon: Icon(Icons.compress),
                label: Text('Compress'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _Header(state: state),
                Expanded(
                  child: IndexedStack(
                    index: state.selectedTab,
                    children: const [
                      _ExtractView(),
                      _SceneDetectionView(),
                      _CompressView(),
                      _HistoryView(),
                      _SettingsView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VideoFrameX Desktop',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  state.metadata == null
                      ? 'Local FFmpeg frame extraction'
                      : state.metadata!.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _StatusPill(
            label: _currentStatusLabel(state),
            color: _currentStatusColor(state, context),
          ),
        ],
      ),
    );
  }

  String _currentStatusLabel(AppState state) {
    if (state.isExtracting) return state.progress.message;
    if (state.isDetectingScenes) return 'Detecting Scenes';
    if (state.isCompressing) return state.compressionProgress.message;
    if (state.isCreatingGif) return 'Creating GIF';
    if (state.isAnalyzingFrames) return 'Analyzing Frames';
    if (state.isGeneratingContactSheet) return 'Contact Sheet';
    return 'Ready';
  }

  Color _currentStatusColor(AppState state, BuildContext context) {
    if (state.isExtracting ||
        state.isDetectingScenes ||
        state.isCompressing ||
        state.isCreatingGif ||
        state.isAnalyzingFrames ||
        state.isGeneratingContactSheet) {
      return Theme.of(context).colorScheme.primary;
    }
    return Colors.green;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  EXTRACT VIEW (Phase 1 + 2 + 3)
// ═════════════════════════════════════════════════════════════════════════════

class _ExtractView extends ConsumerWidget {
  const _ExtractView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    final left = Column(
      children: const [
        _UploadSection(),
        SizedBox(height: 16),
        _MetadataSection(),
        SizedBox(height: 16),
        _QueueSection(),
      ],
    );
    final right = Column(
      children: const [
        _SettingsSection(),
        SizedBox(height: 16),
        _StatsProgressSection(),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: left),
              const SizedBox(width: 18),
              Expanded(flex: 10, child: right),
            ],
          )
        else ...[
          left,
          const SizedBox(height: 16),
          right,
        ],
        const SizedBox(height: 16),
        _ActionBar(state: state),
        const SizedBox(height: 16),
        const _GallerySection(),
        const SizedBox(height: 16),
        _Footer(state: state),
      ],
    );
  }
}

class _UploadSection extends ConsumerStatefulWidget {
  const _UploadSection();

  @override
  ConsumerState<_UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends ConsumerState<_UploadSection> {
  bool _dragging = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(appControllerProvider.notifier);
    final state = ref.watch(appControllerProvider);
    final color = Theme.of(context).colorScheme.primary;
    final canPick = !state.isExtracting && !state.isLoadingMetadata;

    return _Section(
      title: 'Video Upload',
      trailing: OutlinedButton.icon(
        onPressed: canPick ? controller.pickVideos : null,
        icon: const Icon(Icons.folder_open),
        label: const Text('Browse'),
      ),
      child: DropTarget(
        onDragEntered: (_) {
          if (canPick) setState(() => _dragging = true);
        },
        onDragExited: (_) {
          if (canPick) setState(() => _dragging = false);
        },
        onDragDone: (details) async {
          if (!canPick) return;

          try {
            setState(() => _dragging = false);

            final paths = details.files
                .map((file) => file.path)
                .where((path) => path.isNotEmpty)
                .toList();

            debugPrint('Dropped files: $paths');

            if (paths.isEmpty) {
              debugPrint('No files received from drag & drop');
              return;
            }

            await controller.addVideoPaths(paths);
          } catch (e, stack) {
            debugPrint('DROP ERROR: $e');
            debugPrintStack(stackTrace: stack);
          }
        },
        child: MouseRegion(
          cursor: canPick ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) {
            if (canPick) setState(() => _hovered = true);
          },
          onExit: (_) {
            if (canPick) setState(() => _hovered = false);
          },
          child: GestureDetector(
            onTap: canPick ? controller.pickVideos : null,
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: _dragging
                    ? color
                    : _hovered
                        ? color.withValues(alpha: 0.8)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                strokeWidth: _dragging ? 2.0 : (_hovered ? 1.5 : 1.0),
                gap: _dragging ? 4.0 : 6.0,
                dashLength: _dragging ? 8.0 : 6.0,
                borderRadius: 8.0,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 185,
                decoration: BoxDecoration(
                  color: _dragging
                      ? color.withValues(alpha: 0.08)
                      : _hovered
                          ? color.withValues(alpha: 0.04)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _dragging
                              ? color.withValues(alpha: 0.16)
                              : _hovered
                                  ? color.withValues(alpha: 0.08)
                                  : color.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedScale(
                          scale: _dragging ? 1.15 : (_hovered ? 1.08 : 1.0),
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            _dragging
                                ? Icons.file_download
                                : Icons.cloud_upload_outlined,
                            size: 32,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _dragging
                            ? 'Drop to start uploading'
                            : 'Drag & drop videos here',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _dragging
                                  ? color
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                          children: [
                            const TextSpan(text: 'or '),
                            TextSpan(
                              text: 'browse files',
                              style: TextStyle(
                                color: canPick
                                    ? color
                                    : Theme.of(context).disabledColor,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' on your device'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Supports MP4, MOV, AVI, MKV, WEBM, M4V (max 5 GB)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                      if (state.isLoadingMetadata) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 220,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  color: color,
                                  backgroundColor: color.withValues(alpha: 0.1),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Reading video metadata...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dashLength,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(
          strokeWidth / 2,
          strokeWidth / 2,
          size.width - strokeWidth,
          size.height - strokeWidth,
        ),
        Radius.circular(borderRadius),
      ));

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(
            distance,
            length < metric.length ? length : metric.length,
          ),
          paint,
        );
        distance += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _MetadataSection extends ConsumerWidget {
  const _MetadataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(
      appControllerProvider.select((state) => state.metadata),
    );
    return _Section(
      title: 'Video Metadata',
      child: metadata == null
          ? const _EmptyState(
              icon: Icons.info_outline,
              label:
                  'Select a video to inspect codec, duration, resolution, and bitrate.',
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(label: 'Video Name', value: metadata.name),
                _Metric(
                  label: 'File Size',
                  value: formatBytes(metadata.sizeBytes),
                ),
                _Metric(
                  label: 'Duration',
                  value: formatDuration(metadata.duration),
                ),
                _Metric(
                  label: 'Resolution',
                  value: '${metadata.width} x ${metadata.height}',
                ),
                _Metric(label: 'FPS', value: metadata.fps.toStringAsFixed(2)),
                _Metric(
                  label: 'Bitrate',
                  value: metadata.bitrate <= 0
                      ? 'Unknown'
                      : '${(metadata.bitrate / 1000000).toStringAsFixed(2)} Mbps',
                ),
                _Metric(label: 'Codec', value: metadata.codec),
                _Metric(label: 'Format', value: metadata.format),
              ],
            ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    const quickFps = [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0];
    return _Section(
      title: 'Extraction Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Extraction FPS', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fps in quickFps)
                ChoiceChip(
                  label: Text('${fps.toStringAsFixed(0)} FPS'),
                  selected: state.settings.fps == fps,
                  onSelected: (_) => controller.setFps(fps),
                ),
              SizedBox(
                width: 128,
                child: TextFormField(
                  initialValue: state.settings.fps.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.speed),
                    hintText: 'Custom',
                  ),
                  onFieldSubmitted: (value) {
                    final fps = double.tryParse(value);
                    if (fps != null) controller.setFps(fps);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Output Format', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          SegmentedButton<OutputFormat>(
            segments: [
              for (final format in OutputFormat.values)
                ButtonSegment(
                  value: format,
                  label: Text(format.label),
                  icon: const Icon(Icons.image_outlined),
                ),
            ],
            selected: {state.settings.format},
            onSelectionChanged: (selection) =>
                controller.setFormat(selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            state.settings.format.recommendation,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _FolderRow(
            path: state.settings.outputDirectory,
            onChoose: controller.chooseOutputFolder,
          ),
          const SizedBox(height: 18),
          Text('Time Range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Start',
                  value: state.settings.startTime,
                  onChanged: controller.setStartTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeField(
                  label: 'End',
                  value: state.settings.endTime,
                  onChanged: controller.setEndTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.path, required this.onChoose});

  final String? path;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              path ?? 'Choose output folder',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onChoose,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Folder'),
        ),
      ],
    );
  }
}

class _TimeField extends StatefulWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Duration? value;
  final ValueChanged<Duration?> onChanged;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == null ? '' : formatDuration(widget.value!),
    );
  }

  @override
  void didUpdateWidget(covariant _TimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value == null ? '' : formatDuration(widget.value!);
    if (_controller.text != next && oldWidget.value != widget.value) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'HH:MM:SS',
        prefixIcon: const Icon(Icons.timer_outlined),
        suffixIcon: IconButton(
          tooltip: 'Clear',
          onPressed: () {
            _controller.clear();
            widget.onChanged(null);
          },
          icon: const Icon(Icons.close),
        ),
      ),
      onSubmitted: (value) => widget.onChanged(parseClock(value)),
      onEditingComplete: () => widget.onChanged(parseClock(_controller.text)),
    );
  }
}

class _StatsProgressSection extends ConsumerWidget {
  const _StatsProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final metadata = state.metadata;
    return _Section(
      title: 'Statistics & Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: 'Selected FPS',
                value: state.settings.fps.toStringAsFixed(2),
              ),
              _Metric(
                label: 'Expected Frames',
                value: controller.expectedFrames().toString(),
              ),
              _Metric(
                label: 'Generated Frames',
                value: state.progress.framesExtracted.toString(),
              ),
              _Metric(
                label: 'Video Resolution',
                value: metadata == null
                    ? 'None'
                    : '${metadata.width} x ${metadata.height}',
              ),
              _Metric(
                label: 'Current Output Size',
                value: formatBytes(state.progress.outputSizeBytes),
              ),
              _Metric(
                label: 'Estimated ZIP Size',
                value: formatBytes(
                  math.max(
                    state.progress.outputSizeBytes * 0.96,
                    controller.estimatedDiskBytes() * 0.92,
                  ),
                ),
              ),
              _Metric(
                label: 'Processing Speed',
                value: '${state.progress.speedFps.toStringAsFixed(1)} FPS',
              ),
              _Metric(
                label: 'Estimated Disk Usage',
                value: formatBytes(controller.estimatedDiskBytes()),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.isExtracting ? state.progress.percent : null,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(state.progress.percent * 100).clamp(0, 100).toStringAsFixed(0)}%  |  '
                  '${state.progress.framesExtracted} / ${controller.expectedFrames()} frames  |  '
                  'Elapsed ${formatDuration(state.progress.elapsed)}'
                  '${state.progress.remaining == null ? '' : '  |  Remaining ${formatDuration(state.progress.remaining!)}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.isExportingZip)
                Text('ZIP ${(state.zipProgress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: state.isExtracting ? null : controller.extractSelected,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Extract Frames'),
            ),
            OutlinedButton.icon(
              onPressed: state.queue.isEmpty || state.isExtracting
                  ? null
                  : controller.processQueue,
              icon: const Icon(Icons.queue_play_next),
              label: const Text('Process Queue'),
            ),
            OutlinedButton.icon(
              onPressed: !state.isExtracting
                  ? null
                  : state.isPaused
                  ? controller.resumeExtraction
                  : controller.pauseExtraction,
              icon: Icon(
                state.isPaused
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
              ),
              label: Text(state.isPaused ? 'Resume' : 'Pause'),
            ),
            OutlinedButton.icon(
              onPressed: state.isExtracting
                  ? controller.cancelExtraction
                  : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: state.frames.isEmpty || state.isExportingZip
                  ? null
                  : controller.exportZip,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Export ZIP'),
            ),
            // Phase 4: Contact Sheet button
            OutlinedButton.icon(
              onPressed: state.metadata == null ||
                      state.isGeneratingContactSheet
                  ? null
                  : () => _showContactSheetDialog(context, ref),
              icon: const Icon(Icons.grid_on),
              label: const Text('Contact Sheet'),
            ),
            // Phase 4: GIF Creator button
            OutlinedButton.icon(
              onPressed: state.metadata == null || state.isCreatingGif
                  ? null
                  : () => _showGifDialog(context, ref),
              icon: const Icon(Icons.gif_box_outlined),
              label: const Text('Create GIF'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactSheetDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _ContactSheetDialog(),
    );
  }

  void _showGifDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _GifCreatorDialog(),
    );
  }
}

class _QueueSection extends ConsumerWidget {
  const _QueueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(
      appControllerProvider.select((state) => state.queue),
    );
    final controller = ref.read(appControllerProvider.notifier);
    return _Section(
      title: 'Batch Queue',
      trailing: queue.isEmpty
          ? null
          : OutlinedButton.icon(
              onPressed: controller.clearCompletedJobs,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Clear Done'),
            ),
      child: queue.isEmpty
          ? const _EmptyState(
              icon: Icons.queue_outlined,
              label: 'Add multiple videos to build a processing queue.',
            )
          : Column(
              children: [
                for (final job in queue)
                  ListTile(
                    dense: true,
                    leading: Icon(_statusIcon(job.status)),
                    title: Text(
                      job.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(job.error ?? job.status.name.toUpperCase()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusPill(
                          label: job.status.name,
                          color: _statusColor(job.status),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Remove from queue',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              controller.removeFromQueue(job.id),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GallerySection extends ConsumerWidget {
  const _GallerySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final tileWidth = state.userSettings.thumbnailSize
        .clamp(120, 260)
        .toDouble();
    return _Section(
      title: 'Frame Gallery',
      trailing: Wrap(
        spacing: 8,
        children: [
          if (state.frames.isNotEmpty) ...[
            // AI Analysis button
            OutlinedButton.icon(
              onPressed: state.isAnalyzingFrames
                  ? null
                  : controller.analyzeFrames,
              icon: state.isAnalyzingFrames
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 18),
              label: Text(state.isAnalyzingFrames
                  ? '${(state.analysisProgress * 100).toStringAsFixed(0)}%'
                  : 'AI Analyze'),
            ),
            if (state.frameAnalyses.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () => controller.removeDuplicateFrames(),
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Remove Dupes'),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.removeBlurryFrames(500),
                icon: const Icon(Icons.blur_off, size: 18),
                label: const Text('Remove Blurry'),
              ),
            ],
          ],
          Text('${state.frames.length} frames'),
        ],
      ),
      child: state.frames.isEmpty
          ? const _EmptyState(
              icon: Icons.grid_view_outlined,
              label:
                  'Extracted frames appear here with lazy thumbnails and export controls.',
            )
          : SizedBox(
              height: math.min(
                620,
                math.max(300, MediaQuery.sizeOf(context).height * 0.55),
              ),
              child: GridView.builder(
                itemCount: state.frames.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: tileWidth + 88,
                  mainAxisExtent: tileWidth + 106,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final frame = state.frames[index];
                  final analysis = state.frameAnalyses[frame.path];
                  return _FrameCard(
                    frame: frame,
                    analysis: analysis,
                    thumbnailSize: tileWidth,
                    onPreview: () => _showPreview(context, frame),
                    onSave: () => controller.saveFrame(frame),
                    onDelete: () => controller.deleteFrame(frame),
                  );
                },
              ),
            ),
    );
  }

  void _showPreview(BuildContext context, FrameFile frame) {
    showDialog<void>(
      context: context,
      builder: (_) => _PreviewDialog(frame: frame),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.frame,
    required this.thumbnailSize,
    required this.onPreview,
    required this.onSave,
    required this.onDelete,
    this.analysis,
  });

  final FrameFile frame;
  final double thumbnailSize;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final FrameAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: thumbnailSize,
                  width: double.infinity,
                  child: Image.file(
                    File(frame.path),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    cacheWidth: (thumbnailSize * 1.5).round(),
                  ),
                ),
                // Analysis badges
                if (analysis != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (analysis!.isDuplicate)
                          _Badge(
                            label: 'DUPE',
                            color: Colors.orange,
                          ),
                        if (analysis!.blurScore < 500)
                          _Badge(
                            label: 'BLUR',
                            color: Colors.red,
                          ),
                        if (analysis!.blurScore >= 500 && !analysis!.isDuplicate)
                          _Badge(
                            label: '#${analysis!.qualityRank}',
                            color: Colors.green,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                frame.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '${frame.width ?? '-'} x ${frame.height ?? '-'}  |  ${formatBytes(frame.sizeBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Spacer(),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Save frame',
                  onPressed: onSave,
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Delete frame',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({required this.frame});

  final FrameFile frame;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Column(
        children: [
          AppBar(
            title: Text(widget.frame.name),
            actions: [
              IconButton(
                tooltip: 'Rotate',
                onPressed: () => setState(() => _quarterTurns++),
                icon: const Icon(Icons.rotate_90_degrees_ccw),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: _quarterTurns,
              child: PhotoView(
                imageProvider: FileImage(File(widget.frame.path)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 5,
                enableRotation: true,
                backgroundDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text('Frame ${widget.frame.name}')),
                Text(
                  '${widget.frame.width ?? '-'} x ${widget.frame.height ?? '-'}',
                ),
                const SizedBox(width: 18),
                Text(formatBytes(widget.frame.sizeBytes)),
                const SizedBox(width: 18),
                Text(
                  widget.frame.createdAt.toLocal().toString().split('.').first,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SCENE DETECTION VIEW (Phase 4A)
// ═════════════════════════════════════════════════════════════════════════════

class _SceneDetectionView extends ConsumerWidget {
  const _SceneDetectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final sceneSettings = state.sceneSettings;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Section(
          title: 'Scene Detection Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.metadata == null)
                const _EmptyState(
                  icon: Icons.videocam_off_outlined,
                  label:
                      'Load a video in the Extract tab first to use scene detection.',
                )
              else ...[
                Text(
                  'Loaded: ${state.metadata!.name}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                Text(
                  'Scene Change Threshold: ${sceneSettings.threshold.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Lower values detect more scenes. Recommended: 0.2 – 0.5',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Slider(
                  min: 0.05,
                  max: 0.8,
                  divisions: 15,
                  value: sceneSettings.threshold.clamp(0.05, 0.8),
                  onChanged: (v) => controller.updateSceneSettings(
                    sceneSettings.copyWith(threshold: v),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Minimum Scene Duration: ${sceneSettings.minSceneDurationSeconds.toStringAsFixed(1)}s',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  min: 0.5,
                  max: 10.0,
                  divisions: 19,
                  value: sceneSettings.minSceneDurationSeconds.clamp(0.5, 10.0),
                  onChanged: (v) => controller.updateSceneSettings(
                    sceneSettings.copyWith(minSceneDurationSeconds: v),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: state.isDetectingScenes
                          ? null
                          : controller.detectScenes,
                      icon: state.isDetectingScenes
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(state.isDetectingScenes
                          ? 'Detecting ${(state.sceneDetectionProgress * 100).toStringAsFixed(0)}%'
                          : 'Detect Scenes'),
                    ),
                    if (state.detectedScenes.isNotEmpty)
                      FilledButton.icon(
                        onPressed: state.isExtracting
                            ? null
                            : controller.extractSceneFrames,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          'Extract ${state.detectedScenes.length} Scene Frames',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (state.isDetectingScenes) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Detection Progress',
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.sceneDetectionProgress,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(state.sceneDetectionProgress * 100).toStringAsFixed(0)}% complete',
                ),
              ],
            ),
          ),
        ],
        if (state.detectedScenes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Detected Scenes (${state.detectedScenes.length})',
            child: SizedBox(
              height: math.min(400, state.detectedScenes.length * 56.0 + 16),
              child: ListView.builder(
                itemCount: state.detectedScenes.length,
                itemBuilder: (context, index) {
                  final scene = state.detectedScenes[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        '${scene.index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(
                      'Scene ${scene.index + 1}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Timestamp: ${formatDuration(scene.timestamp)}',
                    ),
                    trailing: _StatusPill(
                      label: formatDuration(scene.timestamp),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  COMPRESS VIEW (Phase 4D)
// ═════════════════════════════════════════════════════════════════════════════

class _CompressView extends ConsumerWidget {
  const _CompressView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final cs = state.compressionSettings;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Section(
          title: 'Video Compression',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.metadata == null)
                const _EmptyState(
                  icon: Icons.videocam_off_outlined,
                  label:
                      'Load a video in the Extract tab first to compress it.',
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(label: 'Source', value: state.metadata!.name),
                    _Metric(
                      label: 'Original Size',
                      value: formatBytes(state.metadata!.sizeBytes),
                    ),
                    _Metric(
                      label: 'Duration',
                      value: formatDuration(state.metadata!.duration),
                    ),
                    _Metric(
                      label: 'Source Codec',
                      value: state.metadata!.codec,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Codec selection
                Text('Output Codec',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                SegmentedButton<CompressionCodec>(
                  segments: [
                    for (final codec in CompressionCodec.values)
                      ButtonSegment(
                        value: codec,
                        label: Text(codec.label),
                      ),
                  ],
                  selected: {cs.codec},
                  onSelectionChanged: (s) => controller
                      .updateCompressionSettings(cs.copyWith(codec: s.first)),
                ),
                const SizedBox(height: 18),

                // Encoding preset
                Text('Encoding Speed',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                SegmentedButton<CompressionPreset>(
                  segments: [
                    for (final preset in CompressionPreset.values)
                      ButtonSegment(
                        value: preset,
                        label: Text(preset.label),
                      ),
                  ],
                  selected: {cs.preset},
                  onSelectionChanged: (s) => controller
                      .updateCompressionSettings(cs.copyWith(preset: s.first)),
                ),
                const SizedBox(height: 18),

                // CRF slider
                Text(
                  'Quality (CRF): ${cs.crf}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Lower = better quality & larger file. Recommended: 18–28.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Slider(
                  min: 0,
                  max: 51,
                  divisions: 51,
                  value: cs.crf.toDouble(),
                  onChanged: (v) => controller.updateCompressionSettings(
                    cs.copyWith(crf: v.round()),
                  ),
                ),
                const SizedBox(height: 12),

                // Scale
                Text(
                  'Resolution Scale: ${cs.scalePercent}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  min: 25,
                  max: 100,
                  divisions: 15,
                  value: cs.scalePercent.toDouble().clamp(25, 100),
                  onChanged: (v) => controller.updateCompressionSettings(
                    cs.copyWith(scalePercent: v.round()),
                  ),
                ),
                const SizedBox(height: 12),

                // Audio bitrate
                Text(
                  'Audio Bitrate: ${cs.audioBitrate} kbps',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  min: 64,
                  max: 320,
                  divisions: 8,
                  value: cs.audioBitrate.toDouble().clamp(64, 320),
                  onChanged: (v) => controller.updateCompressionSettings(
                    cs.copyWith(audioBitrate: v.round()),
                  ),
                ),
                const SizedBox(height: 18),

                // Output folder
                _FolderRow(
                  path: state.settings.outputDirectory,
                  onChoose: controller.chooseOutputFolder,
                ),
                const SizedBox(height: 18),

                // Action buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          state.isCompressing ? null : controller.compressVideo,
                      icon: const Icon(Icons.compress),
                      label: const Text('Compress Video'),
                    ),
                    if (state.isCompressing)
                      OutlinedButton.icon(
                        onPressed: controller.cancelCompression,
                        icon: const Icon(Icons.stop),
                        label: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Progress section
        if (state.isCompressing ||
            state.compressionProgress.percent > 0) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Compression Progress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.isCompressing
                        ? state.compressionProgress.percent
                        : null,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(
                      label: 'Progress',
                      value:
                          '${(state.compressionProgress.percent * 100).toStringAsFixed(0)}%',
                    ),
                    _Metric(
                      label: 'Time Position',
                      value: formatDuration(
                          state.compressionProgress.currentTime),
                    ),
                    if (state.compressionProgress.speed.isNotEmpty)
                      _Metric(
                        label: 'Speed',
                        value: state.compressionProgress.speed,
                      ),
                    _Metric(
                      label: 'Output Size',
                      value: formatBytes(
                          state.compressionProgress.outputSizeBytes),
                    ),
                    _Metric(
                      label: 'Status',
                      value: state.compressionProgress.message,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Result section
        if (state.compressedOutputPath != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Compression Result',
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.compressedOutputPath!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      controller.openFolder(File(state.compressedOutputPath!).parent.path),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Folder'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CONTACT SHEET DIALOG (Phase 4B)
// ═════════════════════════════════════════════════════════════════════════════

class _ContactSheetDialog extends ConsumerWidget {
  const _ContactSheetDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final cs = state.contactSheetSettings;

    return AlertDialog(
      title: const Text('Generate Contact Sheet'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Columns: ${cs.columns}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              min: 2,
              max: 8,
              divisions: 6,
              value: cs.columns.toDouble(),
              onChanged: (v) => controller.updateContactSheetSettings(
                cs.copyWith(columns: v.round()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rows: ${cs.rows}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              min: 2,
              max: 8,
              divisions: 6,
              value: cs.rows.toDouble(),
              onChanged: (v) => controller.updateContactSheetSettings(
                cs.copyWith(rows: v.round()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thumbnail Width: ${cs.thumbWidth}px',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              min: 160,
              max: 640,
              divisions: 12,
              value: cs.thumbWidth.toDouble(),
              onChanged: (v) => controller.updateContactSheetSettings(
                cs.copyWith(thumbWidth: v.round()),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Show Timestamps'),
              value: cs.showTimestamps,
              onChanged: (v) => controller.updateContactSheetSettings(
                cs.copyWith(showTimestamps: v),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total thumbnails: ${cs.columns * cs.rows}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (state.isGeneratingContactSheet) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (state.contactSheetPath != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved: ${state.contactSheetPath!.split(Platform.pathSeparator).last}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: state.isGeneratingContactSheet
              ? null
              : controller.generateContactSheet,
          icon: const Icon(Icons.grid_on),
          label: const Text('Generate'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  GIF CREATOR DIALOG (Phase 4C)
// ═════════════════════════════════════════════════════════════════════════════

class _GifCreatorDialog extends ConsumerWidget {
  const _GifCreatorDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final gs = state.gifSettings;

    return AlertDialog(
      title: const Text('Create Animated GIF'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GIF FPS: ${gs.fps.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              min: 5,
              max: 30,
              divisions: 5,
              value: gs.fps.clamp(5, 30),
              onChanged: (v) => controller.updateGifSettings(
                gs.copyWith(fps: v),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Width: ${gs.width}px',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              min: 240,
              max: 960,
              divisions: 9,
              value: gs.width.toDouble().clamp(240, 960),
              onChanged: (v) => controller.updateGifSettings(
                gs.copyWith(width: v.round()),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Time Range (optional)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Start',
                    value: gs.startTime,
                    onChanged: (v) => controller.updateGifSettings(
                      gs.copyWith(startTime: v, clearStart: v == null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'End',
                    value: gs.endTime,
                    onChanged: (v) => controller.updateGifSettings(
                      gs.copyWith(endTime: v, clearEnd: v == null),
                    ),
                  ),
                ),
              ],
            ),
            if (state.isCreatingGif) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.gifProgress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(state.gifProgress * 100).toStringAsFixed(0)}% complete',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.gifOutputPath != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved: ${state.gifOutputPath!.split(Platform.pathSeparator).last}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (state.isCreatingGif)
          OutlinedButton.icon(
            onPressed: controller.cancelGif,
            icon: const Icon(Icons.stop),
            label: const Text('Cancel'),
          ),
        FilledButton.icon(
          onPressed: state.isCreatingGif ? null : controller.createGif,
          icon: const Icon(Icons.gif_box),
          label: const Text('Create GIF'),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HISTORY VIEW (Phase 2)
// ═════════════════════════════════════════════════════════════════════════════

class _HistoryView extends ConsumerWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Section(
          title: 'Extraction History',
          trailing: OutlinedButton.icon(
            onPressed: state.history.isEmpty ? null : controller.clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear All'),
          ),
          child: state.history.isEmpty
              ? const _EmptyState(
                  icon: Icons.history,
                  label: 'Completed and failed extractions are stored locally.',
                )
              : Column(
                  children: [
                    for (final entry in state.history)
                      ListTile(
                        leading: Icon(_statusIcon(entry.status)),
                        title: Text(
                          entry.videoName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${entry.date.toLocal().toString().split('.').first}  |  '
                          '${entry.fps.toStringAsFixed(2)} FPS  |  '
                          '${entry.format.label}  |  ${entry.framesGenerated} frames',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Open folder',
                              onPressed: () =>
                                  controller.openFolder(entry.outputLocation),
                              icon: const Icon(Icons.folder_open),
                            ),
                            IconButton(
                              tooltip: 'Delete history',
                              onPressed: () =>
                                  controller.deleteHistory(entry.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SETTINGS VIEW (Phase 3)
// ═════════════════════════════════════════════════════════════════════════════

class _SettingsView extends ConsumerWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      appControllerProvider.select((state) => state.userSettings),
    );
    final controller = ref.read(appControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Section(
          title: 'Application Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: settings.defaultFps.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Default FPS',
                        prefixIcon: Icon(Icons.speed),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onFieldSubmitted: (value) {
                        final fps = double.tryParse(value);
                        if (fps != null) {
                          controller.updateUserSettings(
                            settings.copyWith(defaultFps: fps),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<OutputFormat>(
                      initialValue: settings.defaultFormat,
                      decoration: const InputDecoration(
                        labelText: 'Default Format',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                      items: [
                        for (final format in OutputFormat.values)
                          DropdownMenuItem(
                            value: format,
                            child: Text(format.label),
                          ),
                      ],
                      onChanged: (format) {
                        if (format != null) {
                          controller.updateUserSettings(
                            settings.copyWith(defaultFormat: format),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<ThemePreference>(
                initialValue: settings.theme,
                decoration: const InputDecoration(
                  labelText: 'Theme',
                  prefixIcon: Icon(Icons.contrast),
                ),
                items: [
                  for (final theme in ThemePreference.values)
                    DropdownMenuItem(
                      value: theme,
                      child: Text(theme.name.toUpperCase()),
                    ),
                ],
                onChanged: (theme) {
                  if (theme != null) {
                    controller.updateUserSettings(
                      settings.copyWith(theme: theme),
                    );
                  }
                },
              ),
              const SizedBox(height: 18),
              Text('Thumbnail Size: ${settings.thumbnailSize.round()} px'),
              Slider(
                min: 120,
                max: 260,
                divisions: 7,
                value: settings.thumbnailSize.clamp(120, 260),
                onChanged: (value) => controller.updateUserSettings(
                  settings.copyWith(thumbnailSize: value),
                ),
              ),
              const SizedBox(height: 12),
              Text('Maximum Concurrent Tasks: ${settings.maxConcurrentTasks}'),
              Slider(
                min: 1,
                max: 4,
                divisions: 3,
                value: settings.maxConcurrentTasks.toDouble().clamp(1, 4),
                onChanged: (value) => controller.updateUserSettings(
                  settings.copyWith(maxConcurrentTasks: value.round()),
                ),
              ),
              const SizedBox(height: 18),
              _FolderRow(
                path: settings.defaultOutputFolder,
                onChoose: controller.chooseOutputFolder,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('VideoFrameX Desktop 1.0.0'),
        const SizedBox(width: 16),
        Text(
          'Company: VideoFrameX',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),
        Text(
          'Original resolution preserved: ${state.metadata == null ? 'no video selected' : '${state.metadata!.width} x ${state.metadata!.height}'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

IconData _statusIcon(JobStatus status) {
  return switch (status) {
    JobStatus.pending => Icons.schedule,
    JobStatus.processing => Icons.autorenew,
    JobStatus.paused => Icons.pause_circle_outline,
    JobStatus.completed => Icons.check_circle_outline,
    JobStatus.failed => Icons.error_outline,
    JobStatus.canceled => Icons.cancel_outlined,
  };
}

Color _statusColor(JobStatus status) {
  return switch (status) {
    JobStatus.pending => Colors.blueGrey,
    JobStatus.processing => Colors.blue,
    JobStatus.paused => Colors.orange,
    JobStatus.completed => Colors.green,
    JobStatus.failed => Colors.red,
    JobStatus.canceled => Colors.grey,
  };
}
