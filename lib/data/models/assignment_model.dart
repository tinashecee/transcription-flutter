import '../../domain/entities/assignment.dart';

class AssignmentModel {
  AssignmentModel({
    required this.recordingId,
    required this.assignedTo,
    required this.assignedBy,
    required this.type,
    required this.assignedAt,
  });

  final String recordingId;
  final String assignedTo;
  final String assignedBy;
  final String type;
  final DateTime assignedAt;

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      recordingId: json['recording_id'].toString(),
      assignedTo: json['assigned_to'].toString(),
      assignedBy: json['assigned_by'].toString(),
      type: json['type'] as String? ?? 'self',
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  Assignment toEntity() => Assignment(
        recordingId: recordingId,
        assignedTo: assignedTo,
        assignedBy: assignedBy,
        type: type,
        assignedAt: assignedAt,
      );
}
