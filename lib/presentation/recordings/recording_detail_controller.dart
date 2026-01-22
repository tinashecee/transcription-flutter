import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../data/providers.dart';
import '../../domain/entities/recording.dart';
import 'recordings_controller.dart';

final recordingDetailProvider =
    FutureProvider.family<Recording, String>((ref, id) async {
  final repo = ref.read(recordingRepositoryProvider);
  
  // 1. Fetch fresh details from API
  final freshRecording = await repo.fetchRecording(id);

  // 2. Try to find the recording in the loaded list (Dashboard/Recordings list)
  final listState = ref.watch(recordingsControllerProvider);
  final cachedRecording = listState.items.firstWhereOrNull((r) => r.id == id);

  // 3. AGGRESSIVE PATCH: Always prefer the list's status if available.
  // The user confirms the list is the source of truth, but the detail API is broken.
  if (cachedRecording != null && cachedRecording.status != freshRecording.status) {
    return freshRecording.copyWith(status: cachedRecording.status);
  }

  return freshRecording;
});
