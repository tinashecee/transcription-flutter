import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/recording.dart';
import '../../domain/entities/assigned_user.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/recording_repository.dart';
import '../../data/providers.dart';
import '../../services/auth_session.dart';
import '../../services/dio_error_mapper.dart';
import '../auth/auth_controller.dart';
import '../player/mini_player_bar.dart';
import 'recordings_controller.dart';
import '../../services/update_manager.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  @override
  void initState() {
    super.initState();
    
    // Auto-check for updates in background on dashboard load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasUpdate = await UpdateManager.checkForUpdatesBackground();
      if (hasUpdate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('A new version is available! Tap the update icon to install.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF115343),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                context.go('/system');
              },
            ),
          ),
        );
      }
    });
  }

  bool _canAssign(String? role) {
    final normalized = role?.toLowerCase().trim();
    return normalized == 'admin' ||
        normalized == 'super_admin' ||
        normalized == 'superadmin';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsControllerProvider);
    final controller = ref.read(recordingsControllerProvider.notifier);
    final auth = ref.watch(authSessionProvider);
    print('[RecordingsScreen] build items=${state.items.length} '
        'loading=${state.isLoading} error=${state.errorMessage} '
        'tab=${state.filters.tab.name}');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF115343).withOpacity(0.95),
                const Color(0xFF3F7166).withOpacity(0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 16),
                    child: Image.asset(
                      'assets/images/testimony.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),

                  // Title with version
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recordings',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'v${UpdateManager.appDisplayVersion ?? '2.1.6'}',
                        style: GoogleFonts.roboto(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Action buttons
                  StreamBuilder<bool>(
                    stream: UpdateManager.updateAvailableStream,
                    initialData: UpdateManager.isUpdateAvailable,
                    builder: (context, snapshot) {
                      final hasUpdate = snapshot.data ?? false;
                      return Badge(
                        isLabelVisible: hasUpdate,
                        backgroundColor: Colors.red,
                        offset: const Offset(8, -8),
                        child: IconButton(
                          icon: const Icon(Icons.system_update, color: Colors.white),
                          tooltip: hasUpdate 
                              ? 'New update available! Click to view'
                              : 'System Status & Updates',
                          onPressed: () {
                            context.go('/system');
                          },
                        ),
                      );
                    },
                  ),

                  IconButton(
                    onPressed: () => controller.loadInitial(),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh',
                  ),

                  IconButton(
                    onPressed: () => ref.read(authControllerProvider).logout(),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayerBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF0F4F3),
              const Color(0xFFF0F4F3).withOpacity(0.8),
            ],
          ),
        ),
        child: Row(
          children: [
            // Court Filter Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: _CourtFilterSidebar(
                selectedCourt: state.filters.court,
                selectedCourtroom: state.filters.courtroom,
                onCourtSelected: (court) => controller.updateFilters(
                  RecordingFilters(
                    court: court,
                    courtroom: null, // Clear courtroom when changing court
                    query: state.filters.query,
                    fromDate: state.filters.fromDate,
                    toDate: state.filters.toDate,
                    tab: state.filters.tab,
                  ),
                ),
                onCourtroomSelected: (courtroom) => controller.updateFilters(
                  RecordingFilters(
                    court: state.filters.court,
                    courtroom: courtroom,
                    query: state.filters.query,
                    fromDate: state.filters.fromDate,
                    toDate: state.filters.toDate,
                    tab: state.filters.tab,
                  ),
                ),
              ),
            ),

            // Main Content
            Expanded(
              child: Column(
                children: [
                  _FiltersBar(
                    filters: state.filters,
                    onFiltersChanged: controller.updateFilters,
                  ),
                  if (auth.isAuthenticated)
                    _TabsBar(
                      selected: state.filters.tab,
                      onChanged: (tab) => controller.updateFilters(
                        RecordingFilters(
                          court: state.filters.court,
                          courtroom: state.filters.courtroom,
                          query: state.filters.query,
                          fromDate: state.filters.fromDate,
                          toDate: state.filters.toDate,
                          tab: tab,
                        ),
                      ),
                    ),
                  Expanded(
                    child: state.isLoading && state.items.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF115343),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF115343),
                            onRefresh: controller.loadInitial,
                            child: ListView.builder(
                              itemCount: state.items.length + 1,
                              itemBuilder: (context, index) {
                                if (index >= state.items.length) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    child: TextButton(
                                      onPressed: state.isLoading ? null : () => controller.loadMore(),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF115343),
                                      ),
                                      child: state.isLoading
                                          ? const CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Color(0xFF115343),
                                              ),
                                            )
                                          : Text(
                                              'Load more',
                                              style: GoogleFonts.roboto(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                    ),
                                  );
                                }
                                final recording = state.items[index];
                                return _RecordingTile(
                                  recording: recording,
                                  isMyList: state.filters.tab ==
                                      RecordingTab.myList,
                                  canAssign: _canAssign(auth.user?.role),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingTile extends ConsumerStatefulWidget {
  const _RecordingTile({
    required this.recording,
    required this.isMyList,
    required this.canAssign,
  });

  final Recording recording;
  final bool isMyList;
  final bool canAssign;

  @override
  ConsumerState<_RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends ConsumerState<_RecordingTile> {
  bool _isOperationInProgress = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFF9800); // Orange
      case 'in_progress':
        return const Color(0xFF2196F3); // Blue
      case 'completed':
        return const Color(0xFF4CAF50); // Green
      case 'reviewed':
        return const Color(0xFF9C27B0); // Purple
      default:
        return const Color(0xFF757575); // Grey
    }
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return 'Duration N/A';
    final totalSeconds = seconds.floor();
    if (totalSeconds <= 0) return 'Duration N/A';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final remainingSeconds = totalSeconds % 60;

    final parts = <String>[];
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || hours > 0) {
      parts.add('${minutes}m');
    }
    parts.add('${remainingSeconds}s');

    return parts.join(' ');
  }

  Future<void> _handleAddToMyList() async {
    if (_isOperationInProgress) return;
    
    final userId = ref.read(authSessionProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      await ref.read(authControllerProvider).logout();
      return;
    }

    setState(() => _isOperationInProgress = true);
    
    try {
      // Step 1: Call API and wait for response
      print('[RecordingsScreen] POST /add_transcription_user case_id=${widget.recording.id} user_id=$userId');
      await ref.read(assignmentRepositoryProvider).assignRecording(
        widget.recording.id,
        userId: userId,
      );
      print('[RecordingsScreen] API returned success');

      // Step 2: Clear current state and reload fresh from API
      print('[RecordingsScreen] Clearing state and reloading from API...');
      final controller = ref.read(recordingsControllerProvider.notifier);
      await controller.loadInitial();
      print('[RecordingsScreen] Reload from API completed');
      
      // Note: No snackbar - the UI will update because we reloaded from API
    } catch (e) {
      print('[RecordingsScreen] API error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to list: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOperationInProgress = false);
      }
    }
  }

  Future<void> _handleRemoveFromMyList() async {
    if (_isOperationInProgress) return;
    
    final userId = ref.read(authSessionProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      await ref.read(authControllerProvider).logout();
      return;
    }

    setState(() => _isOperationInProgress = true);
    
    try {
      // Step 1: Call API and wait for response
      print('[RecordingsScreen] DELETE unassign case_id=${widget.recording.id} user_id=$userId');
      await ref.read(assignmentRepositoryProvider).unassignRecording(
        widget.recording.id,
        userId: userId,
      );
      print('[RecordingsScreen] API returned success');

      // Step 2: Clear current state and reload fresh from API
      print('[RecordingsScreen] Clearing state and reloading from API...');
      final controller = ref.read(recordingsControllerProvider.notifier);
      await controller.loadInitial();
      print('[RecordingsScreen] Reload from API completed');
      
      // Note: No snackbar - the UI will update because we reloaded from API
    } catch (e) {
      print('[RecordingsScreen] API error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove from list: $e')),
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
    final date = DateFormat.yMMMd().format(widget.recording.date);
    final status = (widget.recording.status.isEmpty ? 'pending' : widget.recording.status);
    final durationLabel = _formatDuration(widget.recording.durationSeconds);
    final metaChips = <Widget>[
      _MetaChip(icon: Icons.calendar_today, label: date),
      _MetaChip(icon: Icons.account_balance, label: widget.recording.court),
      _MetaChip(icon: Icons.meeting_room, label: widget.recording.courtroom),
      _MetaChip(icon: Icons.schedule, label: durationLabel),
    ];
    if (widget.recording.judgeName.isNotEmpty) {
      metaChips.add(
        _MetaChip(icon: Icons.gavel, label: widget.recording.judgeName),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${widget.recording.caseNumber} • ${widget.recording.title}',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: const Color(0xFF115343),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: metaChips,
            ),
            if (widget.isMyList) ...[
              const SizedBox(height: 10),
              _AssignedUsersRow(recordingId: widget.recording.id),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!widget.isMyList)
                  OutlinedButton.icon(
                    onPressed: _isOperationInProgress ? null : _handleAddToMyList,
                    icon: _isOperationInProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add, size: 18),
                    label: Text(
                      _isOperationInProgress ? 'Adding...' : 'Add to My List',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (widget.isMyList)
                  OutlinedButton.icon(
                    onPressed: _isOperationInProgress ? null : _handleRemoveFromMyList,
                    icon: _isOperationInProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(
                      _isOperationInProgress ? 'Removing...' : 'Remove from My List',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                if (widget.canAssign)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => _AssignToDialog(
                          recordingId: widget.recording.id,
                          recordingTitle: widget.recording.title,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(
                      'Assign To',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      side: const BorderSide(color: Color(0xFF1E88E5)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.go('/recordings/${widget.recording.id}'),
                  tooltip: 'Open',
                  icon: const Icon(Icons.open_in_new, color: Color(0xFF115343)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF115343).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF115343).withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF115343)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: const Color(0xFF115343),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedUsersRow extends ConsumerWidget {
  const _AssignedUsersRow({required this.recordingId});

  final String recordingId;

  String _displayNameForAssignee(AssignedUser assignee) {
    final name = assignee.name.trim();
    if (name.isNotEmpty) return name;
    return assignee.email.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(assignmentRepositoryProvider).getAssignedUsers(recordingId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        if (data.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Assigned:',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            ...data.map((assignee) {
              final label = _displayNameForAssignee(assignee);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECEF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AssignToDialog extends ConsumerStatefulWidget {
  const _AssignToDialog({
    required this.recordingId,
    required this.recordingTitle,
  });

  final String recordingId;
  final String recordingTitle;

  @override
  ConsumerState<_AssignToDialog> createState() => _AssignToDialogState();
}

class _AssignToDialogState extends ConsumerState<_AssignToDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingUsers = true;
  bool _isLoadingAssigned = true;
  List<User> _users = [];
  List<AssignedUser> _assigned = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUsers(),
      _loadAssigned(),
    ]);
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await ref.read(assignmentRepositoryProvider).getAvailableUsers();
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (_) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadAssigned() async {
    setState(() => _isLoadingAssigned = true);
    try {
      final assigned =
          await ref.read(assignmentRepositoryProvider).getAssignedUsers(
                widget.recordingId,
              );
      setState(() {
        _assigned = assigned;
        _isLoadingAssigned = false;
      });
    } catch (_) {
      setState(() => _isLoadingAssigned = false);
    }
  }

  Future<void> _assignUser(User user) async {
    final currentUser = ref.read(authSessionProvider).user;
    if (currentUser == null) {
      await ref.read(authControllerProvider).logout();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    print('[AssignToDialog] Assigning user ${user.id} to recording ${widget.recordingId}');
    await ref.read(assignmentRepositoryProvider).assignRecording(
          widget.recordingId,
          userId: user.id,
          type: user.email == currentUser.email
              ? 'self_assigned'
              : 'admin_assigned',
        );
    print('[AssignToDialog] Assignment completed, reloading...');
    await _loadAssigned();
    // Also refresh the main recordings list
    await ref.read(recordingsControllerProvider.notifier).loadInitial();
  }

  Future<void> _removeAssignment(AssignedUser assignment) async {
    final currentUser = ref.read(authSessionProvider).user;
    if (currentUser == null) {
      await ref.read(authControllerProvider).logout();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (assignment.id.isEmpty) return;
    print('[AssignToDialog] Removing assignment ${assignment.id}');
    await ref.read(assignmentRepositoryProvider).deleteAssignment(assignment.id);
    print('[AssignToDialog] Removal completed, reloading...');
    await _loadAssigned();
    // Also refresh the main recordings list
    await ref.read(recordingsControllerProvider.notifier).loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final assignedUserIds = _assigned.map((e) => e.userId).toSet();
    final filteredUsers = _users.where((user) {
      if (assignedUserIds.contains(user.id)) return false;
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          (user.court ?? '').toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: Text(
        'Assign Recording',
        style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 520,
        height: 500, // Fixed height to prevent overflow
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.recordingTitle,
                style: GoogleFonts.roboto(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, court, or role...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Available Users',
                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_isLoadingUsers)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredUsers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No users found',
                    style: GoogleFonts.roboto(color: Colors.grey[600]),
                  ),
                )
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return ListTile(
                        dense: true,
                        title: Text(user.name, style: GoogleFonts.roboto()),
                        subtitle: Text(
                          '${user.email} • ${user.role}',
                          style: GoogleFonts.roboto(fontSize: 12),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _assignUser(user),
                          child: const Text('Assign'),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Currently Assigned',
                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_isLoadingAssigned)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_assigned.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No assigned users',
                    style: GoogleFonts.roboto(color: Colors.grey[600]),
                  ),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _assigned.length,
                    itemBuilder: (context, index) {
                      final assigned = _assigned[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          assigned.name.isNotEmpty ? assigned.name : assigned.email,
                          style: GoogleFonts.roboto(),
                        ),
                        subtitle: Text(
                          assigned.email,
                          style: GoogleFonts.roboto(fontSize: 12),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _removeAssignment(assigned),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD32F2F),
                            side: const BorderSide(color: Color(0xFFD32F2F)),
                          ),
                          child: const Text('Remove'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _TabsBar extends StatelessWidget {
  const _TabsBar({required this.selected, required this.onChanged});

  final RecordingTab selected;
  final ValueChanged<RecordingTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<RecordingTab>(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF115343),
          selectedBackgroundColor: const Color(0xFF115343).withOpacity(0.1),
          selectedForegroundColor: const Color(0xFF115343),
          side: BorderSide(
            color: const Color(0xFF115343).withOpacity(0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        segments: [
          ButtonSegment(
            value: RecordingTab.all,
            label: Text(
              'All Recordings',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ButtonSegment(
            value: RecordingTab.myList,
            label: Text(
              'My List',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
      ),
    );
  }
}

class _FiltersBar extends StatefulWidget {
  const _FiltersBar({required this.filters, required this.onFiltersChanged});

  final RecordingFilters filters;
  final ValueChanged<RecordingFilters> onFiltersChanged;

  @override
  State<_FiltersBar> createState() => _FiltersBarState();
}

class _FiltersBarState extends State<_FiltersBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters.query != widget.filters.query) {
      _searchController.text = widget.filters.query ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.roboto(
                color: const Color(0xFF115343),
              ),
              decoration: InputDecoration(
                labelText: 'Search case number or title',
                labelStyle: GoogleFonts.roboto(
                  color: Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: const Color(0xFF115343).withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF115343).withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF115343).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF115343),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF115343).withOpacity(0.02),
              ),
              onSubmitted: (value) => widget.onFiltersChanged(
                RecordingFilters(
                  court: widget.filters.court,
                  courtroom: widget.filters.courtroom,
                  query: value,
                  fromDate: widget.filters.fromDate,
                  toDate: widget.filters.toDate,
                  tab: widget.filters.tab,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.search),
            label: Text(
              'Search',
              style: GoogleFonts.roboto(
                color: const Color(0xFF115343),
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFF115343).withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => widget.onFiltersChanged(
              RecordingFilters(
                court: widget.filters.court,
                courtroom: widget.filters.courtroom,
                query: _searchController.text.trim(),
                fromDate: widget.filters.fromDate,
                toDate: widget.filters.toDate,
                tab: widget.filters.tab,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear),
            label: Text(
              'Clear',
              style: GoogleFonts.roboto(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              _searchController.clear();
              widget.onFiltersChanged(
                RecordingFilters(
                  court: widget.filters.court,
                  courtroom: widget.filters.courtroom,
                  query: null,
                  fromDate: widget.filters.fromDate,
                  toDate: widget.filters.toDate,
                  tab: widget.filters.tab,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: Icon(
              Icons.filter_alt,
              color: const Color(0xFF115343),
            ),
            label: Text(
              'Filters',
              style: GoogleFonts.roboto(
                color: const Color(0xFF115343),
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFF115343).withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              final result = await showDialog<RecordingFilters>(
                context: context,
                builder: (context) => _FilterDialog(filters: widget.filters),
              );
              if (result != null) {
                widget.onFiltersChanged(result);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.filters});

  final RecordingFilters filters;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime? _fromDate = widget.filters.fromDate;
  late DateTime? _toDate = widget.filters.toDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Filters',
        style: GoogleFonts.roboto(
          color: const Color(0xFF115343),
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'From',
                  value: _fromDate,
                  onChanged: (value) => setState(() => _fromDate = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'To',
                  value: _toDate,
                  onChanged: (value) => setState(() => _toDate = value),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.roboto(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF115343),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(
            RecordingFilters(
              court: widget.filters.court,
              courtroom: widget.filters.courtroom,
              query: widget.filters.query,
              fromDate: _fromDate,
              toDate: _toDate,
              tab: widget.filters.tab,
            ),
          ),
          child: Text(
            'Apply',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: const Color(0xFF115343).withOpacity(0.3),
          ),
        ),
      ),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year + 1),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF115343),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF115343),
                ),
              ),
              child: child!,
            );
          },
        );
        onChanged(picked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value == null ? 'Any' : DateFormat.yMMMd().format(value!),
            style: GoogleFonts.roboto(
              color: const Color(0xFF115343),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourtFilterSidebar extends ConsumerStatefulWidget {
  const _CourtFilterSidebar({
    required this.selectedCourt,
    required this.selectedCourtroom,
    required this.onCourtSelected,
    required this.onCourtroomSelected,
  });

  final String? selectedCourt;
  final String? selectedCourtroom;
  final ValueChanged<String?> onCourtSelected;
  final ValueChanged<String?> onCourtroomSelected;

  @override
  ConsumerState<_CourtFilterSidebar> createState() =>
      _CourtFilterSidebarState();
}

class _CourtFilterSidebarState extends ConsumerState<_CourtFilterSidebar> {
  String? _selectedLetter;
  bool _isExpanded = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _courts = [];
  Map<String, List<String>> _courtroomsByCourt = {};

  @override
  void initState() {
    super.initState();
    _loadCourtsAndRooms();
  }

  Future<void> _loadCourtsAndRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(recordingRepositoryProvider);
      final results = await Future.wait([
        repo.fetchCourts(),
        repo.fetchCourtroomsByCourt(),
      ]);
      _courts = (results[0] as List<String>)..sort();
      _courtroomsByCourt = results[1] as Map<String, List<String>>;
      setState(() => _isLoading = false);
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = mapDioError(error);
      });
    }
  }

  List<String> get _filteredCourts {
    if (_selectedLetter == null) return [];
    return _courts.where((court) =>
        court.toUpperCase().startsWith(_selectedLetter!)).toList()
      ..sort();
  }

  List<String> _getCourtrooms(String court) {
    return _courtroomsByCourt[court] ?? [];
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF115343).withOpacity(0.1),
                const Color(0xFF3F7166).withOpacity(0.1),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Court Filter',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF115343),
                ),
              ),
              const Spacer(),
              if (widget.selectedCourt != null)
                IconButton(
                  onPressed: () {
                    widget.onCourtSelected(null);
                    widget.onCourtroomSelected(null);
                  },
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  tooltip: 'Clear filter',
                ),
            ],
          ),
        ),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load courts',
              style: GoogleFonts.roboto(color: Colors.redAccent),
            ),
          )
        else
          const SizedBox.shrink(),

        // Fixed Alphabetical Index
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 3,
            runSpacing: 3,
            children: List.generate(26, (index) {
              final letter = String.fromCharCode(65 + index); // A-Z
              final isSelected = _selectedLetter == letter;
              final hasCourts = _courts.any((court) =>
                  court.toUpperCase().startsWith(letter));

              return InkWell(
                onTap: hasCourts ? () {
                  setState(() {
                    _selectedLetter = isSelected ? null : letter;
                  });
                } : null,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF115343)
                        : hasCourts
                            ? const Color(0xFF115343).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : hasCourts
                                ? const Color(0xFF115343)
                                : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Court List with Expandable Courtrooms
        if (!_isLoading && _errorMessage == null)
          Expanded(
            child: ListView.builder(
              itemCount: _getListItemCount(),
              itemBuilder: (context, index) {
                return _buildListItem(context, index);
              },
            ),
          )
        else
          const Spacer(),

        // Footer with instruction
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            color: Colors.grey.withOpacity(0.05),
          ),
          child: Text(
            _selectedLetter != null
                ? 'Click court to select courtroom'
                : 'Select a letter to browse courts',
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  int _getListItemCount() {
    if (_selectedLetter == null) return 0;

    int count = _filteredCourts.length;
    // Add courtroom items for the selected court if expanded
    if (widget.selectedCourt != null && _isExpanded && _getCourtrooms(widget.selectedCourt!).isNotEmpty) {
      count += 1 + _getCourtrooms(widget.selectedCourt!).length; // +1 for "All Courtrooms" option
    }
    return count;
  }

  Widget _buildListItem(BuildContext context, int index) {
    final courts = _filteredCourts;
    int currentIndex = 0;

    // Find which section this index belongs to
    for (int courtIndex = 0; courtIndex < courts.length; courtIndex++) {
      final court = courts[courtIndex];
      final isSelectedCourt = widget.selectedCourt == court;
      final courtrooms = _getCourtrooms(court);

      // Court item
      if (currentIndex == index) {
        return _buildCourtItem(court, isSelectedCourt, courtrooms.isNotEmpty);
      }
      currentIndex++;

      // Courtroom items (if this court is selected and expanded)
      if (isSelectedCourt && _isExpanded && courtrooms.isNotEmpty) {
        // "All Courtrooms" option
        if (currentIndex == index) {
          return _buildCourtroomItem('All Courtrooms', widget.selectedCourtroom == null, true);
        }
        currentIndex++;

        // Individual courtrooms
        for (int roomIndex = 0; roomIndex < courtrooms.length; roomIndex++) {
          if (currentIndex == index) {
            final courtroom = courtrooms[roomIndex];
            final isLastRoom = roomIndex == courtrooms.length - 1;
            return _buildCourtroomItem(courtroom, widget.selectedCourtroom == courtroom, false, isLastRoom);
          }
          currentIndex++;
        }
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildCourtItem(String court, bool isSelected, bool hasCourtrooms) {
    return InkWell(
      onTap: () {
        if (isSelected) {
          setState(() => _isExpanded = !_isExpanded);
        } else {
          widget.onCourtSelected(court);
          if (hasCourtrooms) {
            setState(() => _isExpanded = true);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF115343).withOpacity(0.08)
              : null,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance,
              size: 18,
              color: isSelected
                  ? const Color(0xFF115343)
                  : Colors.grey[600],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                court,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF115343)
                      : Colors.grey[800],
                ),
              ),
            ),
            if (hasCourtrooms)
              Icon(
                isSelected
                    ? (_isExpanded ? Icons.expand_less : Icons.expand_more)
                    : Icons.chevron_right,
                size: 18,
                color: const Color(0xFF115343).withOpacity(0.6),
              ),
            if (isSelected && !hasCourtrooms)
              Icon(
                Icons.check,
                size: 18,
                color: const Color(0xFF115343),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtroomItem(String label, bool isSelected, bool isAllOption, [bool isLast = false]) {
    return InkWell(
      onTap: () => widget.onCourtroomSelected(isAllOption ? null : label),
      child: Container(
        padding: const EdgeInsets.only(left: 44, right: 16, top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF115343).withOpacity(0.06)
              : null,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.08),
              width: isLast ? 1 : 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.meeting_room,
              size: 16,
              color: isSelected
                  ? const Color(0xFF115343)
                  : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF115343)
                      : Colors.grey[700],
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 16,
                color: const Color(0xFF115343),
              ),
          ],
        ),
      ),
    );
  }
}
