import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthLayout extends StatefulWidget {
  final Widget child;
  final String location;

  const AuthLayout({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> {
  bool _isTransitioning = false;
  late Widget _activeChild;
  String? _lastLocation;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _activeChild = widget.child;
    _lastLocation = widget.location;
  }

  @override
  void didUpdateWidget(AuthLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location) {
      _startTransition();
    } else if (!_isTransitioning) {
      // Update active child if it's not a route change (e.g. form state change)
      _activeChild = widget.child;
    }
  }

  void _startTransition() {
    _transitionTimer?.cancel();
    setState(() {
      _isTransitioning = true;
    });

    _transitionTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
          _activeChild = widget.child;
          _lastLocation = widget.location;
        });
      }
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B4D3E),
              Color(0xFF2A735D),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background blur effects
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(),
                ),
              ),
            ),

            Column(
              children: [
                // Header (Stateless)
                _buildHeader(),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/testimony.png',
                              width: 240,
                              height: 96,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 32),
                            
                            // Animated transition between Loader and Form
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: _isTransitioning 
                                ? _buildLoader()
                                : KeyedSubtree(
                                    key: ValueKey(widget.location),
                                    child: _activeChild,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer (Stateless)
                _buildFooter(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 105,
            height: 80,
            child: OverflowBox(
              minWidth: 105,
              maxWidth: 105,
              minHeight: 105,
              maxHeight: 105,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/jsc_logo_1.webp',
                width: 105,
                height: 105,
                fit: BoxFit.contain,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              'Contact Support',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Testimony Court Intelligence | Powered by Soxfort Solutions',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'INTUITIVE INNOVATION ${DateTime.now().year}',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return Container(
      key: const ValueKey('auth_loader'),
      // Matching the approximate height of the forms to prevent layout jumps
      constraints: const BoxConstraints(minHeight: 400),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Securing session...',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
