import 'dart:ui';
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
import '../widgets/collapsible_sidebar.dart';
import '../widgets/action_button.dart';

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
    
    return Padding(
      padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
      child: Column(
        children: [
          _SearchHeader(
            filters: state.filters,
            onFiltersChanged: controller.updateFilters,
          ),
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _TabsBar(
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
                  : Column(
                      children: [
                        const _ListHeader(),
                        Expanded(
                          child: _RecordingsList(
                            items: state.items,
                            isLoading: state.isLoading,
                            isMyList: state.filters.tab == RecordingTab.myList,
                            canAssign: _canAssign(auth.user?.role),
                          ),
                        ),
                        if (state.items.isNotEmpty)
                          _PaginationFooter(
                            page: state.page,
                            pageSize: state.pageSize,
                            totalItems: state.totalItems,
                            onPageChanged: controller.setPage,
                            onPageSizeChanged: controller.setPageSize,
                            isLoading: state.isLoading,
                          ),
                      ],
                    ),
          ),
        ],
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Hero(
        tag: widget.recording.id,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF115343).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF115343).withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/recordings/${widget.recording.id}'),
              hoverColor: const Color(0xFF115343).withOpacity(0.02),
              splashColor: const Color(0xFF115343).withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                              fontSize: 17,
                              color: const Color(0xFF115343),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getStatusColor(status),
                                _getStatusColor(status).withOpacity(0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _getStatusColor(status).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: metaChips,
                    ),
                    if (widget.isMyList) ...[
                      const SizedBox(height: 12),
                      _AssignedUsersRow(recordingId: widget.recording.id),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (!widget.isMyList)
                          _ModernButton(
                            icon: Icons.playlist_add,
                            label: _isOperationInProgress ? 'Adding...' : 'Add to My List',
                            color: const Color(0xFF2E7D32),
                            isLoading: _isOperationInProgress,
                            onPressed: _isOperationInProgress ? null : _handleAddToMyList,
                          ),
                        if (widget.isMyList)
                          _ModernButton(
                            icon: Icons.remove_circle_outline,
                            label: _isOperationInProgress ? 'Removing...' : 'Remove from My List',
                            color: const Color(0xFFD32F2F),
                            isLoading: _isOperationInProgress,
                            onPressed: _isOperationInProgress ? null : _handleRemoveFromMyList,
                          ),
                        const SizedBox(width: 10),
                        if (widget.canAssign)
                          _ModernButton(
                            icon: Icons.person_add,
                            label: 'Assign To',
                            color: const Color(0xFF1E88E5),
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => _AssignToDialog(
                                  recordingId: widget.recording.id,
                                  recordingTitle: widget.recording.title,
                                ),
                              );
                            },
                          ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF115343).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: () => context.go('/recordings/${widget.recording.id}'),
                            tooltip: 'Open',
                            icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF115343)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF115343).withOpacity(0.08),
            const Color(0xFF115343).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF115343).withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF115343).withOpacity(0.7)),
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

/// Modern filled button with gradient and shadow
class _ModernButton extends StatelessWidget {
  const _ModernButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
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
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    try {
      final users = await ref.read(assignmentRepositoryProvider).getAvailableUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadAssigned() async {
    if (!mounted) return;
    setState(() => _isLoadingAssigned = true);
    try {
      final assigned =
          await ref.read(assignmentRepositoryProvider).getAssignedUsers(
                widget.recordingId,
              );
      if (!mounted) return;
      setState(() {
        _assigned = assigned;
        _isLoadingAssigned = false;
      });
    } catch (_) {
      if (!mounted) return;
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
    final currentUser = ref.watch(authSessionProvider).user;
    final isMeAssigned = currentUser != null && assignedUserIds.contains(currentUser.id);

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
              const SizedBox(height: 16),
              
              if (!isMeAssigned && currentUser != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _assignUser(currentUser),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF115343),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_task),
                    label: Text(
                      'Assign to Me',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],

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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(left: 0, top: 8, bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF115343).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF115343).withOpacity(0.1),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<RecordingTab>(
            value: selected,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF115343)),
            isExpanded: true,
            style: GoogleFonts.roboto(
              color: const Color(0xFF115343),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: const Color(0xFFF5F7FA), // Light grey-blue match
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem(
                value: RecordingTab.all,
                child: Row(
                  children: [
                    Icon(Icons.dashboard_rounded, 
                      size: 20, 
                      color: selected == RecordingTab.all ? const Color(0xFF115343) : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    const Text('All Recordings'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: RecordingTab.myList,
                child: Row(
                  children: [
                    Icon(Icons.bookmark_rounded, 
                      size: 20, 
                      color: selected == RecordingTab.myList ? const Color(0xFF115343) : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    const Text('My List'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class _SearchHeader extends StatefulWidget {
  const _SearchHeader({
    required this.filters,
    required this.onFiltersChanged,
  });

  final RecordingFilters filters;
  final ValueChanged<RecordingFilters> onFiltersChanged;

  @override
  State<_SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<_SearchHeader> {
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
  void didUpdateWidget(_SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filters.query != oldWidget.filters.query &&
        widget.filters.query != _searchController.text) {
      _searchController.text = widget.filters.query ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // Centered Search Bar
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF115343).withOpacity(0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF115343).withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF115343),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search case number, title, or judge...',
                    hintStyle: GoogleFonts.roboto(
                      color: const Color(0xFF115343).withOpacity(0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: const Color(0xFF115343).withOpacity(0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
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
            ),
          ),

          // Right Side Actions
          const SizedBox(width: 16),
          Consumer(
            builder: (context, ref, _) => ActionButton(
              icon: Icons.backspace_outlined,
              tooltip: 'Clear All Filters',
              onPressed: () {
                _searchController.clear();
                ref.read(recordingsControllerProvider.notifier).clearFilters();
              },
            ),
          ),
          const SizedBox(width: 16),
          Consumer(
            builder: (context, ref, _) {
              final isLoading = ref.watch(recordingsControllerProvider.select((s) => s.isLoading));
              return ActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh List',
                isSpinning: isLoading,
                onPressed: isLoading ? null : () => ref.read(recordingsControllerProvider.notifier).fullRefresh(),
              );
            },
          ),
          const SizedBox(width: 24),
          ActionButton(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filter by Date',
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
          const SizedBox(width: 12),
          // User Updates
          const _UpdateBadge(),
          const SizedBox(width: 12),
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
    );
  }
}

// ActionButton refactored to shared widget in lib/presentation/widgets/action_button.dart


class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: UpdateManager.updateAvailableStream,
      initialData: UpdateManager.isUpdateAvailable,
      builder: (context, snapshot) {
        final hasUpdate = snapshot.data ?? false;
        if (!hasUpdate) return const SizedBox.shrink();
        
        return ActionButton(
          icon: Icons.system_update,
          tooltip: 'New update available',
          color: Colors.red.withOpacity(0.1),
          iconColor: Colors.red,
          onPressed: () => context.go('/system'),
        );
      },
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              'RECORDING',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              'ASSIGNED TO',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              'COURT / JUDGE',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            child: Text(
              'STATUS',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              'DATE',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            child: Icon(
              Icons.access_time,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingsList extends StatelessWidget {
  const _RecordingsList({
    required this.items,
    required this.isLoading,
    required this.isMyList,
    required this.canAssign,
  });

  final List<Recording> items;
  final bool isLoading;
  final bool isMyList;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No recordings found',
              style: GoogleFonts.roboto(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _RecordingRow(
          index: index + 1,
          recording: items[index],
          isMyList: isMyList,
          canAssign: canAssign,
        );
      },
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.isLoading = false,
  });

  final int page;
  final int pageSize;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final startRange = totalItems == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final endRange = (page * pageSize) > totalItems ? totalItems : (page * pageSize);
    final totalPages = (totalItems / pageSize).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Range Info
          Row(
            children: [
              Text(
                '$startRange-$endRange',
                style: GoogleFonts.roboto(
                  color: const Color(0xFF115343),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                ' / $totalItems',
                style: GoogleFonts.roboto(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Pagination Controls
          Row(
            children: [
              // Rows per page
              Text(
                'Rows per page:',
                style: GoogleFonts.roboto(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF115343).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF115343).withOpacity(0.1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: [20, 50, 100].contains(pageSize) ? pageSize : 20,
                    icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF115343)),
                    style: GoogleFonts.roboto(
                      color: const Color(0xFF115343),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [20, 50, 100].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: isLoading ? null : (value) => onPageSizeChanged(value!),
                  ),
                ),
              ),
              const SizedBox(width: 32),

              // Page Nav
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onPressed: page > 1 && !isLoading ? () => onPageChanged(page - 1) : null,
                tooltip: 'Previous Page',
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF115343).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $page of $totalPages',
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF115343),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onPressed: page < totalPages && !isLoading ? () => onPageChanged(page + 1) : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: onPressed == null ? Colors.transparent : Colors.white,
              border: Border.all(
                color: (onPressed == null ? Colors.grey : const Color(0xFF115343)).withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: onPressed != null ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null ? Colors.grey[400] : const Color(0xFF115343),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingRow extends ConsumerStatefulWidget {
  const _RecordingRow({
    required this.index,
    required this.recording,
    required this.isMyList,
    required this.canAssign,
  });

  final int index;
  final Recording recording;
  final bool isMyList;
  final bool canAssign;

  @override
  ConsumerState<_RecordingRow> createState() => _RecordingRowState();
}

class _RecordingRowState extends ConsumerState<_RecordingRow> {
  bool _isHovered = false;
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
    if (seconds == null) return '0:00';
    final totalSeconds = seconds.floor();
    if (totalSeconds <= 0) return '0:00';
    final minutes = totalSeconds ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }


  Future<void> _handleAddToMyList() async {
    if (_isOperationInProgress) return;
    final userId = ref.read(authSessionProvider).user?.id;
    if (userId == null) return;
    setState(() => _isOperationInProgress = true);
    try {
      await ref.read(assignmentRepositoryProvider).assignRecording(
        widget.recording.id,
        userId: userId,
      );
      ref.read(recordingsControllerProvider.notifier).loadInitial();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isOperationInProgress = false);
    }
  }

  Future<void> _handleRemoveFromMyList() async {
    if (_isOperationInProgress) return;
    final userId = ref.read(authSessionProvider).user?.id;
    if (userId == null) return;
    setState(() => _isOperationInProgress = true);
    try {
      await ref.read(assignmentRepositoryProvider).unassignRecording(
        widget.recording.id,
        userId: userId,
      );
      ref.read(recordingsControllerProvider.notifier).loadInitial();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isOperationInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(widget.recording.date);
    final duration = _formatDuration(widget.recording.durationSeconds);
    final status = widget.recording.status.isEmpty ? 'pending' : widget.recording.status;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/recordings/${widget.recording.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF115343).withOpacity(0.04) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // # ID
              SizedBox(
                width: 40,
                child: Text(
                  '${widget.index}',
                  style: GoogleFonts.roboto(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 16),
              
              // TITLE
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.recording.title.toUpperCase(),
                      style: GoogleFonts.roboto(
                        color: const Color(0xFF115343),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.recording.caseNumber,
                      style: GoogleFonts.roboto(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                flex: 3,
                child: _AssignmentCell(
                  recording: widget.recording,
                  isMyList: widget.isMyList,
                  canAssign: widget.canAssign,
                  onAddToMyList: _handleAddToMyList,
                  onRemoveFromMyList: _handleRemoveFromMyList,
                  isOperationInProgress: _isOperationInProgress,
                ),
              ),
              const SizedBox(width: 16),

              // COURT
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.recording.court.toUpperCase(),
                      style: GoogleFonts.roboto(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.recording.judgeName.isNotEmpty)
                      Text(
                        widget.recording.judgeName.toUpperCase(),
                        style: GoogleFonts.roboto(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // STATUS
              SizedBox(
                width: 110,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.roboto(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // DATE
              Expanded(
                flex: 2,
                child: Text(
                  date,
                  style: GoogleFonts.roboto(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // DURATION
              SizedBox(
                width: 60,
                child: Text(
                  duration,
                  style: GoogleFonts.roboto(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentCell extends StatelessWidget {
  const _AssignmentCell({
    required this.recording,
    required this.isMyList,
    required this.canAssign,
    required this.onAddToMyList,
    required this.onRemoveFromMyList,
    required this.isOperationInProgress,
  });

  final Recording recording;
  final bool isMyList;
  final bool canAssign;
  final VoidCallback onAddToMyList;
  final VoidCallback onRemoveFromMyList;
  final bool isOperationInProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final currentUserId = ref.read(authSessionProvider).user?.id;
              return FutureBuilder<List<AssignedUser>>(
                future: ref.read(assignmentRepositoryProvider).getAssignedUsers(recording.id),
                builder: (context, snapshot) {
                  final assignments = snapshot.data ?? [];
                  final isAssignedToMe = currentUserId != null && 
                      assignments.any((a) => a.userId == currentUserId);

                  if (assignments.isEmpty && !canAssign) {
                    return Text('-', style: TextStyle(color: Colors.grey[400]));
                  }
                  
                  if (assignments.isEmpty) {
                    return Text(
                      'Unassigned',
                      style: GoogleFonts.roboto(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...assignments.map((a) {
                        final rawName = a.name.isNotEmpty ? a.name : a.email.split('@').first;
                        final name = rawName.toUpperCase();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF115343).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF115343).withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            name,
                            style: GoogleFonts.roboto(
                              color: const Color(0xFF115343),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }),
                      // We use snapshot data to determine final button state
                      if (isOperationInProgress)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else ...[
                        if (isAssignedToMe)
                           IconButton(
                             icon: const Icon(Icons.remove_circle_outline, 
                               size: 20, 
                               color: Color(0xFFD32F2F),
                             ),
                             tooltip: 'Remove from My List',
                             onPressed: onRemoveFromMyList,
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                           )
                        else
                           IconButton(
                             icon: const Icon(Icons.add_circle_outline, 
                               size: 20, 
                               color: Color(0xFF2E7D32),
                             ),
                             tooltip: 'Add to My List',
                             onPressed: onAddToMyList,
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                           ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (!isOperationInProgress && canAssign) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.person_add_outlined,
              size: 20,
              color: Color(0xFF1E88E5),
            ),
            tooltip: 'Assign To...',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _AssignToDialog(
                  recordingId: recording.id,
                  recordingTitle: recording.title,
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
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

  void _reset() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  void _setRange(DateTime? start, DateTime? end) {
    setState(() {
      _fromDate = start;
      _toDate = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by Date',
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF115343),
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF115343).withOpacity(0.6),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select a date range or use a quick shortcut.',
              style: GoogleFonts.roboto(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            // Shortcuts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                     _ShortcutChip(
                      label: 'Today',
                      onTap: () => _setRange(today, null),
                    ),
                    const SizedBox(width: 8),
                    _ShortcutChip(
                      label: 'Yesterday',
                      onTap: () => _setRange(yesterday, today),
                    ),
                    const SizedBox(width: 8),
                    _ShortcutChip(
                      label: 'This Week',
                      onTap: () => _setRange(weekStart, null),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _fromDate,
                    onChanged: (value) => setState(() => _fromDate = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DateField(
                    label: 'To',
                    value: _toDate,
                    onChanged: (value) => setState(() => _toDate = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.roboto(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernButton(
                    icon: Icons.check_circle_rounded,
                    label: 'Apply Filters',
                    color: const Color(0xFF115343),
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
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF115343).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF115343).withOpacity(0.1),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.roboto(
              color: const Color(0xFF115343),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: const Color(0xFF115343).withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 5),
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
                      datePickerTheme: DatePickerThemeData(
                        backgroundColor: Colors.white,
                        headerBackgroundColor: const Color(0xFF115343),
                        headerForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        dayStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                        headerHeadlineStyle: GoogleFonts.roboto(
                          fontSize: 24, 
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        dayOverlayColor: WidgetStateProperty.all(
                          const Color(0xFF115343).withOpacity(0.1),
                        ),
                        yearStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              onChanged(picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF115343).withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: value != null 
                    ? const Color(0xFF115343) 
                    : const Color(0xFF115343).withOpacity(0.1),
                  width: value != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: value != null 
                      ? const Color(0xFF115343) 
                      : const Color(0xFF115343).withOpacity(0.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value == null ? 'Select Date' : DateFormat.yMMMd().format(value!),
                      style: GoogleFonts.roboto(
                        color: value != null 
                          ? const Color(0xFF115343) 
                          : const Color(0xFF115343).withOpacity(0.4),
                        fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (value != null)
                    InkWell(
                      onTap: () => onChanged(null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: const Color(0xFF115343).withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}



