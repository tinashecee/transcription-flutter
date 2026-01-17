class Comment {
  const Comment({
    required this.id,
    required this.recordingId,
    required this.userId,
    required this.body,
    required this.timestampSeconds,
    required this.createdAt,
  });

  final String id;
  final String recordingId;
  final String userId;
  final String body;
  final int timestampSeconds;
  final DateTime createdAt;
}
