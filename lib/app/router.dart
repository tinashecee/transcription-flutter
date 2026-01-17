import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/auth/login_screen.dart';
import '../presentation/auth/auth_controller.dart';
import '../presentation/recordings/recordings_screen.dart';
import '../presentation/recordings/recording_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login', // Start with login page
    refreshListenable: authState,
    redirect: (context, state) {
      final isLogin = state.matchedLocation == '/login';
      final isAuthed = authState.value.isAuthenticated;
      if (!isAuthed && !isLogin) {
        return '/login';
      }
      if (isAuthed && isLogin) {
        return '/recordings';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/recordings',
        builder: (context, state) => const RecordingsScreen(),
      ),
      GoRoute(
        path: '/recordings/:id',
        builder: (context, state) => RecordingDetailScreen(
          recordingId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
