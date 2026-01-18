import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String notes;
  final String url;

  UpdateInfo({
    required this.version,
    required this.notes,
    required this.url,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      notes: json['notes'] as String,
      url: json['url'] as String,
    );
  }
}

enum DownloadStatus { idle, starting, downloading, downloaded, failed }

class UpdateManager {
  static const String _checkUrl = 'https://api.testimony.co.zw/check-transcriber_updates';
  
  static String? appDisplayVersion;
  static List<int>? appSemver;
  static UpdateInfo? _cachedLatest;
  
  static final StreamController<Map<String, dynamic>> _progressController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get progressStream => _progressController.stream;
  
  static DownloadStatus _downloadStatus = DownloadStatus.idle;
  static DownloadStatus get downloadStatus => _downloadStatus;

  /// Initialize the installed app version
  static Future<void> initInstalledVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appDisplayVersion = packageInfo.version;
      appSemver = _parseVersion(appDisplayVersion!);
      print('[UpdateManager] Installed version: $appDisplayVersion');
    } catch (e) {
      print('[UpdateManager] Error reading version: $e');
      appDisplayVersion = '0.0.0';
      appSemver = [0, 0, 0];
    }
  }

  /// Parse semantic version string into [major, minor, patch]
  static List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0,
    ];
  }

  /// Fetch latest update info from server
  static Future<UpdateInfo?> fetchUpdateInfo() async {
    if (!Platform.isWindows) return null;

    try {
      print('[UpdateManager] Checking for updates...');
      final response = await http.get(Uri.parse(_checkUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _cachedLatest = UpdateInfo.fromJson(data);
        print('[UpdateManager] Latest version: ${_cachedLatest?.version}');
        return _cachedLatest;
      } else {
        print('[UpdateManager] Update check failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[UpdateManager] Update check error: $e');
      return null;
    }
  }

  /// Check if remote version is newer than installed version
  static bool isNewer(String remoteVersion) {
    if (appSemver == null) return false;

    final remoteSemver = _parseVersion(remoteVersion);
    
    // Compare major.minor.patch
    for (int i = 0; i < 3; i++) {
      if (remoteSemver[i] > appSemver![i]) return true;
      if (remoteSemver[i] < appSemver![i]) return false;
    }
    
    return false; // Versions are equal
  }

  /// Check for updates and show prompt dialog if available
  static Future<void> checkForUpdatesAndPrompt(BuildContext context) async {
    if (!Platform.isWindows) return;

    final updateInfo = await fetchUpdateInfo();
    if (updateInfo == null) {
      print('[UpdateManager] No update info available');
      return;
    }

    if (!isNewer(updateInfo.version)) {
      print('[UpdateManager] Already up to date');
      return;
    }

    if (!context.mounted) return;

    // Show update dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('New version available (${updateInfo.version})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current version: $appDisplayVersion',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Release Notes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(updateInfo.notes),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstall(context, updateInfo);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  /// Download the installer and prepare for installation
  static Future<void> _downloadAndInstall(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    _downloadStatus = DownloadStatus.starting;
    _progressController.add({'status': 'starting', 'progress': 0.0});

    try {
      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      
      // Extract filename from URL or use default
      String filename = updateInfo.url.split('/').last;
      if (!filename.endsWith('.exe')) {
        filename = 'transcriber_update.exe';
      }
      
      // Sanitize filename for Windows
      filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = '${tempDir.path}/$filename';
      
      print('[UpdateManager] Downloading to: $filePath');
      
      // Start download
      _downloadStatus = DownloadStatus.downloading;
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(updateInfo.url));
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }
      
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      final file = File(filePath);
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        
        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          _progressController.add({
            'status': 'downloading',
            'progress': progress,
            'received': receivedBytes,
            'total': totalBytes,
          });
        } else {
          _progressController.add({
            'status': 'downloading',
            'progress': 0.0,
            'received': receivedBytes,
          });
        }
      }
      
      await sink.close();
      client.close();
      
      _downloadStatus = DownloadStatus.downloaded;
      _progressController.add({'status': 'downloaded', 'progress': 1.0, 'path': filePath});
      
      print('[UpdateManager] Download complete: $filePath');
      
      // Show installation prompt
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Ready to Install'),
          content: const Text(
            'The update has been downloaded. The app will close and install the update.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _runInstallerAndExit(filePath);
              },
              child: const Text('Install'),
            ),
          ],
        ),
      );
      
    } catch (e, stack) {
      print('[UpdateManager] Download error: $e');
      print(stack);
      _downloadStatus = DownloadStatus.failed;
      _progressController.add({'status': 'failed', 'error': e.toString()});
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Run the installer and exit the app
  static Future<void> _runInstallerAndExit(String exePath) async {
    try {
      print('[UpdateManager] Launching installer: $exePath');
      await Process.start(exePath, [], mode: ProcessStartMode.detached);
      exit(0);
    } catch (e) {
      print('[UpdateManager] Failed to launch installer: $e');
    }
  }

  /// Manual update check (for update page)
  static Future<bool> checkForUpdatesManual(BuildContext context) async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updates are only available on Windows')),
      );
      return false;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final updateInfo = await fetchUpdateInfo();
    
    if (!context.mounted) return false;
    Navigator.of(context).pop(); // Close loading

    if (updateInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to check for updates')),
      );
      return false;
    }

    if (!isNewer(updateInfo.version)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already running the latest version')),
      );
      return false;
    }

    // Show update available dialog
    checkForUpdatesAndPrompt(context);
    return true;
  }
}
