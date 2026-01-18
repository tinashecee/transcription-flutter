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
    // NO CACHING - Always fetch fresh
    print('[AssignmentRepo] GET /transcription_users/$recordingId (NO CACHE)');
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
    // Users by email can be cached - it's reference data
    if (_usersByEmailCache != null) return _usersByEmailCache!;
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
      _usersByEmailCache = map;
      return map;
    } catch (_) {
      _usersByEmailCache = const {};
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
