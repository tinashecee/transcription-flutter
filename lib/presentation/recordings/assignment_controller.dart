import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../services/auth_session.dart';
import '../../domain/entities/assignment.dart';

class AssignmentState {
  AssignmentState({
    required this.isLoading,
    this.assignment,
    this.errorMessage,
  });

  final bool isLoading;
  final Assignment? assignment;
  final String? errorMessage;

  AssignmentState copyWith({
    bool? isLoading,
    Assignment? assignment,
    String? errorMessage,
  }) {
    return AssignmentState(
      isLoading: isLoading ?? this.isLoading,
      assignment: assignment ?? this.assignment,
      errorMessage: errorMessage,
    );
  }

  factory AssignmentState.initial() =>
      AssignmentState(isLoading: false, assignment: null);
}

class AssignmentController extends StateNotifier<AssignmentState> {
  AssignmentController(this._ref) : super(AssignmentState.initial());

  final Ref _ref;

  Future<void> load(String recordingId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final assignment =
          await _ref.read(assignmentRepositoryProvider).getAssignment(recordingId);
      state = state.copyWith(isLoading: false, assignment: assignment);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> assign(String recordingId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final userId = _ref.read(authSessionProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'User session not found',
      );
      return;
    }
    await _ref
        .read(assignmentRepositoryProvider)
        .assignRecording(recordingId, userId: userId);
    await load(recordingId);
  }

  Future<void> unassign(String recordingId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final userId = _ref.read(authSessionProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'User session not found',
      );
      return;
    }
    await _ref
        .read(assignmentRepositoryProvider)
        .unassignRecording(recordingId, userId: userId);
    await load(recordingId);
  }
}

final assignmentControllerProvider =
    StateNotifierProvider<AssignmentController, AssignmentState>((ref) {
  return AssignmentController(ref);
});
