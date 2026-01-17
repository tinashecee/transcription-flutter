import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';

class SecureTokenStorage {
  static const _tokenKey = 'auth_token';

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

class RememberMeStorage {
  static const _rememberKey = 'remember_me';

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, value);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? false;
  }
}

class UserStorage {
  static const _userKey = 'auth_user';

  Future<void> writeUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'court': user.court,
      'contact_info': user.contactInfo,
      'district': user.district,
      'province': user.province,
      'region': user.region,
      'date_created': user.dateCreated,
    };
    await prefs.setString(_userKey, jsonEncode(payload));
  }

  Future<User?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return User(
        id: data['id']?.toString() ?? '',
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
        role: data['role'] as String? ?? '',
        court: data['court'] as String?,
        contactInfo: data['contact_info'] as String?,
        district: data['district'] as String?,
        province: data['province'] as String?,
        region: data['region'] as String?,
        dateCreated: data['date_created']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
