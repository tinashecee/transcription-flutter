import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../presentation/auth/login_screen.dart';
import '../presentation/auth/splash_screen.dart';
import '../presentation/auth/forgot_password_screen.dart';
import '../presentation/auth/auth_controller.dart';
import '../presentation/auth/auth_layout.dart';
import '../presentation/layout/dashboard_layout.dart';
import '../presentation/recordings/recordings_screen.dart';
import '../presentation/recordings/recording_detail_screen.dart';
import '../presentation/system/system_status_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authState,
    redirect: (context, state) {
      final isLogin = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';
      final isForgot = state.matchedLocation == '/forgot-password';
      final isAuthed = authState.value.isAuthenticated;

      if (!isAuthed && !isLogin && !isSplash && !isForgot) {
        return '/login';
      }

      if (isAuthed && (isLogin || isSplash || isForgot)) {
        return '/recordings';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth Shell for consistent background and header/footer
      ShellRoute(
        builder: (context, state, child) {
          return AuthLayout(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),

      // Dashboard Shell for persistent sidebar and layout
      ShellRoute(
        builder: (context, state, child) {
          return DashboardLayout(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/recordings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RecordingsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return RecordingDetailScreen(recordingId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/system-status',
            builder: (context, state) => const SystemStatusScreen(),
          ),
        ],
      ),
    ],
  );
});
