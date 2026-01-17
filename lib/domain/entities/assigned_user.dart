class AssignedUser {
  const AssignedUser({
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
}
