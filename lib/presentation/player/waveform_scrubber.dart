import 'dart:math';
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
    final double progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final relative = (localPos.dx / box.size.width).clamp(0.0, 1.0);
        onSeek(Duration(milliseconds: (relative * duration.inMilliseconds).toInt()));
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final relative = (localPos.dx / box.size.width).clamp(0.0, 1.0);
        onSeek(Duration(milliseconds: (relative * duration.inMilliseconds).toInt()));
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = (constraints.maxWidth / 4).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (index) {
              final barProgress = index / barCount;
              final isActive = barProgress <= progress;
              
              // Seeded random height for "waveform" look
              final random = Random(index * 31);
              final heightFactor = 0.3 + random.nextDouble() * 0.7;
              
              return Container(
                width: 2,
                height: constraints.maxHeight * heightFactor,
                decoration: BoxDecoration(
                  color: isActive 
                    ? const Color(0xFF115343) 
                    : const Color(0xFF115343).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
