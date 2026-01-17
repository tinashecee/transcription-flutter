import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import '../services/logging_service.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('AppConfig not loaded');
});

final loggingServiceProvider = Provider<LoggingService>((ref) {
  throw UnimplementedError('LoggingService not initialized');
});
