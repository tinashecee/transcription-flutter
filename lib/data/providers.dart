import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../services/auth_session.dart';
import '../services/word_export_service.dart';
import 'api/api_client.dart';
import 'repositories/auth_repository_impl.dart';
import 'repositories/assignment_repository_impl.dart';
import 'repositories/comment_repository_impl.dart';
import 'repositories/recording_repository_impl.dart';
import 'repositories/status_repository_impl.dart';
import 'repositories/transcript_repository_impl.dart';
import 'storage/secure_storage.dart';
import '../services/update_service.dart';

final tokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final rememberMeStorageProvider = Provider<RememberMeStorage>((ref) {
  return RememberMeStorage();
});

final userStorageProvider = Provider<UserStorage>((ref) {
  return UserStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final session = ref.watch(authSessionProvider);
  return ApiClient(
    config: config,
    tokenProvider: () async => session.token,
  );
});

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(ref.watch(apiClientProvider));
});

final recordingRepositoryProvider = Provider<RecordingRepositoryImpl>((ref) {
  return RecordingRepositoryImpl(ref.watch(apiClientProvider));
});

final assignmentRepositoryProvider = Provider<AssignmentRepositoryImpl>((ref) {
  return AssignmentRepositoryImpl(ref.watch(apiClientProvider));
});

final commentRepositoryProvider = Provider<CommentRepositoryImpl>((ref) {
  return CommentRepositoryImpl(ref.watch(apiClientProvider));
});

final statusRepositoryProvider = Provider<StatusRepositoryImpl>((ref) {
  return StatusRepositoryImpl(ref.watch(apiClientProvider));
});

final transcriptRepositoryProvider = Provider<TranscriptRepositoryImpl>((ref) {
  return TranscriptRepositoryImpl(ref.watch(apiClientProvider));
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ref.watch(apiClientProvider));
});

final wordExportServiceProvider = Provider<WordExportService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WordExportService(
    dio: apiClient.dio,
  );
});
