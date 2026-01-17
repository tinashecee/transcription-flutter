import '../entities/assignment.dart';
import '../entities/assigned_user.dart';
import '../entities/user.dart';

abstract class AssignmentRepository {
  Future<void> assignRecording(
    String recordingId, {
    required String userId,
    String type,
  });
  Future<void> unassignRecording(String recordingId, {required String userId});
  Future<void> deleteAssignment(String assignmentId);
  Future<Assignment?> getAssignment(String recordingId);
  Future<List<Assignment>> getMyAssignments();
  Future<List<AssignedUser>> getAssignedUsers(String recordingId);
  Future<List<User>> getAvailableUsers();
  Future<void> bulkAssign(List<String> recordingIds);
}
