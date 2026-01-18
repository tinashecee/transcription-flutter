import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'recording_detail_controller.dart';
import 'recordings_controller.dart';

class StatusState {
  const StatusState({
    required this.isLoading,
    this.errorMessage,
    this.lastUpdatedStatus,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? lastUpdatedStatus;

  StatusState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? lastUpdatedStatus,
  }) {
    return StatusState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastUpdatedStatus: lastUpdatedStatus ?? this.lastUpdatedStatus,
    );
  }

  static const initial = StatusState(isLoading: false);
}

class StatusController extends StateNotifier<StatusState> {
  StatusController(this._ref) : super(StatusState.initial);

  final Ref _ref;

  Future<void> updateStatus(String recordingId, String status) async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      print('[StatusController] Updating status for $recordingId to $status');
      
      // Step 1: Call API and wait for response
      final response = await _ref
          .read(statusRepositoryProvider)
          .updateStatus(recordingId: recordingId, status: status);
      
      print('[StatusController] API returned: $response');
      
      // Step 2: Refresh the recording detail to get fresh data from API
      _ref.invalidate(recordingDetailProvider(recordingId));
      
      // Step 3: Also refresh recordings list
      await _ref.read(recordingsControllerProvider.notifier).loadInitial();
      
      state = state.copyWith(
        isLoading: false,
        lastUpdatedStatus: response['transcript_status'] as String?,
      );
      
      print('[StatusController] Status update completed');
    } catch (error) {
      print('[StatusController] Error: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }
}

final statusControllerProvider =
    StateNotifierProvider<StatusController, StatusState>((ref) {
  return StatusController(ref);
});
