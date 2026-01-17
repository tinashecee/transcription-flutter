import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/user.dart';

class AuthSession {
  const AuthSession({
    this.token,
    this.user,
  });

  final String? token;
  final User? user;

  bool get isAuthenticated => token != null;
}

class AuthSessionController extends StateNotifier<AuthSession> {
  AuthSessionController() : super(const AuthSession());

  void setSession({required String token, required User user}) {
    state = AuthSession(token: token, user: user);
  }

  void clear() {
    state = const AuthSession();
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionController, AuthSession>((ref) {
  return AuthSessionController();
});
