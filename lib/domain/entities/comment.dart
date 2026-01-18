class Comment {
  const Comment({
    required this.id,
    required this.recordingId,
    required this.authorName,
    required this.authorEmail,
    required this.commentType,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String recordingId;
  final String authorName;
  final String authorEmail;
  final String commentType;
  final String content;
  final DateTime createdAt;
}
