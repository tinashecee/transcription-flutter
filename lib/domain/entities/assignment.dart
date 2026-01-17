class Assignment {
  const Assignment({
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
}
