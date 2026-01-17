import '../entities/user.dart';

abstract class AuthRepository {
  Future<Map<String, dynamic>> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> sendPasswordReset(String email);
}
