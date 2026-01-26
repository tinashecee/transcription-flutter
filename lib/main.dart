import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'app/providers.dart';
import 'services/logging_service.dart';
import 'services/update_manager.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();

  // Initialize window manager and set to maximized
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize();
    await windowManager.show();
  });

  final config = await AppConfig.load();
  final loggingService = LoggingService();
  await loggingService.init();

  // Initialize UpdateManager
  await UpdateManager.initInstalledVersion();

  // Enable console logging for debugging
  setupConsoleLogging();


  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        loggingServiceProvider.overrideWithValue(loggingService),
        // Remove mock authentication overrides - now using real API
      ],
      child: const TestimonyApp(),
    ),
  );
}
