import 'package:flutter/material.dart';

class WaveformScrubber extends StatelessWidget {
  const WaveformScrubber({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final value = position.inMilliseconds.clamp(0, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          value: value,
          max: max.toDouble(),
          onChanged: (val) => onSeek(Duration(milliseconds: val.toInt())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_format(position)),
            Text(_format(duration)),
          ],
        ),
      ],
    );
  }

  String _format(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(duration.inMinutes.remainder(60));
    final seconds = two(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
