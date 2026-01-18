import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../api/api_client.dart';
import '../models/comment_model.dart';

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Comment>> listComments(String recordingId) async {
    final response = await _client.dio
        .get<List<dynamic>>('/transcript_comments/$recordingId');
    return response.data
            ?.map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
            .map((model) => model.toEntity())
            .toList() ??
        [];
  }

  @override
  Future<Comment> createComment({
    required String recordingId,
    required String content,
    required String commentType,
    required String commenterId,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/add_transcription_comment',
      data: {
        'case_id': int.parse(recordingId),
        'commenter': int.parse(commenterId),
        'comment_type': commentType,
        'comment_text': content,
      },
    );
    return CommentModel.fromJson(response.data ?? {}).toEntity();
  }
}
