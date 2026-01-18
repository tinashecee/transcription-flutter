import '../../domain/entities/comment.dart';

class CommentModel {
  CommentModel({
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

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] as String?;
    return CommentModel(
      id: json['id'].toString(),
      recordingId: (json['case_id'] ?? json['recording_id']).toString(),
      authorName: json['commenter_name'] as String? ??
          json['author_name'] as String? ??
          'Unknown',
      authorEmail: json['commenter_email'] as String? ??
          json['author_email'] as String? ??
          'unknown@example.com',
      commentType: json['comment_type'] as String? ?? 'general',
      content: json['comment_text'] as String? ??
          json['content'] as String? ??
          '',
      createdAt: createdAtRaw == null || createdAtRaw.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.tryParse(createdAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Comment toEntity() => Comment(
        id: id,
        recordingId: recordingId,
        authorName: authorName,
        authorEmail: authorEmail,
        commentType: commentType,
        content: content,
        createdAt: createdAt,
      );
}
