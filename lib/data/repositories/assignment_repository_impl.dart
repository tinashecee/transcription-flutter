import '../../domain/entities/assignment.dart';
import '../../domain/entities/assigned_user.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/assignment_repository.dart';
import '../api/api_client.dart';
import '../models/assigned_user_model.dart';
import '../models/assignment_model.dart';
import 'package:dio/dio.dart';

/// Assignment repository - NO CACHING. All operations fetch fresh from API.
class AssignmentRepositoryImpl implements AssignmentRepository {
  AssignmentRepositoryImpl(this._client);

  final ApiClient _client;
  
  // Users list can be cached since it rarely changes during a session
  List<User>? _availableUsersCache;
  Map<String, String>? _usersByEmailCache;
  
  // Futures for request deduplication
  Future<Map<String, String>>? _usersByEmailFuture;
  final Map<String, Future<List<AssignedUser>>> _assignedUsersFutures = {};
  
  // Short-term cache for assigned users to prevent flooding during list scrolls/renders
  final Map<String, _CacheEntry<List<AssignedUser>>> _assignedUsersCache = {};
  static const _cacheDuration = Duration(seconds: 5);

  @override
  Future<void> assignRecording(
    String recordingId, {
    required String userId,
    String type = 'self_assigned',
  }) async {
    print('[AssignmentRepo] POST /add_transcription_user case_id=$recordingId user_id=$userId type=$type');
    final response = await _client.dio.post(
      '/add_transcription_user',
      data: {
        'case_id': recordingId,
        'user_id': userId,
        'date_assigned': DateTime.now().toIso8601String(),
        'type': type,
      },
    );
    print('[AssignmentRepo] assignRecording response: ${response.statusCode}');
  }

  @override
  Future<void> unassignRecording(String recordingId, {required String userId}) async {
    print('[AssignmentRepo] unassignRecording recordingId=$recordingId userId=$userId');
    // Find assignment id for this user + case
    final assignmentsResponse = await _client.dio.get<List<dynamic>>(
      '/transcription_users/$recordingId',
    );
    final assignments = assignmentsResponse.data ?? const [];
    print('[AssignmentRepo] found ${assignments.length} assignments for case $recordingId');
    final match = assignments.cast<Map<String, dynamic>>().firstWhere(
          (a) => a['user_id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );
    final assignmentId = match['id']?.toString();
    if (assignmentId == null || assignmentId.isEmpty) {
      print('[AssignmentRepo] no matching assignment found for userId=$userId');
      return;
    }
    print('[AssignmentRepo] DELETE /transcription_users/$assignmentId');
    final deleteResponse = await _client.dio.delete('/transcription_users/$assignmentId');
    print('[AssignmentRepo] unassignRecording response: ${deleteResponse.statusCode}');
  }

  @override
  Future<Assignment?> getAssignment(String recordingId) async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/assignments/$recordingId');
      final data = response.data;
      if (data == null) return null;
      return AssignmentModel.fromJson(data).toEntity();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) {
        print('[AssignmentRepository] getAssignment 404 for $recordingId');
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<Assignment>> getMyAssignments() async {
    // NO CACHING - Always fetch fresh
    print('[AssignmentRepo] GET /api/my-assignments (NO CACHE)');
    final response =
        await _client.dio.get<List<dynamic>>('/api/my-assignments');
    final items = response.data
            ?.map((json) => AssignmentModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList() ??
        [];
    print('[AssignmentRepo] getMyAssignments returned ${items.length} items');
    return items;
  }

  @override
  Future<List<AssignedUser>> getAssignedUsers(String recordingId) async {
    // 1. Check short-term cache
    final cached = _assignedUsersCache[recordingId];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    // 2. Check if there's an in-flight request for this recordingId
    if (_assignedUsersFutures.containsKey(recordingId)) {
      return _assignedUsersFutures[recordingId]!;
    }

    // 3. Start a new request and deduplicate
    final future = _fetchAssignedUsersInternal(recordingId);
    _assignedUsersFutures[recordingId] = future;

    try {
      final items = await future;
      _assignedUsersCache[recordingId] = _CacheEntry(items);
      return items;
    } finally {
      _assignedUsersFutures.remove(recordingId);
    }
  }

  Future<List<AssignedUser>> _fetchAssignedUsersInternal(String recordingId) async {
    print('[AssignmentRepo] GET /transcription_users/$recordingId (FETCHING)');
    final response = await _client.dio.get<List<dynamic>>(
      '/transcription_users/$recordingId',
    );
    var items = response.data
            ?.map((json) =>
                AssignedUserModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList() ??
        [];

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
    print('[AssignmentRepo] getAssignedUsers returned ${items.length} items');
    return items;
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    print('[AssignmentRepo] DELETE /transcription_users/$assignmentId');
    final response = await _client.dio.delete('/transcription_users/$assignmentId');
    print('[AssignmentRepo] deleteAssignment response: ${response.statusCode}');
  }

  @override
  Future<List<User>> getAvailableUsers() async {
    // Users list can be cached - it's reference data that rarely changes
    if (_availableUsersCache != null) return _availableUsersCache!;
    print('[AssignmentRepo] GET /users');
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
    _availableUsersCache = items;
    print('[AssignmentRepo] getAvailableUsers returned ${items.length} users');
    return items;
  }

  Future<Map<String, String>> _getUsersByEmail() async {
    // 1. Check cache
    if (_usersByEmailCache != null) return _usersByEmailCache!;
    
    // 2. Check in-flight request (deduplication)
    if (_usersByEmailFuture != null) return _usersByEmailFuture!;

    _usersByEmailFuture = _fetchUsersByEmailInternal();
    try {
      final result = await _usersByEmailFuture!;
      _usersByEmailCache = result;
      return result;
    } finally {
      _usersByEmailFuture = null;
    }
  }

  Future<Map<String, String>> _fetchUsersByEmailInternal() async {
    try {
      print('[AssignmentRepo] GET /users (FOR MAP)');
      final response = await _client.dio.get<List<dynamic>>('/users');
      final map = <String, String>{};
      for (final raw in response.data ?? const []) {
        final data = raw as Map<String, dynamic>;
        final email = (data['email'] as String?)?.trim().toLowerCase();
        if (email == null || email.isEmpty) continue;
        final name = (data['name'] as String?)?.trim();
        map[email] = (name == null || name.isEmpty) ? email : name;
      }
      return map;
    } catch (e) {
      print('[AssignmentRepo] _fetchUsersByEmailInternal error: $e');
      return const {};
    }
  }

  @override
  Future<void> bulkAssign(List<String> recordingIds) async {
    print('[AssignmentRepo] POST /api/assignments/bulk ids=${recordingIds.length}');
    final response = await _client.dio.post(
      '/api/assignments/bulk',
      data: {'recording_ids': recordingIds},
    );
    print('[AssignmentRepo] bulkAssign response: ${response.statusCode}');
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

class _CacheEntry<T> {
  _CacheEntry(this.value) : timestamp = DateTime.now();
  final T value;
  final DateTime timestamp;

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(seconds: 5);
}
