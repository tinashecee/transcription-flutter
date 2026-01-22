import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _transitionController;
  late AnimationController _waveController;
  
  bool _startWave = false;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Start the sequence
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _startWave = true);
        _transitionController.forward();
      }
    });

    // Navigate to login after animation
    Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _transitionController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 600,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Connecting Sound Wave
              if (_startWave)
                Positioned(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _transitionController,
                      curve: Curves.easeIn,
                    ),
                    child: SizedBox(
                      width: 200,
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(12, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                final animValue = math.sin((_waveController.value * 2 * math.pi) + (index * 0.5));
                                final height = 4.0 + (animValue.abs() * 28.0);
                                return Container(
                                  width: 4,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: Color.lerp(
                                      const Color(0xFF1B4D3E),
                                      const Color(0xFF2A735D),
                                      animValue.abs(),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

              // JSC Logo (Left)
              AnimatedBuilder(
                animation: _transitionController,
                builder: (context, child) {
                  final xOffset = -240.0 * _transitionController.value;
                  final scale = 0.5 + (0.5 * _transitionController.value);
                  final opacity = _transitionController.value;
                  
                  return Transform.translate(
                    offset: Offset(xOffset, 0),
                    child: Transform.scale(
                      scale: _transitionController.isAnimating || _transitionController.isCompleted ? scale : 0.5,
                      child: Opacity(
                        opacity: _transitionController.isAnimating || _transitionController.isCompleted ? opacity : 0.0,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/jsc_logo_1.webp',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),

              // Testimony Logo (Right)
              AnimatedBuilder(
                animation: _transitionController,
                builder: (context, child) {
                  final xOffset = 240.0 * _transitionController.value;
                  
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating Ring
                      if (!_transitionController.isCompleted)
                        RotationTransition(
                          turns: _rotationController,
                          child: Opacity(
                            opacity: (1.0 - _transitionController.value).clamp(0.0, 0.5),
                            child: Container(
                              width: 320,
                              height: 320,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1B4D3E),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(xOffset, 0),
                        child: child,
                      ),
                    ],
                  );
                },
                child: Image.asset(
                  'assets/images/testimony.png',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
