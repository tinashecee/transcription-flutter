import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart' as dq;
import 'package:quill_html_converter/quill_html_converter.dart';

import '../comments/comments_panel.dart';
import '../player/audio_player_controller.dart';
import '../player/waveform_scrubber.dart';
import '../transcript/transcript_controller.dart';
import '../../data/providers.dart';
import '../../domain/entities/recording.dart';
import '../../domain/entities/assigned_user.dart';
import '../../services/auth_session.dart';
import '../../app/providers.dart';
import '../../services/dio_error_mapper.dart';
import '../transcript/transcript_editor.dart';
import 'assignment_controller.dart';
import 'recording_detail_controller.dart';
import 'status_controller.dart';
import 'recordings_controller.dart';

class RecordingDetailScreen extends ConsumerStatefulWidget {
  const RecordingDetailScreen({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<RecordingDetailScreen> createState() =>
      _RecordingDetailScreenState();
}

final assignedUsersProvider =
    FutureProvider.family<List<AssignedUser>, String>((ref, recordingId) {
  return ref.read(assignmentRepositoryProvider).getAssignedUsers(recordingId);
});

class _RecordingDetailScreenState
    extends ConsumerState<RecordingDetailScreen> {
  bool _transcriptExpanded = false;
  Timer? _statusTimer;
  Map<String, dynamic>? _transcriptionStatus;
  String? _loadedRecordingId;

  @override
  void initState() {
    super.initState();
    ref.read(recordingDetailProvider(widget.recordingId).future).then((recording) {
      ref
          .read(audioPlayerControllerProvider.notifier)
          .loadRecording(recording.audioPath);
    });
  }

  @override
  void dispose() {
    print('[RecordingDetailScreen] dispose id=${widget.recordingId}');
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingAsync = ref.watch(recordingDetailProvider(widget.recordingId));
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playerController = ref.read(audioPlayerControllerProvider.notifier);
    final assignmentState = ref.watch(assignmentControllerProvider);
    final statusState = ref.watch(statusControllerProvider);
    final currentUserId = ref.watch(authSessionProvider).user?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF115343),
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            ref.invalidate(audioPlayerControllerProvider);
            ref.read(recordingsControllerProvider.notifier).loadInitial();
            context.go('/recordings');
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Recordings',
        ),
        title: Text(
          'Recording Player',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
        ),
        actions: const [],
      ),
      body: recordingAsync.when(
        data: (recording) {
          if (_loadedRecordingId != recording.id) {
            _loadedRecordingId = recording.id;
            _loadTranscriptionStatus(recording.id, poll: true);
          }
          final assignedUsersAsync =
              ref.watch(assignedUsersProvider(recording.id));
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (!_transcriptExpanded)
                            Expanded(
                              flex: 4,
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
                                          onPressed: () => _downloadAudio(recording),
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
                                              child: _AnnotationsList(
                                                annotations: recording.annotations,
                                                onSeek: (position) =>
                                                    playerController.seek(position),
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
                            flex: _transcriptExpanded ? 1 : 6,
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
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF115343),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => ref
                                      .read(transcriptControllerProvider.notifier)
                                      .save(),
                                  icon: const Icon(Icons.save, size: 14),
                                  label: const Text('Save'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _exportTranscript(recording),
                                  icon: const Icon(Icons.file_upload, size: 14),
                                  label: const Text('Export'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setState(
                                      () => _transcriptExpanded = !_transcriptExpanded),
                                  icon: const Icon(Icons.expand, size: 14),
                                  label: Text(
                                    _transcriptExpanded
                                        ? 'Default View'
                                        : 'Expand Editor',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(transcriptControllerProvider.notifier)
                                      .retranscribe(),
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Retranscribe'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: DropdownButtonFormField<String>(
                                    value: _normalizeStatus(recording.status),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
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
                                            child: Text(status, style: TextStyle(fontSize: 12)),
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
                                assignedUsersAsync.when(
                                  data: (assignedUsers) {
                                    final isAssignedToMe = currentUserId != null &&
                                        assignedUsers.any(
                                          (user) => user.userId == currentUserId,
                                        );
                                    return OutlinedButton.icon(
                                      onPressed: assignmentState.isLoading
                                          ? null
                                          : () async {
                                              if (currentUserId == null || currentUserId.isEmpty) {
                                                return;
                                              }
                                              print('[RecordingDetailScreen] ${isAssignedToMe ? "Removing from" : "Adding to"} My List');
                                              if (isAssignedToMe) {
                                                // Call API directly - no caching
                                                await ref
                                                    .read(assignmentRepositoryProvider)
                                                    .unassignRecording(recording.id, userId: currentUserId);
                                              } else {
                                                // Call API directly - no caching
                                                await ref
                                                    .read(assignmentRepositoryProvider)
                                                    .assignRecording(recording.id, userId: currentUserId);
                                              }
                                              print('[RecordingDetailScreen] API call completed, refreshing...');
                                              // Refresh the assigned users and recordings list
                                              ref.invalidate(assignedUsersProvider(recording.id));
                                              await ref.read(recordingsControllerProvider.notifier).loadInitial();
                                              print('[RecordingDetailScreen] Refresh completed');
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(isAssignedToMe
                                                      ? 'Removed from My List'
                                                      : 'Added to My List'),
                                                ),
                                              );
                                            },
                                      icon: Icon(
                                        isAssignedToMe
                                            ? Icons.remove_circle_outline
                                            : Icons.playlist_add,
                                        size: 14,
                                      ),
                                      label: Text(
                                        isAssignedToMe
                                            ? 'Remove from My List'
                                            : 'Add to My List',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                  loading: () => OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.playlist_add, size: 14),
                                    label: const Text('My List'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  error: (_, __) {
                                    final userId = currentUserId;
                                    return OutlinedButton.icon(
                                      onPressed: assignmentState.isLoading || userId == null
                                          ? null
                                          : () async {
                                              print('[RecordingDetailScreen] My List button (error state)');
                                              if (assignmentState.assignment == null) {
                                                await ref
                                                    .read(assignmentRepositoryProvider)
                                                    .assignRecording(recording.id, userId: userId);
                                              } else {
                                                await ref
                                                    .read(assignmentRepositoryProvider)
                                                    .unassignRecording(recording.id, userId: userId);
                                              }
                                              ref.invalidate(assignedUsersProvider(recording.id));
                                              await ref.read(recordingsControllerProvider.notifier).loadInitial();
                                            },
                                      icon: const Icon(Icons.playlist_add, size: 14),
                                      label: Text(
                                        assignmentState.assignment == null
                                            ? 'Add to My List'
                                            : 'Remove from My List',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => ref
                                      .refresh(recordingDetailProvider(widget.recordingId)),
                                  icon: const Icon(Icons.sync, size: 14),
                                  label: const Text('Refresh'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (statusState.isLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _TranscriptionStatusPanel(status: _transcriptionStatus),
                            const SizedBox(height: 8),
                            assignedUsersAsync.when(
                              data: (assignedUsers) {
                                final isAssignedToMe = currentUserId != null &&
                                    assignedUsers.any(
                                      (user) => user.userId == currentUserId,
                                    );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _AssignmentStatusIndicator(
                                      isAssigned: isAssignedToMe,
                                    ),
                                    if (assignedUsers.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: assignedUsers
                                            .map(
                                              (user) => Chip(
                                                label: Text(
                                                  user.name.isNotEmpty
                                                      ? user.name
                                                      : user.email,
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                );
                              },
                              loading: () => _AssignmentStatusIndicator(
                                isAssigned: assignmentState.assignment != null,
                              ),
                              error: (_, __) => _AssignmentStatusIndicator(
                                isAssigned: assignmentState.assignment != null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TranscriptEditor(recordingId: recording.id),
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
              Positioned(
                right: 20,
                bottom: 20,
                child: CommentsPanel(recordingId: recording.id),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mapDioError(error),
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(
                  recordingDetailProvider(widget.recordingId),
                ),
                icon: const Icon(Icons.refresh),
                label: Text('Retry', style: GoogleFonts.roboto()),
              ),
            ],
          ),
        ),
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

  Future<void> _loadTranscriptionStatus(
    String recordingId, {
    bool poll = false,
  }) async {
    _statusTimer?.cancel();
    try {
      final client = ref.read(apiClientProvider).dio;
      final response =
          await client.get<Map<String, dynamic>>('/case_recordings/$recordingId/transcription_status');
      setState(() {
        _transcriptionStatus = response.data;
      });
      final state = (response.data?['transcription_state'] ?? 'none')
          .toString()
          .toLowerCase();
      if (poll && (state == 'queued' || state == 'processing')) {
        _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _loadTranscriptionStatus(recordingId);
        });
      }
    } catch (error) {
      setState(() {
        _transcriptionStatus = {'transcription_state': 'none'};
      });
    }
  }

  Future<void> _downloadAudio(Recording recording) async {
    try {
      final config = ref.read(appConfigProvider);
      final uri = _buildAudioUri(
        baseUrl: config.audioBaseUrl,
        audioPath: recording.audioPath,
      );
      if (uri == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio URL is empty')),
          );
        }
        return;
      }

      final filename =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'audio';
      final location = await getSaveLocation(suggestedName: filename);
      if (location == null) return;

      final dio = ref.read(apiClientProvider).dio;
      await dio.downloadUri(uri, location.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio saved to ${location.path}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download audio: $error')),
        );
      }
    }
  }

  Uri? _buildAudioUri({
    required String baseUrl,
    required String audioPath,
  }) {
    final trimmed = audioPath.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }

    var normalized = trimmed.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final recordingsIndex = normalized.indexOf('recordings/');
    if (recordingsIndex >= 0) {
      normalized = normalized.substring(recordingsIndex + 'recordings/'.length);
    } else if (normalized.contains('media/recordings/')) {
      normalized = normalized.split('media/recordings/').last;
    }

    final filename = normalized.split('/').last;
    final base = Uri.parse(baseUrl);
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'recordings',
        filename,
      ],
    );
  }

  Future<void> _exportTranscript(Recording recording) async {
    final state = ref.read(transcriptControllerProvider);
    final parchmentDelta = state.controller.document.toDelta();
    final transcriptHtml = dq.Delta.fromJson(parchmentDelta.toJson()).toHtml();

    final caseNumber = recording.caseNumber.isNotEmpty
        ? recording.caseNumber
        : 'unknown_case';
    final title = recording.title.isNotEmpty ? recording.title : 'Untitled';
    final judge = recording.judgeName.isNotEmpty ? recording.judgeName : 'N/A';
    final dateStamp = recording.date.toIso8601String();
    final prosecution = recording.prosecutionCounsel.isNotEmpty
        ? recording.prosecutionCounsel
        : 'N/A';
    final defense = recording.defenseCounsel.isNotEmpty
        ? recording.defenseCounsel
        : 'N/A';

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Court Transcript - $caseNumber</title>
</head>
<body>
  <h1>Court Transcript: $title ($caseNumber)</h1>
  <div>
    <p><strong>Judge:</strong> $judge</p>
    <p><strong>Date:</strong> $dateStamp</p>
    <p><strong>Prosecution Counsel:</strong> $prosecution</p>
    <p><strong>Defense Counsel:</strong> $defense</p>
  </div>
  <hr>
  $transcriptHtml
</body>
</html>
''';

    final location = await getSaveLocation(
      suggestedName: 'transcript_$caseNumber.doc',
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Word',
          extensions: ['doc'],
        ),
      ],
    );
    if (location == null) return;
    await File(location.path).writeAsString(html);
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

class _TranscriptionStatusPanel extends StatelessWidget {
  const _TranscriptionStatusPanel({required this.status});

  final Map<String, dynamic>? status;

  @override
  Widget build(BuildContext context) {
    final state = (status?['transcription_state'] ?? 'none')
        .toString()
        .toLowerCase();
    final activeJobs = status?['active_jobs'] as List<dynamic>? ?? [];
    final lastTranscribedAt = status?['last_transcribed_at'];

    String label = 'No Transcription';
    String details = 'No transcription job has been created.';
    IconData icon = Icons.circle;
    Color color = Colors.grey;

    if (state == 'queued') {
      label = 'Transcription Queued';
      final job = activeJobs.isNotEmpty ? activeJobs.first : null;
      final queuePos = job is Map ? job['queue_position'] : null;
      details = queuePos == null ? 'Waiting in queue...' : 'Position $queuePos in queue';
      icon = Icons.access_time;
      color = Colors.orange;
    } else if (state == 'processing') {
      label = 'Transcription Processing';
      details = 'Processing audio...';
      icon = Icons.sync;
      color = Colors.blue;
    } else if (state == 'completed') {
      label = 'Transcription Completed';
      details = lastTranscribedAt == null
          ? 'Transcription is ready'
          : 'Completed $lastTranscribedAt';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (state == 'failed') {
      label = 'Transcription Failed';
      details = 'Transcription job failed.';
      icon = Icons.error;
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                ),
                Text(
                  details,
                  style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.toUpperCase(),
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentStatusIndicator extends StatelessWidget {
  const _AssignmentStatusIndicator({required this.isAssigned});

  final bool isAssigned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssigned ? const Color(0xFFD4EDDA) : const Color(0xFFF8D7DA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssigned ? const Color(0xFFC3E6CB) : const Color(0xFFF5C6CB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info,
            color: isAssigned ? const Color(0xFF155724) : const Color(0xFF721C24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAssigned
                  ? 'You are assigned to this recording. You can edit the transcript.'
                  : 'You are not assigned to this recording. You can only add comments.',
              style: GoogleFonts.roboto(
                color: isAssigned ? const Color(0xFF155724) : const Color(0xFF721C24),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnotationsList extends StatelessWidget {
  const _AnnotationsList({
    required this.annotations,
    required this.onSeek,
  });

  final List<Map<String, dynamic>> annotations;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return Center(
        child: Text(
          'No annotations available',
          style: GoogleFonts.roboto(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      itemCount: annotations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final annotation = annotations[index];
        final rawTimestamp = annotation['timestamp'] ??
            annotation['time_stamp'] ??
            annotation['time'] ??
            'N/A';
        final details = annotation['details'] ??
            annotation['text'] ??
            annotation['content'] ??
            annotation['note'] ??
            '';
        final displayTimestamp = _formatAnnotationTimestamp(rawTimestamp);

        return ListTile(
          dense: true,
          title: Text(
            displayTimestamp,
            style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            details.toString(),
            style: GoogleFonts.roboto(fontSize: 12),
          ),
          onTap: () {
            final seconds = _parseTimestampToSeconds(rawTimestamp);
            if (seconds != null) {
              onSeek(Duration(milliseconds: (seconds * 1000).round()));
            }
          },
        );
      },
    );
  }

  String _formatAnnotationTimestamp(dynamic value) {
    final seconds = _parseTimestampToSeconds(value);
    if (seconds == null) return 'N/A';
    final duration = Duration(milliseconds: (seconds * 1000).round());
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(duration.inHours);
    final minutes = two(duration.inMinutes.remainder(60));
    final secs = two(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secs';
  }

  double? _parseTimestampToSeconds(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final seconds = value.toDouble();
      if (seconds > 3600 * 1000) {
        return seconds / 1000;
      }
      return seconds;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'N/A') return null;
      if (trimmed.contains(':')) {
        final parts = trimmed.split(':').map((e) => double.tryParse(e) ?? 0).toList();
        if (parts.length == 3) {
          return parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
        if (parts.length == 2) {
          return parts[0] * 60 + parts[1];
        }
        if (parts.length == 1) {
          return parts[0];
        }
      }
      final asNum = double.tryParse(trimmed);
      if (asNum == null) return null;
      return asNum > 3600 * 1000 ? asNum / 1000 : asNum;
    }
    return null;
  }
}
