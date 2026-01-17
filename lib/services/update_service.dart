import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../data/api/api_client.dart';

class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.url,
    required this.mandatory,
  });

  final String version;
  final String url;
  final bool mandatory;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '',
      url: json['url'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class UpdateService {
  UpdateService(this._client);

  final ApiClient _client;

  Future<UpdateInfo?> checkForUpdates() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/api/check-updates',
    );
    final data = response.data;
    if (data == null || data.isEmpty) return null;
    return UpdateInfo.fromJson(data);
  }

  Future<File> downloadUpdate(String url) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}update.bin');
    final dio = Dio();
    await dio.download(url, file.path);
    return file;
  }
}
