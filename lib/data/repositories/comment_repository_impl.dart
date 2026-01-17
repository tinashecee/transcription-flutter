import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../api/api_client.dart';
import '../models/comment_model.dart';

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Comment>> listComments(String recordingId) async {
    final response =
        await _client.dio.get<List<dynamic>>('/api/comments/$recordingId');
    return response.data
            ?.map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList() ??
        [];
  }

  @override
  Future<Comment> createComment({
    required String recordingId,
    required String body,
    required int timestampSeconds,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/api/comments/$recordingId',
      data: {
        'body': body,
        'timestamp_seconds': timestampSeconds,
      },
    );
    return CommentModel.fromJson(response.data ?? {}).toEntity();
  }

  @override
  Future<Comment> updateComment({
    required String commentId,
    required String body,
  }) async {
    final response = await _client.dio.put<Map<String, dynamic>>(
      '/api/comments/$commentId',
      data: {'body': body},
    );
    return CommentModel.fromJson(response.data ?? {}).toEntity();
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.dio.delete('/api/comments/$commentId');
  }
}
