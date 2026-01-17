import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recording.dart';
import '../comments/comments_panel.dart';
import '../player/audio_player_controller.dart';
import '../player/waveform_scrubber.dart';
import '../transcript/transcript_editor.dart';
import 'assignment_controller.dart';
import 'recording_detail_controller.dart';
import 'status_controller.dart';

class RecordingDetailScreen extends ConsumerStatefulWidget {
  const RecordingDetailScreen({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<RecordingDetailScreen> createState() =>
      _RecordingDetailScreenState();
}

class _RecordingDetailScreenState
    extends ConsumerState<RecordingDetailScreen> {
  bool _transcriptExpanded = true;

  @override
  void initState() {
    super.initState();
    ref.read(recordingDetailProvider(widget.recordingId).future).then((recording) {
      ref
          .read(audioPlayerControllerProvider.notifier)
          .loadRecording(recording.audioPath);
      ref.read(assignmentControllerProvider.notifier).load(recording.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordingAsync = ref.watch(recordingDetailProvider(widget.recordingId));
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playerController = ref.read(audioPlayerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Recording ${widget.recordingId}'),
      ),
      body: recordingAsync.when(
        data: (recording) => Column(
          children: [
            _RecordingHeader(recording: recording),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  WaveformScrubber(
                    position: playerState.position,
                    duration: playerState.duration,
                    onSeek: playerController.seek,
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => playerController.rewind(),
                        icon: const Icon(Icons.replay_5),
                        tooltip: 'Rewind 5s',
                      ),
                      IconButton(
                        onPressed: () => playerController.playPause(),
                        icon: Icon(
                          playerState.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        tooltip: 'Play/Pause',
                      ),
                      IconButton(
                        onPressed: () => playerController.forward(),
                        icon: const Icon(Icons.forward_5),
                        tooltip: 'Forward 5s',
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<double>(
                        value: playerState.speed,
                        items: const [
                          0.25,
                          0.5,
                          0.75,
                          1.0,
                          1.25,
                          1.5,
                          2.0
                        ]
                            .map(
                              (speed) => DropdownMenuItem(
                                value: speed,
                                child: Text('${speed}x'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            playerController.setSpeed(value);
                          }
                        },
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _transcriptExpanded = !_transcriptExpanded),
                        icon: Icon(
                          _transcriptExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: const Text('Transcript'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: _transcriptExpanded ? 3 : 1,
                    child: _transcriptExpanded
                        ? TranscriptEditor(recordingId: recording.id)
                        : const Center(child: Text('Transcript collapsed')),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 1,
                    child: CommentsPanel(recordingId: recording.id),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _RecordingHeader extends ConsumerWidget {
  const _RecordingHeader({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentState = ref.watch(assignmentControllerProvider);
    final statusState = ref.watch(statusControllerProvider);
    return ListTile(
      title: Text('${recording.caseNumber} • ${recording.title}'),
      subtitle: Text('${recording.court} • ${recording.courtroom}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: assignmentState.isLoading
                ? null
                : () {
                    if (assignmentState.assignment == null) {
                      ref
                          .read(assignmentControllerProvider.notifier)
                          .assign(recording.id);
                    } else {
                      ref
                          .read(assignmentControllerProvider.notifier)
                          .unassign(recording.id);
                    }
                  },
            child: Text(
              assignmentState.assignment == null ? 'Assign to me' : 'Unassign',
            ),
          ),
          DropdownButton<String>(
            value: recording.status,
            items: const [
              'pending',
              'in_progress',
              'completed',
              'reviewed',
            ]
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(),
            onChanged: statusState.isLoading
                ? null
                : (value) {
                    if (value != null) {
                      ref
                          .read(statusControllerProvider.notifier)
                          .updateStatus(recording.id, value);
                    }
                  },
          ),
          if (statusState.isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
