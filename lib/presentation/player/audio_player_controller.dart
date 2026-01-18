import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';

import '../../app/providers.dart';
import '../../services/auth_session.dart';

class AudioPlayerState {
  const AudioPlayerState({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
    );
  }

  static const initial = AudioPlayerState(
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    speed: 1.0,
  );
}

class AudioPlayerController extends StateNotifier<AudioPlayerState> {
  AudioPlayerController(this._ref) : super(AudioPlayerState.initial) {
  }

  final Ref _ref;
  late final Logger _logger = _ref.read(loggingServiceProvider).logger;
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;
  bool _isAvailable = true;
  int _loadAttempt = 0;

  AudioPlayer? _ensurePlayer() {
    if (!_isAvailable) return null;
    if (_player != null) return _player;
    try {
      final player = AudioPlayer();
      _player = player;
      _positionSub = player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      });
      _durationSub = player.durationStream.listen((dur) {
        state = state.copyWith(duration: dur ?? Duration.zero);
      });
      _playerStateSub = player.playerStateStream.listen((playerState) {
        state = state.copyWith(isPlaying: playerState.playing);
      });
      _processingStateSub =
          player.processingStateStream.listen((processingState) {
        _logger.info('[AudioPlayer] processingState=$processingState');
      });
      return player;
    } on MissingPluginException {
      _isAvailable = false;
      return null;
    }
  }

  Future<void> loadRecording(String audioPath) async {
    if (!_isAvailable) return;
    final attempt = ++_loadAttempt;
    AudioPlayer? player;
    String? token;
    try {
      player = _ensurePlayer();
      if (player == null) return;
      await player.stop();
      final config = _ref.read(appConfigProvider);
      final session = _ref.read(authSessionProvider);
      token = session.token;
      _logger.info(
        '[AudioPlayer] loadRecording audioPath="$audioPath" '
        'baseUrl="${config.audioBaseUrl}" token=${token != null}',
      );
      final uri = _buildAudioUri(
        baseUrl: config.audioBaseUrl,
        audioPath: audioPath,
      );
      if (uri == null) {
        _logger.warning('[AudioPlayer] Empty audio path for recording');
        return;
      }
      _logger.info('[AudioPlayer] Loading audio: $uri');
      await _probeAudio(uri, token);
      await player.setAudioSource(
        AudioSource.uri(
          uri,
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
    } on MissingPluginException catch (error, stack) {
      _logger.severe('[AudioPlayer] MissingPluginException', error, stack);
      _isAvailable = false;
    } catch (error, stack) {
      _logger.severe('[AudioPlayer] Failed to load audio source', error, stack);
      final fallbackUri = _buildMp3FallbackUri(
        baseUrl: _ref.read(appConfigProvider).audioBaseUrl,
        audioPath: audioPath,
      );
      if (fallbackUri != null && attempt == _loadAttempt && player != null) {
        _logger.warning('[AudioPlayer] Retrying with MP3: $fallbackUri');
        await _probeAudio(fallbackUri, token);
        try {
          await player.setAudioSource(
            AudioSource.uri(
              fallbackUri,
              headers: token == null ? null : {'Authorization': 'Bearer $token'},
            ),
          );
        } catch (fallbackError, fallbackStack) {
          _logger.severe(
            '[AudioPlayer] MP3 fallback failed',
            fallbackError,
            fallbackStack,
          );
        }
      }
    }
  }

  Future<void> playPause() async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> rewind({int seconds = 5}) async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      final target = state.position - Duration(seconds: seconds);
      await player.seek(target < Duration.zero ? Duration.zero : target);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> forward({int seconds = 5}) async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      final target = state.position + Duration(seconds: seconds);
      await player.seek(target);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> setSpeed(double speed) async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      await player.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> seek(Duration position) async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      await player.seek(position);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> pressPlay() async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      if (!player.playing) {
        await player.play();
      }
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> releasePlay() async {
    if (!_isAvailable) return;
    try {
      final player = _ensurePlayer();
      if (player == null) return;
      if (player.playing) {
        await player.pause();
      }
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _processingStateSub?.cancel();
    if (_isAvailable) {
      try {
        _player?.dispose();
      } on MissingPluginException catch (_) {
        _isAvailable = false;
      }
    }
    super.dispose();
  }

  Uri? _buildAudioUri({
    required String baseUrl,
    required String audioPath,
  }) {
    final trimmed = audioPath.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      _logger.info('[AudioPlayer] Using absolute audio URL: $parsed');
      return parsed;
    }

    var normalized = trimmed.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final recordingsIndex = normalized.indexOf('recordings/');
    if (recordingsIndex >= 0) {
      normalized = normalized.substring(recordingsIndex + 'recordings/'.length);
    } else if (normalized.contains('media/recordings/')) {
      normalized = normalized.split('media/recordings/').last;
    }

    final filename = normalized.split('/').last;
    final base = Uri.parse(baseUrl);
    final resolved = base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'recordings',
        filename,
      ],
    );
    _logger.info(
      '[AudioPlayer] buildAudioUri normalized="$normalized" filename="$filename" '
      'resolved="$resolved"',
    );
    return resolved;
  }

  Uri? _buildMp3FallbackUri({
    required String baseUrl,
    required String audioPath,
  }) {
    final trimmed = audioPath.trim();
    if (!trimmed.toLowerCase().endsWith('.wav')) return null;
    final mp3Path =
        trimmed.substring(0, trimmed.length - 4) + '.mp3';
    return _buildAudioUri(baseUrl: baseUrl, audioPath: mp3Path);
  }

  Future<void> _probeAudio(Uri uri, String? token) async {
    try {
      final dio = Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final headers = <String, dynamic>{
        'Range': 'bytes=0-1',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await dio.getUri(uri, options: Options(headers: headers));
      _logger.info(
        '[AudioPlayer] probe status=${response.statusCode} '
        'contentType=${response.headers.value('content-type')} '
        'contentLength=${response.headers.value('content-length')}',
      );
    } catch (error, stack) {
      _logger.warning('[AudioPlayer] probe failed', error, stack);
    }
  }
}

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerController, AudioPlayerState>((ref) {
  return AudioPlayerController(ref);
});
