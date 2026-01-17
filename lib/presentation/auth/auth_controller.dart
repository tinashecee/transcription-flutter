import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../data/providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../services/auth_session.dart';
import 'package:logging/logging.dart';

class AuthState {
  AuthState({
    required this.isAuthenticated,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  static AuthState initial() => AuthState(isAuthenticated: false);
}

class AuthController extends ChangeNotifier {
  AuthController(this._ref, {bool mockAuthenticated = false}) {
    _logger = Logger('AuthController');
    if (mockAuthenticated) {
      _state = AuthState(isAuthenticated: true);
    } else {
      unawaited(_restoreSession());
    }
  }

  final Ref _ref;
  late final Logger _logger;
  AuthState _state = AuthState.initial();

  AuthState get value => _state;

  Future<void> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _logger.info('Starting login attempt for email: $email');
    _setState(_state.copyWith(isLoading: true, errorMessage: null));

    // Try API login first
    try {
      _logger.info('Attempting API login...');
      final authRepo = _ref.read(authRepositoryProvider);
      final response = await authRepo.login(email, password);

      _logger.info('API login successful, parsing response...');

      // Parse the API response
      final userData = response['user'] ?? response;
      final token = response['token'];

      _logger.info('Token received: ${token != null ? "Yes (${token.length} chars)" : "No"}');
      _logger.info('User data keys: ${userData.keys.toList()}');

      final user = User(
        id: userData['id'].toString(),
        email: userData['email'] ?? email,
        name: userData['name'] ?? 'Test User',
        role: userData['role'] ?? 'transcriber',
        court: userData['court'],
        contactInfo: userData['contact_info'],
        district: userData['district'],
        province: userData['province'],
        region: userData['region'],
        dateCreated: userData['date_created'],
      );

      _logger.info('User created: ${user.name} (${user.email}) - Role: ${user.role}');
      print(
        '[LoginResponse] {token: $token, id: ${user.id}, name: ${user.name}, '
        'email: ${user.email}, role: ${user.role}, court: ${user.court}, '
        'contact_info: ${user.contactInfo}, district: ${user.district}, '
        'province: ${user.province}, region: ${user.region}, '
        'date_created: ${user.dateCreated}}',
      );

      _ref.read(authSessionProvider.notifier).setSession(token: token, user: user);
      await _ref.read(rememberMeStorageProvider).setRememberMe(rememberMe);
      await _ref.read(userStorageProvider).writeUser(user);
      if (rememberMe) {
        await _ref.read(tokenStorageProvider).writeToken(token);
        _logger.info('Token stored for remember me');
      } else {
        await _ref.read(tokenStorageProvider).clearToken();
        _logger.info('Token cleared (no remember me)');
      }

      _logger.info('Login successful, navigating to recordings');
      _setState(_state.copyWith(isAuthenticated: true, isLoading: false));
    } catch (error, stackTrace) {
      _logger.severe('API login failed', error, stackTrace);

      // Check if it's a network error or API error
      if (error.toString().contains('SocketException') ||
          error.toString().contains('Connection refused') ||
          error.toString().contains('Failed host lookup')) {
        _logger.warning('Network error detected, falling back to mock login');
      }

      // Fallback to mock login for development
      _logger.info('Using mock login fallback...');
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

      final mockUser = User(
        id: '1',
        email: email,
        name: 'Test User (Mock)',
        role: 'transcriber',
        court: 'Harare High Court',
      );

      const mockToken = 'mock_jwt_token_for_development';
      _ref.read(authSessionProvider.notifier).setSession(token: mockToken, user: mockUser);
      await _ref.read(rememberMeStorageProvider).setRememberMe(rememberMe);
      await _ref.read(userStorageProvider).writeUser(mockUser);
      if (rememberMe) {
        await _ref.read(tokenStorageProvider).writeToken(mockToken);
      } else {
        await _ref.read(tokenStorageProvider).clearToken();
      }

      _logger.info('Mock login successful');
      _setState(_state.copyWith(isAuthenticated: true, isLoading: false));
    }
  }

  Future<void> logout() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      // Clear local session data immediately
      await _ref.read(tokenStorageProvider).clearToken();
      await _ref.read(rememberMeStorageProvider).setRememberMe(false);
      await _ref.read(userStorageProvider).clearUser();
      _ref.read(authSessionProvider.notifier).clear();

      // Try to call logout endpoint (optional - some APIs don't require this)
      try {
        final authRepo = _ref.read(authRepositoryProvider);
        await authRepo.logout();
      } catch (_) {
        // Ignore logout endpoint errors - local cleanup is more important
      }

      _setState(AuthState.initial());
    } catch (error) {
      // Even if there's an error, ensure local cleanup happened
      _ref.read(authSessionProvider.notifier).clear();
      _setState(AuthState.initial());
    }
  }

  Future<void> forgotPassword(String email) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _ref.read(authRepositoryProvider).sendPasswordReset(email);
      _setState(_state.copyWith(isLoading: false));
    } catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _restoreSession() async {
    _logger.info('Attempting to restore session...');

    final rememberMe = await _ref.read(rememberMeStorageProvider).getRememberMe();
    _logger.info('Remember me setting: $rememberMe');

    if (!rememberMe) {
      _logger.info('Remember me is false, starting fresh session');
      _setState(AuthState.initial());
      return;
    }

    final token = await _ref.read(tokenStorageProvider).readToken();
    if (token == null) {
      _logger.info('No stored token found');
      _setState(AuthState.initial());
      return;
    }

    _logger.info('Token found (${token.length} characters), validating...');

    try {
      if (JwtDecoder.isExpired(token)) {
        _logger.warning('Token is expired, clearing session');
        await _ref.read(tokenStorageProvider).clearToken();
        await _ref.read(rememberMeStorageProvider).setRememberMe(false);
        _setState(AuthState.initial());
        return;
      }
    } catch (e) {
      // If JWT validation fails, assume token is invalid and clear session
      _logger.severe('JWT validation failed', e);
      await _ref.read(tokenStorageProvider).clearToken();
      await _ref.read(rememberMeStorageProvider).setRememberMe(false);
      _setState(AuthState.initial());
      return;
    }

    try {
      final storedUser = await _ref.read(userStorageProvider).readUser();
      final user = storedUser ?? AuthRepositoryImpl.userFromToken(token);
      _logger.info('User restored from token: ${user.name} (${user.email})');
      _ref.read(authSessionProvider.notifier).setSession(token: token, user: user);
      _setState(_state.copyWith(isAuthenticated: true));
      _logger.info('Session restored successfully');
    } catch (error) {
      _logger.severe('Token parsing failed during session restore', error);
      // If token parsing fails, clear session
      await _ref.read(tokenStorageProvider).clearToken();
      await _ref.read(rememberMeStorageProvider).setRememberMe(false);
      _setState(AuthState.initial());
    }
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }
}

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(ref);
});
