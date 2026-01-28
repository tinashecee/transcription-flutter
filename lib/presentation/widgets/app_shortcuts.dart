import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/foot_pedal_service.dart';
import '../player/audio_player_controller.dart';
import '../../app/providers.dart';

class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts>
    with WidgetsBindingObserver {
  StreamSubscription<FootPedalEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clearKeyboardState();
    try {
      final service = ref.read(footPedalServiceProvider);
      service.start();
      _subscription = service.events.listen(_handlePedal);
    } catch (e) {
      // Foot pedal service is optional - silently fail if not available
      print('Foot pedal service initialization failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      _clearKeyboardState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  void _clearKeyboardState() {
    // clearState is restricted; use a no-op try block to avoid crashes on bad key states
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      HardwareKeyboard.instance.clearState();
    } catch (_) {}
  }

  void _handlePedal(FootPedalEvent event) {
    try {
      final controller = ref.read(audioPlayerControllerProvider.notifier);
      if (event.pedal == 'left' && event.pressed) {
       controller.forward();
      }
      if (event.pedal == 'right' && event.pressed) {
        controller.playPause();
      }
      if (event.pedal == 'middle') {
       controller.rewind();
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
            onInvoke: (intent) {
              print('[AppShortcuts] F1 Rewind triggered');
              return ref.read(audioPlayerControllerProvider.notifier).rewind();
            },
          ),
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (intent) {
              print('[AppShortcuts] F2 PlayPause triggered');
              return ref.read(audioPlayerControllerProvider.notifier).playPause();
            },
          ),
          ForwardIntent: CallbackAction<ForwardIntent>(
            onInvoke: (intent) {
              print('[AppShortcuts] F3 Forward triggered');
              return ref.read(audioPlayerControllerProvider.notifier).forward();
            },
          ),
          SlowDownIntent: CallbackAction<SlowDownIntent>(
            onInvoke: (intent) {
              print('[AppShortcuts] F4 SlowDown triggered');
              final state = ref.read(audioPlayerControllerProvider);
              final next = (state.speed - 0.25).clamp(0.25, 2.0);
              return ref
                  .read(audioPlayerControllerProvider.notifier)
                  .setSpeed(next);
            },
          ),
          SpeedUpIntent: CallbackAction<SpeedUpIntent>(
            onInvoke: (intent) {
              print('[AppShortcuts] F5 SpeedUp triggered');
              final state = ref.read(audioPlayerControllerProvider);
              final next = (state.speed + 0.25).clamp(0.25, 2.0);
              return ref
                  .read(audioPlayerControllerProvider.notifier)
                  .setSpeed(next);
            },
          ),
        },
        child: widget.child,
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
