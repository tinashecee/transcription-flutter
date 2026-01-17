import '../../domain/entities/assignment.dart';
import '../../domain/entities/assigned_user.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/assignment_repository.dart';
import '../api/api_client.dart';
import '../cache/ttl_cache.dart';
import '../models/assigned_user_model.dart';
import '../models/assignment_model.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  AssignmentRepositoryImpl(this._client)
      : _assignmentsCache = TtlCache<List<Assignment>>(
          const Duration(seconds: 30),
        ),
        _assignedUsersCache = TtlCache<List<AssignedUser>>(
          const Duration(seconds: 30),
        ),
        _usersByEmailCache = TtlCache<Map<String, String>>(
          const Duration(minutes: 5),
        ),
        _availableUsersCache = TtlCache<List<User>>(
          const Duration(minutes: 5),
        );

  final ApiClient _client;
  final TtlCache<List<Assignment>> _assignmentsCache;
  final TtlCache<List<AssignedUser>> _assignedUsersCache;
  final TtlCache<Map<String, String>> _usersByEmailCache;
  final TtlCache<List<User>> _availableUsersCache;

  @override
  Future<void> assignRecording(
    String recordingId, {
    required String userId,
    String type = 'self_assigned',
  }) async {
    await _client.dio.post(
      '/add_transcription_user',
      data: {
        'case_id': recordingId,
        'user_id': userId,
        'type': type,
      },
    );
    _assignmentsCache.clear();
    _assignedUsersCache.clear();
  }

  @override
  Future<void> unassignRecording(String recordingId, {required String userId}) async {
    // Find assignment id for this user + case
    final assignmentsResponse = await _client.dio.get<List<dynamic>>(
      '/transcription_users/$recordingId',
    );
    final assignments = assignmentsResponse.data ?? const [];
    final match = assignments.cast<Map<String, dynamic>>().firstWhere(
          (a) => a['user_id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );
    final assignmentId = match['id']?.toString();
    if (assignmentId == null || assignmentId.isEmpty) {
      return;
    }
    await _client.dio.delete('/transcription_users/$assignmentId');
    _assignmentsCache.clear();
    _assignedUsersCache.clear();
  }

  @override
  Future<Assignment?> getAssignment(String recordingId) async {
    final response =
        await _client.dio.get<Map<String, dynamic>>('/api/assignments/$recordingId');
    final data = response.data;
    if (data == null) return null;
    return AssignmentModel.fromJson(data).toEntity();
  }

  @override
  Future<List<Assignment>> getMyAssignments() async {
    final cached = _assignmentsCache.get('my_assignments');
    if (cached != null) return cached;
    final response =
        await _client.dio.get<List<dynamic>>('/api/my-assignments');
    final items = response.data
            ?.map((json) => AssignmentModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList() ??
        [];
    _assignmentsCache.set('my_assignments', items);
    return items;
  }

  @override
  Future<List<AssignedUser>> getAssignedUsers(String recordingId) async {
    final cacheKey = 'assigned_users:$recordingId';
    final cached = _assignedUsersCache.get(cacheKey);
    if (cached != null) return cached;

    final response = await _client.dio.get<List<dynamic>>(
      '/transcription_users/$recordingId',
    );
    var items = response.data
            ?.map((json) =>
                AssignedUserModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList() ??
        [];

    // Resolve missing names using /users email->name map when available
    final usersByEmail = await _getUsersByEmail();
    if (usersByEmail.isNotEmpty) {
      items = items.map((user) {
        if (user.name.trim().isNotEmpty) return user;
        final emailKey = user.email.trim().toLowerCase();
        final resolvedName = usersByEmail[emailKey];
        if (resolvedName == null || resolvedName.trim().isEmpty) {
          return user;
        }
        return AssignedUser(
          id: user.id,
          userId: user.userId,
          name: resolvedName,
          email: user.email,
          assignedAt: user.assignedAt,
          type: user.type,
        );
      }).toList();
    }
    _assignedUsersCache.set(cacheKey, items);
    return items;
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    await _client.dio.delete('/transcription_users/$assignmentId');
    _assignmentsCache.clear();
    _assignedUsersCache.clear();
  }

  @override
  Future<List<User>> getAvailableUsers() async {
    final cached = _availableUsersCache.get('available_users');
    if (cached != null) return cached;
    final response = await _client.dio.get<List<dynamic>>('/users');
    final items = response.data
            ?.map((json) => json as Map<String, dynamic>)
            .map(
              (data) => User(
                id: data['id']?.toString() ?? '',
                name: data['name'] as String? ?? '',
                email: data['email'] as String? ?? '',
                role: data['role'] as String? ?? '',
                court: data['court'] as String?,
              ),
            )
            .where((user) => user.id.isNotEmpty)
            .where((user) => _isAssignableRole(user.role))
            .toList() ??
        [];
    _availableUsersCache.set('available_users', items);
    return items;
  }

  Future<Map<String, String>> _getUsersByEmail() async {
    final cached = _usersByEmailCache.get('users_by_email');
    if (cached != null) return cached;
    try {
      final response = await _client.dio.get<List<dynamic>>('/users');
      final map = <String, String>{};
      for (final raw in response.data ?? const []) {
        final data = raw as Map<String, dynamic>;
        final email = (data['email'] as String?)?.trim().toLowerCase();
        if (email == null || email.isEmpty) continue;
        final name = (data['name'] as String?)?.trim();
        map[email] = (name == null || name.isEmpty) ? email : name;
      }
      _usersByEmailCache.set('users_by_email', map);
      return map;
    } catch (_) {
      _usersByEmailCache.set('users_by_email', const {});
      return const {};
    }
  }

  @override
  Future<void> bulkAssign(List<String> recordingIds) async {
    await _client.dio.post(
      '/api/assignments/bulk',
      data: {'recording_ids': recordingIds},
    );
    _assignmentsCache.clear();
    _assignedUsersCache.clear();
    _availableUsersCache.clear();
  }

  bool _isAssignableRole(String role) {
    final normalized = role.trim().toLowerCase();
    return normalized == 'transcriber' ||
        normalized == 'court_recorder' ||
        normalized == 'admin' ||
        normalized == 'super_admin' ||
        normalized == 'superadmin';
  }
}
