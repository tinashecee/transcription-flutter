import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class StatusController extends StateNotifier<AsyncValue<void>> {
  StatusController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> updateStatus(String recordingId, String status) async {
    state = const AsyncValue.loading();
    try {
      await _ref
          .read(statusRepositoryProvider)
          .updateStatus(recordingId: recordingId, status: status);
      state = const AsyncValue.data(null);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}

final statusControllerProvider =
    StateNotifierProvider<StatusController, AsyncValue<void>>((ref) {
  return StatusController(ref);
});
