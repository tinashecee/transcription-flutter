import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_selector/file_selector.dart';

import '../comments/comments_panel.dart';
import '../player/audio_player_controller.dart';
import '../player/waveform_scrubber.dart';
import '../transcript/transcript_controller.dart';
import '../widgets/collapsible_sidebar.dart';
import '../../data/providers.dart';
import '../../domain/repositories/recording_repository.dart';
import '../../domain/entities/recording.dart';
import '../../domain/entities/assigned_user.dart';
import '../../services/auth_session.dart';
import '../../app/providers.dart';
import '../../services/dio_error_mapper.dart';
import '../../services/update_manager.dart';
import '../transcript/transcript_editor.dart';
import 'assignment_controller.dart';
import 'recording_detail_controller.dart';
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
  String? _lastKnownState;
  int _pollErrorCount = 0;
  static const int _maxPollErrors = 3;

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

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? 'hr' : 'hrs'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      } else {
        final month = dateTime.month.toString().padLeft(2, '0');
        final day = dateTime.day.toString().padLeft(2, '0');
        return '$month/$day';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingAsync = ref.watch(recordingDetailProvider(widget.recordingId));
    final playerState = ref.watch(audioPlayerControllerProvider);
    final playerController = ref.read(audioPlayerControllerProvider.notifier);
    final assignmentState = ref.watch(assignmentControllerProvider);
    final currentUserId = ref.watch(authSessionProvider).user?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: recordingAsync.when(
        data: (recording) {
          if (_loadedRecordingId != recording.id) {
            _loadedRecordingId = recording.id;
            _loadTranscriptionStatus(recording.id, poll: true);
          }
          final assignedUsersAsync =
              ref.watch(assignedUsersProvider(recording.id));
          
          // Determine if current user is assigned (for controlling edit permissions)
          final isAssignedToMe = assignedUsersAsync.whenOrNull(
            data: (users) {
              final assigned = currentUserId != null &&
                  users.any((user) => user.userId == currentUserId);
              print('[RecordingDetail] isAssignedToMe check: currentUserId=$currentUserId users=${users.map((u) => u.userId).toList()} result=$assigned');
              return assigned;
            },
          ) ?? false;
          
          print('[RecordingDetail] Final isAssignedToMe=$isAssignedToMe (loading=${assignedUsersAsync.isLoading})');
          
          return Stack(
            fit: StackFit.expand,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Collapsible sidebar for court filtering
                  if (!_transcriptExpanded)
                    CollapsibleSidebar(
                      initiallyCollapsed: true,
                      selectedCourt: null,
                      selectedCourtroom: null,
                      onCourtSelected: (court) {
                        // Update controller state explicitly before navigating
                        ref.read(recordingsControllerProvider.notifier).updateFilters(
                              RecordingFilters(
                                tab: RecordingTab.all,
                                court: court,
                              ),
                            );

                        // Navigate back to recordings with filter
                        if (court != null) {
                          context.go('/recordings?court=$court');
                        } else {
                          context.go('/recordings');
                        }
                      },
                      onCourtroomSelected: (_) {},
                    ),
                  // Main content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back Button
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                // Reset to "All Recordings" before navigating back
                                ref.read(recordingsControllerProvider.notifier).updateFilters(
                                      const RecordingFilters(tab: RecordingTab.all),
                                    );
                                context.go('/recordings');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF115343)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Back to Dashboard',
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF115343),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                          if (!_transcriptExpanded)
                            Expanded(
                              flex: 3,
                              child: Hero(
                                tag: widget.recordingId,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Recording Title + Play Button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Recording',
                                            style: GoogleFonts.roboto(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF111827), // Dark grey/black
                                            ),
                                          ),
                                          // Play button moved to controls row below
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        recording.title,
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      // Waveform with side timestamps
                                      Row(
                                        children: [
                                          Text(
                                            _formatTimestamp(playerState.position),
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SizedBox(
                                              height: 48,
                                              child: WaveformScrubber(
                                                position: playerState.position,
                                                duration: playerState.duration,
                                                onSeek: playerController.seek,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '-${_formatTimestamp(playerState.duration - playerState.position)}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      // Playback Controls (Rewind - Play/Pause - Forward)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.replay_10, size: 24),
                                            onPressed: playerController.rewind,
                                            color: Colors.grey[700],
                                            tooltip: 'Rewind 10s',
                                          ),
                                          const SizedBox(width: 24),
                                          // Central Play/Pause Button
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF115343),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF115343).withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                                                size: 32,
                                                color: Colors.white,
                                              ),
                                              onPressed: playerController.playPause,
                                              tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          IconButton(
                                            icon: const Icon(Icons.forward_10, size: 24),
                                            onPressed: playerController.forward,
                                            color: Colors.grey[700],
                                            tooltip: 'Forward 10s',
                                          ),
                                        ],
                                      ),
                                      
                                      // Speed & Download Row - Compact
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.speed, size: 16, color: Color(0xFF115343)),
                                                  const SizedBox(width: 4),
                                                  DropdownButton<double>(
                                                    value: playerState.speed,
                                                    underline: const SizedBox(),
                                                    isDense: true,
                                                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.black87),
                                                    items: const [0.5, 1.0, 1.5, 2.0]
                                                        .map((speed) => DropdownMenuItem(
                                                              value: speed,
                                                              child: Text('${speed}x'),
                                                            ))
                                                        .toList(),
                                                    onChanged: (value) {
                                                      if (value != null) playerController.setSpeed(value);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.download, size: 20),
                                              onPressed: () => _downloadAudio(recording),
                                              tooltip: 'Download',
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 24),
                                      
                                      // Annotations - Integrated & Readable
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F9FA),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xFF115343).withOpacity(0.08),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.bookmark, size: 18, color: Color(0xFF115343)),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Annotations',
                                                      style: GoogleFonts.roboto(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF115343),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF115343).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Text(
                                                        '${recording.annotations.length}',
                                                        style: GoogleFonts.roboto(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF115343),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Expanded(
                                                child: _AnnotationsList(
                                                  annotations: recording.annotations,
                                                  onSeek: (position) => playerController.seek(position),
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
                            ),
                          if (!_transcriptExpanded) const SizedBox(width: 20),
                          Expanded(
                            flex: _transcriptExpanded ? 1 : 7,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title Row with expand/menu controls
                                  Row(
                                    children: [
                                      Text(
                                        'Transcript',
                                        style: GoogleFonts.roboto(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF115343),
                                        ),
                                      ),
                                      if (_transcriptionStatus != null && _transcriptionStatus!['status'] == 'completed') ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Completed ${_formatTimeAgo(_transcriptionStatus!['completed_at'])}',
                                            style: GoogleFonts.roboto(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => setState(() => _transcriptExpanded = !_transcriptExpanded),
                                        icon: Icon(_transcriptExpanded ? Icons.fullscreen_exit : Icons.fullscreen),
                                        tooltip: _transcriptExpanded ? 'Collapse' : 'Expand Editor',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      MenuAnchor(
                                        builder: (context, controller, child) => IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          onPressed: () {
                                            if (controller.isOpen) {
                                              controller.close();
                                            } else {
                                              controller.open();
                                            }
                                          },
                                          tooltip: 'More Actions',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        menuChildren: [
                                          MenuItemButton(
                                            leadingIcon: const Icon(Icons.check_circle_outline, size: 18),
                                            onPressed: isAssignedToMe ? () async {
                                              await ref.read(transcriptControllerProvider.notifier).save();
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Transcript saved successfully')),
                                                );
                                              }
                                            } : null,
                                            child: const Text('Save Changes'),
                                          ),
                                          MenuItemButton(
                                            leadingIcon: const Icon(Icons.file_download_outlined, size: 18),
                                            onPressed: () => _exportTranscript(recording),
                                            child: const Text('Export to DOCX'),
                                          ),
                                          if (isAssignedToMe)
                                            MenuItemButton(
                                              leadingIcon: const Icon(Icons.history, size: 18),
                                              onPressed: () => _handleRetranscribe(context, recording),
                                              child: const Text('Retranscribe'),
                                            ),
                                          MenuItemButton(
                                            leadingIcon: const Icon(Icons.sync, size: 18),
                                            onPressed: () => ref.refresh(recordingDetailProvider(widget.recordingId)),
                                            child: const Text('Refresh Data'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Centered Action Buttons Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _StatusDropdown(
                                        recordingId: recording.id,
                                        currentStatus: recording.status,
                                        isEnabled: isAssignedToMe,
                                      ),
                                      const SizedBox(width: 12),
                                      _MyListButton(
                                        recordingId: recording.id,
                                        currentUserId: currentUserId,
                                        assignedUsersAsync: assignedUsersAsync,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: TranscriptEditor(
                                      recordingId: recording.id,
                                      isAssigned: isAssignedToMe,
                                    ),
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
            ),
          ],
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


  Future<void> _loadTranscriptionStatus(
    String recordingId, {
    bool poll = false,
  }) async {
    _statusTimer?.cancel();
    try {
      final client = ref.read(apiClientProvider).dio;
      final response =
          await client.get<Map<String, dynamic>>('/case_recordings/$recordingId/transcription_status');
      
      final currentState = (response.data?['transcription_state'] ?? 'none')
          .toString()
          .toLowerCase();
      
      // Detect state changes
      final stateChanged = _lastKnownState != null && _lastKnownState != currentState;
      final justCompleted = stateChanged && 
                           currentState == 'completed' && 
                           (_lastKnownState == 'processing' || _lastKnownState == 'queued');
      
      print('[TranscriptionStatus] State: $currentState (was: $_lastKnownState, changed: $stateChanged, justCompleted: $justCompleted)');
      
      setState(() {
        _transcriptionStatus = response.data;
        _lastKnownState = currentState;
      });
      
      // Reset error count on success
      _pollErrorCount = 0;
      
      // If job just completed, auto-refresh transcript
      if (justCompleted && mounted) {
        print('[TranscriptionStatus] Job completed! Refreshing transcript in 1.5 seconds...');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            print('[TranscriptionStatus] Reloading transcript...');
            ref.read(transcriptControllerProvider.notifier).load(recordingId);
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transcription completed! Transcript has been updated.'),
                backgroundColor: Color(0xFF4CAF50),
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
      
      // Start/continue polling for active jobs
      if (poll && (currentState == 'queued' || currentState == 'processing')) {
        print('[TranscriptionStatus] Starting polling (state: $currentState)');
        _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _loadTranscriptionStatus(recordingId);
        });
      } else {
        // Stop polling when done
        print('[TranscriptionStatus] Stopping polling (state: $currentState)');
      }
      
    } catch (error) {
      print('[TranscriptionStatus] Error loading status: $error');
      _pollErrorCount++;
      
      setState(() {
        _transcriptionStatus = {'transcription_state': 'none'};
      });
      
      // Stop polling after max errors
      if (_pollErrorCount >= _maxPollErrors) {
        print('[TranscriptionStatus] Max errors reached ($_maxPollErrors), stopping poll');
        _statusTimer?.cancel();
        _pollErrorCount = 0;
      }
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
    try {
      print('[Export] Starting export for recording ${recording.id}');
      
      // Get transcript content
      final state = ref.read(transcriptControllerProvider);
      final delta = state.controller.document.toDelta();
      print('[Export] Got transcript delta: ${delta.length} operations');
      
      // Convert delta to HTML
      final transcriptHtml = _deltaToHtml(delta);
      print('[Export] Converted to HTML: ${transcriptHtml.length} chars');

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
  <style>
    body { font-family: 'Times New Roman', serif; margin: 40px; line-height: 1.6; }
    h1 { color: #115343; border-bottom: 2px solid #115343; padding-bottom: 10px; }
    .metadata { background: #f5f5f5; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
    .metadata p { margin: 5px 0; }
    hr { border: none; border-top: 1px solid #ccc; margin: 20px 0; }
  </style>
</head>
<body>
  <h1>Court Transcript: $title ($caseNumber)</h1>
  <div class="metadata">
    <p><strong>Judge:</strong> $judge</p>
    <p><strong>Date:</strong> $dateStamp</p>
    <p><strong>Prosecution Counsel:</strong> $prosecution</p>
    <p><strong>Defense Counsel:</strong> $defense</p>
  </div>
  <hr>
  <div class="transcript">
    $transcriptHtml
  </div>
</body>
</html>
''';

      print('[Export] Opening save dialog...');
      
      // Open save dialog
      final location = await getSaveLocation(
        suggestedName: 'transcript_$caseNumber.doc',
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Word Document',
            extensions: ['doc', 'html'],
          ),
        ],
      );
      
      if (location == null) {
        print('[Export] User cancelled save dialog');
        return;
      }
      
      print('[Export] Saving to: ${location.path}');
      
      // Write file
      await File(location.path).writeAsString(html);
      
      print('[Export] File saved successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcript exported to ${location.path}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e, stack) {
      print('[Export] Error: $e');
      print('[Export] Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  String _deltaToHtml(dynamic delta) {
    final buffer = StringBuffer();
    
    final ops = delta.toList();
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final data = op.data;
      
      if (data is! String) continue;

      final attributes = op.attributes ?? {};
      final text = data.toString();

      // Check if this is a newline with block attributes
      if (text == '\n') {
        if (i > 0) {
          buffer.write('</p>\n');
        }
        if (i < ops.length - 1) {
          final header = attributes['header'];
          if (header != null) {
            buffer.write('<h$header>');
          } else {
            buffer.write('<p>');
          }
        }
        continue;
      }

      // Start paragraph if needed
      if (i == 0 || (i > 0 && ops[i - 1].data == '\n')) {
        final header = attributes['header'];
        if (header != null) {
          buffer.write('<h$header>');
        } else {
          buffer.write('<p>');
        }
      }

      // Apply inline formatting
      var formattedText = _escapeHtml(text);
      
      if (attributes['bold'] == true) {
        formattedText = '<strong>$formattedText</strong>';
      }
      if (attributes['italic'] == true) {
        formattedText = '<em>$formattedText</em>';
      }
      if (attributes['underline'] == true) {
        formattedText = '<u>$formattedText</u>';
      }
      if (attributes['strike'] == true) {
        formattedText = '<s>$formattedText</s>';
      }
      final link = attributes['link'];
      if (link != null) {
        formattedText = '<a href="$link">$formattedText</a>';
      }

      buffer.write(formattedText);
    }

    if (buffer.isEmpty) {
      return '<p>No transcript available.</p>';
    }

    buffer.write('</p>\n');
    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<void> _handleRetranscribe(BuildContext context, Recording recording) async {
    // Step 1: Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Confirm Retranscribe'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will re-run transcription and overwrite the currently saved transcript.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to continue?',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Retranscribe'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Step 2: Get user ID
    final authState = ref.read(authSessionProvider);
    final userId = authState.user?.id;
    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to determine user ID'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Step 3: Show loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Queueing transcription job...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );
    }

    // Step 4: Call retranscribe
    print('[RecordingDetail] Calling retranscribe with userId=$userId recordingId=${recording.id}');
    
    Map<String, dynamic> response;
    try {
      response = await ref
          .read(transcriptControllerProvider.notifier)
          .retranscribe(userId);
      print('[RecordingDetail] Retranscribe response: $response');
    } catch (error, stack) {
      print('[RecordingDetail] Retranscribe error: $error');
      print('[RecordingDetail] Stack: $stack');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Step 5: Handle response
    ScaffoldMessenger.of(context).clearSnackBars();

    if (response.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? response['error']),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    } else if (response['already_exists'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ?? 'A transcription job already exists for this recording.',
          ),
          backgroundColor: Colors.blue.shade700,
        ),
      );
    } else {
      final queuePos = response['queue_position'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job Queued Successfully!\n${queuePos != null ? 'Position in queue: $queuePos' : 'The transcript will update automatically when processing completes.'}',
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Reload transcription status to show the queued job
      print('[RecordingDetail] Reloading transcription status after job queued');
      _loadTranscriptionStatus(recording.id, poll: true);
    }
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: annotations.length,
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final seconds = _parseTimestampToSeconds(rawTimestamp);
                if (seconds != null) {
                  onSeek(Duration(milliseconds: (seconds * 1000).round()));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF115343).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayTimestamp,
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF115343),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        details.toString(),
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: const Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.play_circle_outline,
                      size: 18,
                      color: const Color(0xFF115343).withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

/// Separate stateful widget for My List button to properly handle loading state
class _MyListButton extends ConsumerStatefulWidget {
  const _MyListButton({
    required this.recordingId,
    required this.currentUserId,
    required this.assignedUsersAsync,
  });

  final String recordingId;
  final String? currentUserId;
  final AsyncValue<List<AssignedUser>> assignedUsersAsync;

  @override
  ConsumerState<_MyListButton> createState() => _MyListButtonState();
}

class _MyListButtonState extends ConsumerState<_MyListButton> {
  bool _isOperationInProgress = false;

  Future<void> _handleMyListAction(bool isCurrentlyAssigned) async {
    if (_isOperationInProgress) return;
    if (widget.currentUserId == null || widget.currentUserId!.isEmpty) return;

    setState(() => _isOperationInProgress = true);

    try {
      // Step 1: Call API and wait for response
      if (isCurrentlyAssigned) {
        print('[RecordingDetailScreen] DELETE unassign case_id=${widget.recordingId} user_id=${widget.currentUserId}');
        await ref.read(assignmentRepositoryProvider).unassignRecording(
          widget.recordingId,
          userId: widget.currentUserId!,
        );
      } else {
        print('[RecordingDetailScreen] POST assign case_id=${widget.recordingId} user_id=${widget.currentUserId}');
        await ref.read(assignmentRepositoryProvider).assignRecording(
          widget.recordingId,
          userId: widget.currentUserId!,
        );
      }
      print('[RecordingDetailScreen] API returned success');

      // Step 2: Clear state and reload fresh from API
      print('[RecordingDetailScreen] Clearing state and reloading from API...');
      ref.invalidate(assignedUsersProvider(widget.recordingId));
      await ref.read(recordingsControllerProvider.notifier).loadInitial();
      print('[RecordingDetailScreen] Reload from API completed');
      
      // No snackbar - UI will update because we reloaded
    } catch (e) {
      print('[RecordingDetailScreen] API error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOperationInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.assignedUsersAsync.when(
      data: (assignedUsers) {
        final isAssignedToMe = widget.currentUserId != null &&
            assignedUsers.any((user) => user.userId == widget.currentUserId);
        
        // Use green for "Add" action, amber/orange for "Remove" (already assigned)
        final buttonColor = isAssignedToMe 
            ? const Color(0xFFFF9800) // Orange for assigned state
            : const Color(0xFF115343); // Green for add action
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isOperationInProgress 
                ? null 
                : () => _handleMyListAction(isAssignedToMe),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isOperationInProgress
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [buttonColor, buttonColor.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isOperationInProgress)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      isAssignedToMe ? Icons.remove_circle_outline : Icons.playlist_add,
                      size: 16,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isOperationInProgress
                        ? (isAssignedToMe ? 'Removing...' : 'Adding...')
                        : (isAssignedToMe ? 'Remove from List' : 'Add to My List'),
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading...',
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.currentUserId == null
              ? null
              : () => _handleMyListAction(false),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF115343), Color(0xFF0D3F33)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF115343).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.playlist_add, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Add to My List',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status dropdown with pill styling - handles API call, wait, reload
class _StatusDropdown extends ConsumerStatefulWidget {
  const _StatusDropdown({
    required this.recordingId,
    required this.currentStatus,
    this.isEnabled = true,
  });

  final String recordingId;
  final String currentStatus;
  final bool isEnabled;

  @override
  ConsumerState<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends ConsumerState<_StatusDropdown> {
  bool _isUpdating = false;
  late String _selectedStatus;

  // Valid statuses for the Flask API
  static const _validStatuses = ['pending', 'inprogress', 'completed'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = _normalizeStatus(widget.currentStatus);
  }

  @override
  void didUpdateWidget(covariant _StatusDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus) {
      _selectedStatus = _normalizeStatus(widget.currentStatus);
    }
  }

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase().replaceAll('_', '').replaceAll('-', '');
    if (value.isEmpty) return 'pending';
    switch (value) {
      case 'pending':
      case 'pendingtranscription':
        return 'pending';
      case 'inprogress':
      case 'processing':
        return 'inprogress';
      case 'completed':
      case 'reviewed':
        return 'completed';
      default:
        return 'pending';
    }
  }

  String _displayStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'inprogress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800); // Orange
      case 'inprogress':
        return const Color(0xFF2196F3); // Blue
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  Future<void> _handleStatusChange(String newStatus) async {
    if (_isUpdating || newStatus == _selectedStatus) return;

    setState(() => _isUpdating = true);

    try {
      // Step 1: Call API and wait for response
      print('[StatusDropdown] PUT /case_recordings/${widget.recordingId}/update_status status=$newStatus');
      await ref.read(statusRepositoryProvider).updateStatus(
        recordingId: widget.recordingId,
        status: newStatus,
      );
      print('[StatusDropdown] API returned success');

      // Step 2: Clear state and reload fresh from API
      print('[StatusDropdown] Refreshing recording detail...');
      ref.invalidate(recordingDetailProvider(widget.recordingId));
      await ref.read(recordingsControllerProvider.notifier).loadInitial();
      print('[StatusDropdown] Reload completed');

      // Update local state to reflect new status
      setState(() {
        _selectedStatus = newStatus;
      });
    } catch (e) {
      print('[StatusDropdown] API error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isEnabled 
        ? _getStatusColor(_selectedStatus)
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: _isUpdating
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updating...',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, color: statusColor, size: 20),
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: _validStatuses.map((status) {
                  final color = _getStatusColor(status);
                  return DropdownMenuItem(
                    value: status,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _displayStatus(status),
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return _validStatuses.map((status) {
                    final color = widget.isEnabled 
                        ? _getStatusColor(status)
                        : Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        _displayStatus(status),
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    );
                  }).toList();
                },
                onChanged: widget.isEnabled
                    ? (value) {
                        if (value != null) {
                          _handleStatusChange(value);
                        }
                      }
                    : null,
              ),
            ),
    );
  }
}


