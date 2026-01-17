import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../app/providers.dart';

// Add logging levels to console as well as file
void setupConsoleLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final level = record.level.name.padRight(7);
    final loggerName = record.loggerName.padRight(20);
    final message = record.message;

    final output = '[$time] [$level] [$loggerName] $message';

    if (record.error != null) {
      print('$output\nError: ${record.error}');
    } else {
      print(output);
    }

    if (record.stackTrace != null) {
      print('Stack trace:\n${record.stackTrace}');
    }
  });
}

class LoggingService {
  late final Logger logger;
  late final File _logFile;
  late final String _logFilePath;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _logFilePath = '${dir.path}${Platform.pathSeparator}transcriber.log';
    _logFile = File(_logFilePath);

    logger = Logger('Transcriber');
    logger.onRecord.listen((record) async {
      final line =
          '${record.time.toIso8601String()} [${record.level.name}] ${record.message}\n';
      await _logFile.writeAsString(line, mode: FileMode.append, flush: true);
    });
  }

  Future<String> getLogContents() async {
    try {
      if (await _logFile.exists()) {
        return await _logFile.readAsString();
      } else {
        return 'Log file does not exist yet. Try logging in first.';
      }
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  String getLogFilePath() => _logFilePath;
}

final logProvider = Provider<Logger>((ref) {
  final service = ref.watch(loggingServiceProvider);
  return service.logger;
});
