import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'app/providers.dart';
import 'services/logging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();
  final loggingService = LoggingService();
  await loggingService.init();

  // Enable console logging for debugging
  setupConsoleLogging();


  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        loggingServiceProvider.overrideWithValue(loggingService),
        // Remove mock authentication overrides - now using real API
      ],
      child: const TranscriberApp(),
    ),
  );
}
