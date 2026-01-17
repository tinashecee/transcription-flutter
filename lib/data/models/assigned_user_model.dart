import '../../domain/entities/assigned_user.dart';

class AssignedUserModel {
  AssignedUserModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.assignedAt,
    this.type,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final DateTime? assignedAt;
  final String? type;

  factory AssignedUserModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final userId = json['user_id']?.toString() ?? '';
    final name = json['user_name'] as String? ??
        json['name'] as String? ??
        json['username'] as String? ??
        '';
    final email = json['user_email'] as String? ??
        json['email'] as String? ??
        '';
    final assignedAtRaw = json['date_assigned'] as String?;
    final assignedAt = assignedAtRaw == null || assignedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(assignedAtRaw);
    final type = json['type'] as String?;
    return AssignedUserModel(
      id: id,
      userId: userId,
      name: name,
      email: email,
      assignedAt: assignedAt,
      type: type,
    );
  }

  AssignedUser toEntity() => AssignedUser(
        id: id,
        userId: userId,
        name: name,
        email: email,
        assignedAt: assignedAt,
        type: type,
      );
}
