import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../comments/comments_panel.dart';
import '../player/audio_player_controller.dart';
import '../player/waveform_scrubber.dart';
import '../transcript/transcript_controller.dart';
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
  bool _transcriptExpanded = false;

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
    final assignmentState = ref.watch(assignmentControllerProvider);
    final statusState = ref.watch(statusControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF115343),
        foregroundColor: Colors.white,
        title: Text(
          'Recording Player',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
        ),
      ),
      body: recordingAsync.when(
        data: (recording) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Recordings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    if (!_transcriptExpanded)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Case: ${recording.title} (${recording.caseNumber})',
                                style: GoogleFonts.roboto(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF115343),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9ECEF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: WaveformScrubber(
                                  position: playerState.position,
                                  duration: playerState.duration,
                                  onSeek: playerController.seek,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  '${_formatTimestamp(playerState.position)} / ${_formatTimestamp(playerState.duration)}',
                                  style: GoogleFonts.roboto(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF115343),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PlaybackButton(
                                    icon: Icons.replay_10,
                                    onPressed: playerController.rewind,
                                  ),
                                  const SizedBox(width: 16),
                                  _PlaybackButton(
                                    icon: playerState.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    onPressed: playerController.playPause,
                                  ),
                                  const SizedBox(width: 16),
                                  _PlaybackButton(
                                    icon: Icons.forward_10,
                                    onPressed: playerController.forward,
                                  ),
                                  const SizedBox(width: 16),
                                  _PlaybackButton(
                                    icon: Icons.download,
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Playback Speed:',
                                        style: GoogleFonts.roboto(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      DropdownButton<double>(
                                        value: playerState.speed,
                                        items: const [
                                          0.5,
                                          1.0,
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
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Annotations',
                                        style: GoogleFonts.roboto(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            'Annotations will appear here',
                                            style: GoogleFonts.roboto(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_transcriptExpanded) const SizedBox(width: 20),
                    Expanded(
                      flex: _transcriptExpanded ? 2 : 1,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transcript',
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF115343),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => ref
                                      .read(transcriptControllerProvider.notifier)
                                      .save(),
                                  icon: const Icon(Icons.save, size: 16),
                                  label: const Text('Save'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.file_upload, size: 16),
                                  label: const Text('Export'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setState(
                                      () => _transcriptExpanded = !_transcriptExpanded),
                                  icon: const Icon(Icons.expand, size: 16),
                                  label: Text(
                                    _transcriptExpanded
                                        ? 'Default View'
                                        : 'Expand Editor',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(transcriptControllerProvider.notifier)
                                      .retranscribe(),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retranscribe'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: DropdownButtonFormField<String>(
                                    value: _normalizeStatus(recording.status),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
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
                                ),
                                OutlinedButton.icon(
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
                                  icon: const Icon(Icons.playlist_add, size: 16),
                                  label: Text(
                                    assignmentState.assignment == null
                                        ? 'My List'
                                        : 'Remove My List',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(recordingDetailProvider(widget.recordingId)
                                          .future),
                                  icon: const Icon(Icons.sync, size: 16),
                                  label: const Text('Refresh'),
                                ),
                                if (statusState.isLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TranscriptEditor(recordingId: recording.id),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: CommentsPanel(recordingId: recording.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _formatTimestamp(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(duration.inHours);
    final minutes = two(duration.inMinutes.remainder(60));
    final secs = two(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secs';
  }

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'pending';
    switch (value) {
      case 'pending_transcription':
      case 'pending-transcription':
      case 'pendingtranscription':
        return 'pending';
      case 'inprogress':
      case 'in_progress':
      case 'processing':
        return 'in_progress';
      case 'completed':
      case 'reviewed':
      case 'pending':
        return value;
      default:
        return 'pending';
    }
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF115343),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
      ),
      child: Icon(icon),
    );
  }
}
