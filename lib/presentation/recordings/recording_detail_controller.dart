import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/recording.dart';

final recordingDetailProvider =
    FutureProvider.family<Recording, String>((ref, id) async {
  final repo = ref.read(recordingRepositoryProvider);
  return repo.fetchRecording(id);
});
