import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

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
    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.durationStream.listen((dur) {
      state = state.copyWith(duration: dur ?? Duration.zero);
    });
    _player.playerStateStream.listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);
    });
  }

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  bool _isAvailable = true;

  Future<void> loadRecording(String audioPath) async {
    if (!_isAvailable) return;
    try {
      final config = _ref.read(appConfigProvider);
      final session = _ref.read(authSessionProvider);
      final token = session.token;
      final uri = Uri.parse('${config.audioBaseUrl}$audioPath');
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> playPause() async {
    if (!_isAvailable) return;
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> rewind({int seconds = 5}) async {
    if (!_isAvailable) return;
    try {
      final target = state.position - Duration(seconds: seconds);
      await _player.seek(target < Duration.zero ? Duration.zero : target);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> forward({int seconds = 5}) async {
    if (!_isAvailable) return;
    try {
      final target = state.position + Duration(seconds: seconds);
      await _player.seek(target);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> setSpeed(double speed) async {
    if (!_isAvailable) return;
    try {
      await _player.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> seek(Duration position) async {
    if (!_isAvailable) return;
    try {
      await _player.seek(position);
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> pressPlay() async {
    if (!_isAvailable) return;
    try {
      if (!_player.playing) {
        await _player.play();
      }
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> releasePlay() async {
    if (!_isAvailable) return;
    try {
      if (_player.playing) {
        await _player.pause();
      }
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
  }

  @override
  void dispose() {
    if (_isAvailable) {
      try {
        _player.dispose();
      } on MissingPluginException catch (_) {
        _isAvailable = false;
      }
    }
    super.dispose();
  }
}

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerController, AudioPlayerState>((ref) {
  return AudioPlayerController(ref);
});
