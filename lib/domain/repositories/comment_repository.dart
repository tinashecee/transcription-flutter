import '../entities/comment.dart';

abstract class CommentRepository {
  Future<List<Comment>> listComments(String recordingId);
  Future<Comment> createComment({
    required String recordingId,
    required String body,
    required int timestampSeconds,
  });
  Future<Comment> updateComment({
    required String commentId,
    required String body,
  });
  Future<void> deleteComment(String commentId);
}
