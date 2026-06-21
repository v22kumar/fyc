import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/api_constants.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fade;
  late AnimationController _aurora;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    context.read<AuthBloc>().add(const AuthCheckRequested());
  }

  @override
  void dispose() {
    _fade.dispose();
    _aurora.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthUnauthenticated) {
          // DEV ONLY — skip the language/login flow and go straight to home.
          context.go(ApiConstants.devBypassAuth ? '/home' : '/lang-select');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Aurora blobs ─────────────────────────────────────────────
            AnimatedBuilder(
              animation: _aurora,
              builder: (_, __) {
                final t = _aurora.value * 2 * math.pi;
                return Stack(
                  children: [
                    // Large primary blob — top-left
                    Positioned(
                      left: -100.0 + 70 * math.sin(t * 0.55),
                      top: -100.0 + 60 * math.cos(t * 0.40),
                      child: _SplashBlob(
                        size: 320,
                        color: const Color(0xFF0F5132).withOpacity(0.55),
                      ),
                    ),
                    // Medium secondary blob — bottom-right
                    Positioned(
                      right: -80.0 + 90 * math.sin(t * 0.32 + 1.2),
                      bottom: 60.0 + 70 * math.cos(t * 0.48 + 0.6),
                      child: _SplashBlob(
                        size: 280,
                        color: const Color(0xFF16A34A).withOpacity(0.32),
                      ),
                    ),
                    // Small gold accent — center-bottom
                    Positioned(
                      left: 60.0 + 50 * math.sin(t * 0.72 + 2.4),
                      bottom: -60.0 + 80 * math.cos(t * 0.38 + 1.8),
                      child: _SplashBlob(
                        size: 220,
                        color: const Color(0xFFD4AF37).withOpacity(0.08),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ── Blur layer ───────────────────────────────────────────────
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),

            // ── Foreground content ───────────────────────────────────────
            FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing ring around logo
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) {
                        final scale = 1.0 + 0.04 * _pulse.value;
                        final ringOpacity = 0.5 - 0.3 * _pulse.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Container(
                              width: 140 * scale,
                              height: 140 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF16A34A)
                                      .withOpacity(ringOpacity),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Logo container
                            child!,
                          ],
                        );
                      },
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF0F5132).withOpacity(0.40),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/images/fyc_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            '🌱',
                            style: TextStyle(fontSize: 46),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // App name
                    const Text(
                      'FYC Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Tamil tagline
                    Text(
                      'சமூக சேவையில் இணைவோம்',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.60),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Animated dots loader
                    AnimatedBuilder(
                      animation: _aurora,
                      builder: (_, __) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final phase =
                                (_aurora.value * 3 - i * 0.33) % 1.0;
                            final opacity =
                                (0.25 + 0.75 * math.sin(phase * math.pi))
                                    .clamp(0.25, 1.0);
                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF16A34A)
                                    .withOpacity(opacity),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _SplashBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
