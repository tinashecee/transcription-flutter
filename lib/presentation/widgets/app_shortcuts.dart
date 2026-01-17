import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/foot_pedal_service.dart';
import '../player/audio_player_controller.dart';

class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  late final FootPedalService _footPedalService;
  StreamSubscription<FootPedalEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    try {
      _footPedalService = FootPedalService()..start();
      _subscription = _footPedalService.events.listen(_handlePedal);
    } catch (e) {
      // Foot pedal service is optional - silently fail if not available
      print('Foot pedal service initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _footPedalService.dispose();
    super.dispose();
  }

  void _handlePedal(FootPedalEvent event) {
    try {
      final controller = ref.read(audioPlayerControllerProvider.notifier);
      if (event.pedal == 'left' && event.pressed) {
        controller.rewind();
      }
      if (event.pedal == 'right' && event.pressed) {
        controller.forward();
      }
      if (event.pedal == 'middle') {
        if (event.pressed) {
          controller.pressPlay();
        } else {
          controller.releasePlay();
        }
      }
    } catch (e) {
      // Ignore foot pedal handling errors
      print('Foot pedal event handling failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): const RewindIntent(),
        LogicalKeySet(LogicalKeyboardKey.f2): const PlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.f3): const ForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.f4): const SlowDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5): const SpeedUpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          RewindIntent: CallbackAction<RewindIntent>(
            onInvoke: (intent) =>
                ref.read(audioPlayerControllerProvider.notifier).rewind(),
          ),
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (intent) =>
                ref.read(audioPlayerControllerProvider.notifier).playPause(),
          ),
          ForwardIntent: CallbackAction<ForwardIntent>(
            onInvoke: (intent) =>
                ref.read(audioPlayerControllerProvider.notifier).forward(),
          ),
          SlowDownIntent: CallbackAction<SlowDownIntent>(
            onInvoke: (intent) {
              final state = ref.read(audioPlayerControllerProvider);
              final next = (state.speed - 0.25).clamp(0.25, 2.0);
              return ref
                  .read(audioPlayerControllerProvider.notifier)
                  .setSpeed(next);
            },
          ),
          SpeedUpIntent: CallbackAction<SpeedUpIntent>(
            onInvoke: (intent) {
              final state = ref.read(audioPlayerControllerProvider);
              final next = (state.speed + 0.25).clamp(0.25, 2.0);
              return ref
                  .read(audioPlayerControllerProvider.notifier)
                  .setSpeed(next);
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }
}

class RewindIntent extends Intent {
  const RewindIntent();
}

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class ForwardIntent extends Intent {
  const ForwardIntent();
}

class SlowDownIntent extends Intent {
  const SlowDownIntent();
}

class SpeedUpIntent extends Intent {
  const SpeedUpIntent();
}
