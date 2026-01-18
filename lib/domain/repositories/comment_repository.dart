import '../entities/comment.dart';

abstract class CommentRepository {
  Future<List<Comment>> listComments(String recordingId);
  Future<Comment> createComment({
    required String recordingId,
    required String content,
    required String commentType,
    required String commenterId,
  });
}
