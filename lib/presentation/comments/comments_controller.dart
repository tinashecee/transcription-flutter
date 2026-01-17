import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/comment.dart';

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
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> addComment(String body, int timestampSeconds) async {
    final recordingId = _recordingId;
    if (recordingId == null) return;
    final repo = _ref.read(commentRepositoryProvider);
    await repo.createComment(
      recordingId: recordingId,
      body: body,
      timestampSeconds: timestampSeconds,
    );
    await load(recordingId);
  }

  Future<void> deleteComment(String commentId) async {
    await _ref.read(commentRepositoryProvider).deleteComment(commentId);
    final recordingId = _recordingId;
    if (recordingId != null) {
      await load(recordingId);
    }
  }

  Future<void> updateComment(String commentId, String body) async {
    await _ref
        .read(commentRepositoryProvider)
        .updateComment(commentId: commentId, body: body);
    final recordingId = _recordingId;
    if (recordingId != null) {
      await load(recordingId);
    }
  }
}

final commentsControllerProvider =
    StateNotifierProvider<CommentsController, CommentsState>((ref) {
  return CommentsController(ref);
});
