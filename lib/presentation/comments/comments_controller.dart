import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/comment.dart';
import '../../services/auth_session.dart';
import '../../services/dio_error_mapper.dart';

class CommentsState {
  CommentsState({
    required this.items,
    required this.isLoading,
    this.errorMessage,
  });

  final List<Comment> items;
  final bool isLoading;
  final String? errorMessage;

  CommentsState copyWith({
    List<Comment>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CommentsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory CommentsState.initial() =>
      CommentsState(items: const [], isLoading: false);
}

class CommentsController extends StateNotifier<CommentsState> {
  CommentsController(this._ref) : super(CommentsState.initial());

  final Ref _ref;
  String? _recordingId;

  Future<void> load(String recordingId) async {
    _recordingId = recordingId;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = _ref.read(commentRepositoryProvider);
      final items = await repo.listComments(recordingId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: mapDioError(error),
      );
    }
  }

  Future<void> addComment(String content, String commentType) async {
    final recordingId = _recordingId;
    if (recordingId == null) return;
    final commenterId = _ref.read(authSessionProvider).user?.id;
    if (commenterId == null) {
      state = state.copyWith(
        errorMessage: 'User session expired. Please log in again.',
      );
      return;
    }
    await _ref.read(commentRepositoryProvider).createComment(
          recordingId: recordingId,
          content: content,
          commentType: commentType,
          commenterId: commenterId,
        );
    await load(recordingId);
  }
}

final commentsControllerProvider =
    StateNotifierProvider<CommentsController, CommentsState>((ref) {
  return CommentsController(ref);
});
