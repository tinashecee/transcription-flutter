import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/auth/login_screen.dart';
import '../presentation/auth/auth_controller.dart';
import '../presentation/recordings/recordings_screen.dart';
import '../presentation/recordings/recording_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login', // Start with login page
    refreshListenable: authState,
    observers: [
      _RouterLoggingObserver(),
    ],
    redirect: (context, state) {
      print('[Router] redirect check: '
          'location=${state.matchedLocation} '
          'full=${state.uri} '
          'isLogin=${state.matchedLocation == '/login'} '
          'isAuthed=${authState.value.isAuthenticated}');
      final isLogin = state.matchedLocation == '/login';
      final isAuthed = authState.value.isAuthenticated;
      if (!isAuthed && !isLogin) {
        print('[Router] redirect -> /login');
        return '/login';
      }
      if (isAuthed && isLogin) {
        print('[Router] redirect -> /recordings');
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

class _RouterLoggingObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('[Router] didPush: ${route.settings.name ?? route.settings} '
        'from=${previousRoute?.settings.name ?? previousRoute?.settings}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('[Router] didPop: ${route.settings.name ?? route.settings} '
        'to=${previousRoute?.settings.name ?? previousRoute?.settings}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    print('[Router] didReplace: '
        'new=${newRoute?.settings.name ?? newRoute?.settings} '
        'old=${oldRoute?.settings.name ?? oldRoute?.settings}');
  }
}
