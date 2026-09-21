// lib/splash_screen.dart
import 'package:flutter/material.dart';
import 'RoleSelectionScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  static const Duration _splashDuration = Duration(seconds: 3);

  final List<Color> _dotColors = const [
    Color(0xFF2B2560),
    Color(0xFFB13BE0),
    Color(0xFFE85CA8),
    Color(0xFFF3C6E0),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    Future.delayed(_splashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const RoleSelectionScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            Image.asset(
              'assets/images/logo.png',
              width: 220,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Color(0xFF2B2560),
                );
              },
            ),
            const Spacer(flex: 3),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _dotColors.length,
                    (index) {
                      final double phase =
                          (_controller.value + (index / _dotColors.length)) %
                              1.0;
                      final double bounce =
                          (1 - (2 * phase - 1).abs()).clamp(0.0, 1.0);
                      final double scale = 0.7 + 0.5 * bounce;
                      final double opacity = 0.5 + 0.5 * bounce;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _dotColors[index],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
