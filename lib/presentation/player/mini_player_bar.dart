import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_player_controller.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    if (state.duration == Duration.zero) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed:
                  ref.read(audioPlayerControllerProvider.notifier).playPause,
            ),
            Expanded(
              child: Slider(
                value: state.position.inSeconds
                    .clamp(0, state.duration.inSeconds)
                    .toDouble(),
                max: state.duration.inSeconds.toDouble(),
                onChanged: (value) => ref
                    .read(audioPlayerControllerProvider.notifier)
                    .seek(Duration(seconds: value.toInt())),
              ),
            ),
            Text(
              '${_format(state.position)} / ${_format(state.duration)}',
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(duration.inMinutes.remainder(60));
    final secs = two(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
  }
}
