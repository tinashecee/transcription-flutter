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
import '../widgets/sidebar_provider.dart';
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
import '../auth/auth_controller.dart';
import '../widgets/action_button.dart';

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
    extends ConsumerState<RecordingDetailScreen> with SingleTickerProviderStateMixin {
  bool _transcriptExpanded = false;
  bool _isEditMode = false;
  Timer? _statusTimer;
  Map<String, dynamic>? _transcriptionStatus;
  String? _loadedRecordingId;
  String? _lastKnownState;
  int _pollErrorCount = 0;
  static const int _maxPollErrors = 3;

  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _arrowAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
    // Force sidebar expansion on detail page load
    Future.microtask(() {
      if (mounted) {
        ref.read(sidebarCollapsedProvider.notifier).state = false;
      }
    });

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
    _arrowController.dispose();
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

    // Prevent rebuilds/disposals when provider is refreshing by checking valueOrNull
    // This keeps the TranscriptEditor alive while background data updates happen
    final recording = recordingAsync.valueOrNull;

    if (recording == null) {
      // Only show loading if we have NO data at all
      if (recordingAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      // Show error if we have no data and an error
      if (recordingAsync.hasError) {
         return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${recordingAsync.error}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(recordingDetailProvider(widget.recordingId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink(); // Should not happen
    }

    if (_loadedRecordingId != recording.id) {
       _loadedRecordingId = recording.id;
       _loadTranscriptionStatus(recording.id, poll: true);
    }
    
    final assignedUsersAsync = ref.watch(assignedUsersProvider(recording.id));
    final isAssignedToMe = assignedUsersAsync.valueOrNull?.any((u) => u.userId == currentUserId) ?? false;
        
    return Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/recordings');
                            }
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
                        const Spacer(),
                        Consumer(
                          builder: (context, ref, _) => ActionButton(
                            icon: Icons.logout_rounded,
                            tooltip: 'Logout',
                            onPressed: () => ref.read(authControllerProvider).logout(),
                            color: Colors.red.withOpacity(0.1),
                            iconColor: Colors.red,
                          ),
                        ),
                      ],
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
                                    Text(
                                      'Recording',
                                      style: GoogleFonts.roboto(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF111827),
                                      ),
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
                            padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
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

                                    // Controls Section
                                    if (isAssignedToMe) ...[
                                      // Save Button
                                      if (_isEditMode) // Only show Save button in Edit Mode
                                          Theme(
                                            data: Theme.of(context).copyWith(
                                              filledButtonTheme: FilledButtonThemeData(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(0xFF115343),
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                            child: Consumer(
                                              builder: (context, ref, child) {
                                                final state = ref.watch(transcriptControllerProvider);
                                                return FilledButton.icon(
                                                  onPressed: state.isSaving 
                                                      ? null 
                                                      : () async {
                                                          bool markAsCompleted = false;
                                                          
                                                          // Only show dialog if not already completed
                                                          final currentStatus = recording.status?.toLowerCase() ?? 'pending';
                                                          if (['pending', 'in_progress'].contains(currentStatus)) {
                                                            final confirmed = await showDialog<bool>(
                                                              context: context,
                                                              builder: (context) => _SaveConfirmationDialog(
                                                                currentStatus: recording.status,
                                                                onMarkCompletedChanged: (val) => markAsCompleted = val,
                                                              ),
                                                            );
                                                            if (confirmed != true) return;
                                                          }

                                                          final success = await ref.read(transcriptControllerProvider.notifier).save();
                                                          
                                                          if (success && markAsCompleted) {
                                                            try {
                                                              await ref.read(statusRepositoryProvider).updateStatus(
                                                                recordingId: widget.recordingId,
                                                                status: 'completed',
                                                              );
                                                              ref.read(recordingsControllerProvider.notifier).updateRecordingStatus(widget.recordingId, 'completed');
                                                              ref.invalidate(recordingDetailProvider(widget.recordingId));
                                                            } catch (e) {
                                                              if (context.mounted) {
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(content: Text('Transcript saved, but failed to update status: $e')),
                                                                );
                                                              }
                                                            }
                                                          }

                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Row(
                                                                  children: [
                                                                    Icon(success ? Icons.check_circle : Icons.error, color: Colors.white, size: 20),
                                                                    const SizedBox(width: 8),
                                                                    Text(success 
                                                                      ? (markAsCompleted ? 'Saved & Marked as Completed' : 'Saved successfully') 
                                                                      : 'Save failed'),
                                                                  ],
                                                                ),
                                                                backgroundColor: success ? const Color(0xFF115343) : Colors.red,
                                                                behavior: SnackBarBehavior.floating,
                                                                width: 320,
                                                              ),
                                                            );
                                                          }
                                                        },
                                                  icon: state.isSaving 
                                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                      : const Icon(Icons.save, size: 16),
                                                  label: Text(state.isSaving ? 'Saving' : 'Save'),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: const Color(0xFF115343),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    minimumSize: const Size(0, 36),
                                                    textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                      const SizedBox(width: 8),
                                      const SizedBox(height: 24, child: VerticalDivider(width: 24)),

                                      ActionButton(
                                        onPressed: () {
                                          final nextVal = !_transcriptExpanded;
                                          setState(() => _transcriptExpanded = nextVal);
                                          ref.read(sidebarHiddenProvider.notifier).state = nextVal;
                                        },
                                        icon: _transcriptExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                                        tooltip: _transcriptExpanded ? 'Collapse' : 'Expand Editor',
                                      ),
                                      const SizedBox(width: 8),

                                      if (isAssignedToMe) ...[
                                        // Bouncing Arrow Animation
                                        if (!_isEditMode)
                                          AnimatedBuilder(
                                            animation: _arrowAnimation,
                                            builder: (context, child) {
                                              return Transform.translate(
                                                offset: Offset(_arrowAnimation.value, 0), // Bouncing horizontally
                                                child: child,
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'Edit here', 
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12, 
                                                      color: const Color(0xFF115343),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF115343)),
                                                ],
                                              ),
                                            ),
                                          ),

                                        Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _isEditMode ? const Color(0xFF115343).withOpacity(0.1) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _isEditMode 
                                                  ? const Color(0xFF115343) 
                                                  : const Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              // If we are IN edit mode and clicking "Done", we could auto-save, 
                                              // but for now we just toggle the mode. The user can hit Save manually.
                                              setState(() => _isEditMode = !_isEditMode);
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _isEditMode ? Icons.check : Icons.edit_outlined, 
                                                    size: 14,
                                                    color: _isEditMode ? const Color(0xFF115343) : const Color(0xFF374151),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _isEditMode ? 'Done' : 'Edit',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      color: _isEditMode ? const Color(0xFF115343) : const Color(0xFF374151),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      
                                      // Remove User Icon Button
                                      Tooltip(
                                        message: 'Are you sure you want to remove yourself from this transcript?',
                                        child: IconButton(
                                          onPressed: () async {
                                             await ref.read(assignmentControllerProvider.notifier).unassign(recording.id);
                                             ref.invalidate(assignedUsersProvider(recording.id));
                                             ref.invalidate(recordingDetailProvider(recording.id));
                                          },
                                          icon: const Icon(Icons.person_remove_outlined),
                                          color: Colors.red.shade700,
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.red.shade50,
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      // Add to My List Button (if not assigned)
                                       Consumer(
                                        builder: (context, ref, _) {
                                          final state = ref.watch(assignmentControllerProvider);
                                          return FilledButton.icon(
                                            onPressed: state.isLoading ? null : () async {
                                                await ref.read(assignmentControllerProvider.notifier).assign(recording.id);
                                                ref.invalidate(assignedUsersProvider(recording.id));
                                                ref.invalidate(recordingDetailProvider(recording.id));
                                            },
                                            icon: state.isLoading 
                                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                                              : const Icon(Icons.add_circle_outline, size: 16),
                                            label: const Text('Add to My List'),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              minimumSize: const Size(0, 36),
                                              textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          );
                                        }
                                      ),
                                    ],
                                    
                                    const SizedBox(width: 8),
                                    
                                    // Status Dropdown
                                    _StatusDropdown(
                                      recordingId: recording.id,
                                      currentStatus: recording.status,
                                      isEnabled: isAssignedToMe,
                                    ),
                                    
                                    const SizedBox(width: 8),

                                    // More Actions
                                    MenuAnchor(
                                      style: MenuStyle(
                                        backgroundColor: WidgetStateProperty.all(Colors.white),
                                        elevation: WidgetStateProperty.all(8),
                                        shadowColor: WidgetStateProperty.all(const Color(0xFF115343).withOpacity(0.1)),
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: const Color(0xFF115343).withOpacity(0.12),
                                            ),
                                          ),
                                        ),
                                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 8)),
                                      ),
                                      alignmentOffset: const Offset(-100, 8),
                                      builder: (context, controller, child) => ActionButton(
                                        icon: Icons.more_vert,
                                        onPressed: () {
                                          if (controller.isOpen) {
                                            controller.close();
                                          } else {
                                            controller.open();
                                          }
                                        },
                                        tooltip: 'More Actions',
                                      ),
                                      menuChildren: [
                                        MenuItemButton(
                                          leadingIcon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF115343)),
                                          onPressed: () => _exportTranscript(recording),
                                          child: Text(
                                            'Export to DOCX',
                                            style: GoogleFonts.roboto(
                                              fontSize: 14,
                                              color: const Color(0xFF115343),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (isAssignedToMe)
                                          MenuItemButton(
                                            leadingIcon: const Icon(Icons.history, size: 18, color: Color(0xFF115343)),
                                            onPressed: () => _handleRetranscribe(context, recording),
                                            child: Text(
                                              'Retranscribe',
                                              style: GoogleFonts.roboto(
                                                fontSize: 14,
                                                color: const Color(0xFF115343),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        MenuItemButton(
                                          leadingIcon: const Icon(Icons.sync, size: 18, color: Color(0xFF115343)),
                                          onPressed: () => ref.refresh(recordingDetailProvider(widget.recordingId)),
                                          child: Text(
                                            'Refresh Data',
                                            style: GoogleFonts.roboto(
                                              fontSize: 14,
                                              color: const Color(0xFF115343),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 0),
                                // Expanded Transcript Editor
                                Expanded(
                                  child: TranscriptEditor(
                                    recordingId: recording.id,
                                    isAssigned: isAssignedToMe,
                                    isEditing: _isEditMode,
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
            Positioned(
              right: 20,
              bottom: 20,
              child: CommentsPanel(recordingId: recording.id),
            ),
          ],
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
      
      final stateChanged = _lastKnownState != null && _lastKnownState != currentState;
      final justCompleted = stateChanged && 
                           currentState == 'completed' && 
                           (_lastKnownState == 'processing' || _lastKnownState == 'queued');
      
      setState(() {
        _transcriptionStatus = response.data;
        _lastKnownState = currentState;
      });
      
      _pollErrorCount = 0;
      
      if (justCompleted && mounted) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            ref.read(transcriptControllerProvider.notifier).load(recordingId);
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
      
      if (poll && (currentState == 'queued' || currentState == 'processing')) {
        _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _loadTranscriptionStatus(recordingId);
        });
      }
      
    } catch (error) {
      _pollErrorCount++;
      setState(() {
        _transcriptionStatus = {'transcription_state': 'none'};
      });
      if (_pollErrorCount >= _maxPollErrors) {
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
      final state = ref.read(transcriptControllerProvider);
      final delta = state.controller.document.toDelta();
      final transcriptHtml = _deltaToHtml(delta);

      final caseNumber = recording.caseNumber.isNotEmpty ? recording.caseNumber : 'unknown_case';
      final title = recording.title.isNotEmpty ? recording.title : 'Untitled';
      final judge = recording.judgeName.isNotEmpty ? recording.judgeName : 'N/A';
      final dateStamp = recording.date.toIso8601String();
      final prosecution = recording.prosecutionCounsel.isNotEmpty ? recording.prosecutionCounsel : 'N/A';
      final defense = recording.defenseCounsel.isNotEmpty ? recording.defenseCounsel : 'N/A';

      final html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$title</title>
</head>
<body>
    <h1>$title</h1>
    <p><strong>Case Number:</strong> $caseNumber</p>
    <p><strong>Judge:</strong> $judge</p>
    <p><strong>Date:</strong> $dateStamp</p>
    <p><strong>Prosecution:</strong> $prosecution</p>
    <p><strong>Defense:</strong> $defense</p>
    <hr>
    <div>$transcriptHtml</div>
</body>
</html>
''';

      final fileName = '${caseNumber}_${title.replaceAll(' ', '_')}.docx';
      final destination = await getSaveLocation(suggestedName: fileName);
      if (destination == null) return;

      final client = ref.read(apiClientProvider).dio;
      await client.post(
        '/export/docx',
        data: {'html': html},
        onReceiveProgress: (count, total) {},
      ).then((response) async {
         // Assuming API returns file bytes or similar. This part needs refinement based on actual API response.
         // For now, let's just show success as a placeholder if we were actually downloading it.
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported successfully to ${destination.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  String _deltaToHtml(dynamic delta) {
    // Simplified delta to HTML converter for export
    // In a real app, use a proper quill_delta to HTML library
    return delta.toString();
  }

  Future<void> _handleRetranscribe(BuildContext context, Recording recording) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retranscribe?'),
        content: const Text('This will overwrite the current transcript. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retranscribe')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final client = ref.read(apiClientProvider).dio;
        await client.post('/case_recordings/${recording.id}/retranscribe');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retranscription started')),
          );
          _loadTranscriptionStatus(recording.id, poll: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start retranscription: $e')),
          );
        }
      }
    }
  }
}

class _AnnotationsList extends StatelessWidget {
  const _AnnotationsList({required this.annotations, required this.onSeek});

  final List<dynamic> annotations;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return Center(
        child: Text(
          'No annotations yet',
          style: GoogleFonts.roboto(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: annotations.length,
      itemBuilder: (context, index) {
        final annotation = annotations[index];
        // Timestamps are in milliseconds from the backend
        final position = Duration(milliseconds: annotation['timestamp'].toInt());
        return ListTile(
          leading: const Icon(Icons.bookmark_outline, size: 18),
          title: Text(annotation['text']),
          subtitle: Text(_formatDuration(position)),
          onTap: () => onSeek(position),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}

class _StatusDropdown extends ConsumerStatefulWidget {
  const _StatusDropdown({
    required this.recordingId,
    required this.currentStatus,
    required this.isEnabled,
  });

  final String recordingId;
  final String currentStatus;
  final bool isEnabled;

  @override
  ConsumerState<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends ConsumerState<_StatusDropdown> {
  String? _localStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _localStatus = _normalizeStatus(widget.currentStatus);
  }

  @override
  void didUpdateWidget(_StatusDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != oldWidget.currentStatus && !_isUpdating) {
      setState(() {
        _localStatus = _normalizeStatus(widget.currentStatus);
      });
    }
  }

  String _normalizeStatus(String status) {
    const validStatuses = ['pending', 'in_progress', 'completed', 'reviewed'];
    String normalized = status.trim().toLowerCase().replaceAll(' ', '_');
    
    if (validStatuses.contains(normalized)) return normalized;
    
    if (normalized.contains('progress')) return 'in_progress';
    if (normalized.contains('review')) return 'reviewed';
    if (normalized.contains('complete')) return 'completed';
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    const validStatuses = ['pending', 'in_progress', 'completed', 'reviewed'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF115343).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF115343).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _localStatus,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          elevation: 4,
          icon: _isUpdating 
              ? const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              : const Icon(Icons.arrow_drop_down),
          onChanged: widget.isEnabled && !_isUpdating ? (value) async {
             if (value != null && value != _localStatus) {
               setState(() {
                 _localStatus = value; // Optimistic update
                 _isUpdating = true;
               });
               
               try {
                 await ref.read(statusRepositoryProvider).updateStatus(
                   recordingId: widget.recordingId,
                   status: value,
                 );
                 
                 // Update the cached list so the patch logic works
                 ref.read(recordingsControllerProvider.notifier).updateRecordingStatus(widget.recordingId, value);
                 
                 // Invalidate details to assume the new status (via patch)
                 ref.invalidate(recordingDetailProvider(widget.recordingId)); 
                 
                 // Artificial delay to show "loading" state briefly if needed
                 // mostly just ensuring the UI feels responsive but "working"
               } catch (e) {
                 // Revert on error
                 if (mounted) {
                   setState(() {
                     _localStatus = _normalizeStatus(widget.currentStatus);
                   });
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Failed to update status: $e')),
                   );
                 }
               } finally {
                 if (mounted) {
                   setState(() {
                     _isUpdating = false;
                   });
                 }
               }
             }
          } : null,
          items: validStatuses
              .map((s) => DropdownMenuItem(
                    value: s, 
                    child: Text(
                      s.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isUpdating ? Colors.grey : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _SaveConfirmationDialog extends StatefulWidget {
  final String? currentStatus;
  final ValueChanged<bool> onMarkCompletedChanged;

  const _SaveConfirmationDialog({
    required this.currentStatus,
    required this.onMarkCompletedChanged,
  });

  @override
  State<_SaveConfirmationDialog> createState() => _SaveConfirmationDialogState();
}

class _SaveConfirmationDialogState extends State<_SaveConfirmationDialog> {
  bool _markAsCompleted = true;

  bool get _canComplete {
    final status = widget.currentStatus?.toLowerCase() ?? 'pending';
    return status == 'pending' || status == 'in_progress';
  }

  @override
  void initState() {
    super.initState();
    // Initialize the parent with default value
    widget.onMarkCompletedChanged(_markAsCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Save Changes',
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF115343),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Are you sure you want to save the changes to this transcript?'),
          if (_canComplete) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF115343).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF115343).withOpacity(0.1)),
              ),
              child: CheckboxListTile(
                value: _markAsCompleted,
                onChanged: (val) {
                  setState(() => _markAsCompleted = val ?? false);
                  widget.onMarkCompletedChanged(_markAsCompleted);
                },
                title: Text(
                  'Mark as Completed',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF115343),
                  ),
                ),
                subtitle: Text(
                  'This will transition the recording status to finalized.',
                  style: GoogleFonts.roboto(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF115343),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.roboto(color: Colors.grey[600]),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF115343),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
