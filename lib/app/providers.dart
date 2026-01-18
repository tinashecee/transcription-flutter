import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import '../services/logging_service.dart';
import '../services/foot_pedal_service.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('AppConfig not loaded');
});

final loggingServiceProvider = Provider<LoggingService>((ref) {
  throw UnimplementedError('LoggingService not initialized');
});

final footPedalServiceProvider = Provider<FootPedalService>((ref) {
  final config = ref.watch(appConfigProvider);
  final service = FootPedalService(url: config.pedalWebSocketUrl);
  ref.onDispose(service.dispose);
  return service;
});

final footPedalStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(footPedalServiceProvider);
  service.start();
  return service.connectionStatus;
});
