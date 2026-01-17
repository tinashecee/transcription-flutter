import '../../domain/entities/comment.dart';

class CommentModel {
  CommentModel({
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

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'].toString(),
      recordingId: json['recording_id'].toString(),
      userId: json['user_id'].toString(),
      body: json['body'] as String? ?? '',
      timestampSeconds: (json['timestamp_seconds'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Comment toEntity() => Comment(
        id: id,
        recordingId: recordingId,
        userId: userId,
        body: body,
        timestampSeconds: timestampSeconds,
        createdAt: createdAt,
      );
}
