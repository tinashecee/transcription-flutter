import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_controller.dart';
import '../../services/update_manager.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  late AnimationController _waveAnimationController;

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _waveAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    final authState = authController.value;

    return Scaffold(
      body: Stack(
        children: [
          // Animated wave background
          AnimatedBuilder(
            animation: _waveAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF0F4F3),
                      const Color(0xFFF0F4F3).withOpacity(0.95),
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: WavePainter(
                    animationValue: _waveAnimationController.value,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF115343).withOpacity(0.95), // rgba(17, 83, 67, 0.95)
                        const Color(0xFF3F7166).withOpacity(0.95), // rgba(63, 113, 102, 0.95)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 48,
                        offset: const Offset(0, 22),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 240,
                        height: 78, // Adjust based on logo aspect ratio
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Image.asset(
                          'assets/images/testimony.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),

                      // Title and subtitle
                      Text(
                        'Welcome back',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue to Testimony Transcriber Portal',
                        style: GoogleFonts.roboto(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Version badge
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Version ${UpdateManager.appDisplayVersion ?? '2.1.10'}',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Login form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email field
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: TextFormField(
                                controller: _emailController,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty ? 'Required' : null,
                              ),
                            ),

                            // Password field
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty ? 'Required' : null,
                              ),
                            ),

                            // Remember me and forgot password
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) =>
                                        setState(() => _rememberMe = value ?? true),
                                    fillColor: MaterialStateProperty.resolveWith(
                                      (states) => Colors.white.withOpacity(0.12),
                                    ),
                                    checkColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  Text(
                                    'Remember me',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : () async {
                                            if (_emailController.text.isEmpty) {
                                              return;
                                            }
                                            await authController
                                                .forgotPassword(_emailController.text);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'Password reset email sent',
                                                    style: TextStyle(color: Colors.white),
                                                  ),
                                                  backgroundColor: const Color(0xFF4CAF50),
                                                ),
                                              );
                                            }
                                          },
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.roboto(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Error message
                            if (authState.errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  authState.errorMessage!,
                                  style: GoogleFonts.roboto(
                                    color: const Color(0xFFFF6B6B),
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: authState.isLoading
                                    ? null
                                    : () async {
                                        if (_formKey.currentState?.validate() ?? false) {
                                          await authController.login(
                                            email: _emailController.text,
                                            password: _passwordController.text,
                                            rememberMe: _rememberMe,
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF115343),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.12),
                                ),
                                child: authState.isLoading
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF115343),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Log In',
                                        style: GoogleFonts.roboto(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Footer text
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        child: Text(
                          'Intuitive Innovation for Modern Justice Systems',
                          style: GoogleFonts.roboto(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom wave painter for background animation
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF004D40).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path1 = Path();
    final path2 = Path();
    final path3 = Path();

    // Calculate animation offset
    final offset = animationValue * size.width;

    // Wave 1
    path1.moveTo(-offset, size.height * 0.45);
    for (double x = 0; x < size.width + 200; x += 200) {
      path1.quadraticBezierTo(
        x + 100 - offset,
        size.height * 0.4,
        x + 200 - offset,
        size.height * 0.45,
      );
    }

    // Wave 2
    path2.moveTo(-offset, size.height * 0.5);
    for (double x = 0; x < size.width + 200; x += 200) {
      path2.quadraticBezierTo(
        x + 100 - offset,
        size.height * 0.45,
        x + 200 - offset,
        size.height * 0.5,
      );
    }

    // Wave 3
    path3.moveTo(-offset, size.height * 0.35);
    for (double x = 0; x < size.width + 200; x += 200) {
      path3.quadraticBezierTo(
        x + 100 - offset,
        size.height * 0.3,
        x + 200 - offset,
        size.height * 0.35,
      );
    }

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
