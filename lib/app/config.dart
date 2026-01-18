import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.audioBaseUrl,
    required this.pedalWebSocketUrl,
  });

  final String apiBaseUrl;
  final String audioBaseUrl;
  final String pedalWebSocketUrl;

  static Future<AppConfig> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      if (raw.isEmpty) {
        throw Exception('Config file is empty');
      }

      final map = jsonDecode(raw) as Map<String, dynamic>;

      final apiBaseUrl = map['apiBaseUrl'] as String?;
      final audioBaseUrl = map['audioBaseUrl'] as String?;
      final pedalWebSocketUrl = map['pedalWebSocketUrl'] as String?;

      if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
        throw Exception('apiBaseUrl is missing or empty in config');
      }
      if (audioBaseUrl == null || audioBaseUrl.isEmpty) {
        throw Exception('audioBaseUrl is missing or empty in config');
      }
      if (pedalWebSocketUrl == null || pedalWebSocketUrl.isEmpty) {
        throw Exception('pedalWebSocketUrl is missing or empty in config');
      }

      return AppConfig(
        apiBaseUrl: apiBaseUrl,
        audioBaseUrl: audioBaseUrl,
        pedalWebSocketUrl: pedalWebSocketUrl,
      );
    } catch (e) {
      // Provide fallback config for development
      print('Failed to load config.json: $e');
      print('Using fallback configuration');

      return const AppConfig(
        apiBaseUrl: 'https://api.testimony.co.zw',
        audioBaseUrl: 'https://api.testimony.co.zw',
        pedalWebSocketUrl: 'ws://127.0.0.1:8080',
      );
    }
  }
}
