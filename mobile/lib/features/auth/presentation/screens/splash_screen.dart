import 'dart:math' as math;
import '../../../../core/l10n/tr.dart';
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
        final home = ApiConstants.useAppShellV2 ? '/app' : '/home';
        String? target;
        // Signed in or not, the app opens into the app.
        //
        // This used to send anyone without a session to /lang-select, which
        // led to /login — so every launch that was not already authenticated
        // began with two gates, and choosing a language was something members
        // did over and over. The language is remembered (and detected from the
        // phone the first time); signing in happens when an action needs it.
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          target = home;
        }
        if (target == null) return;

        // AuthCheckRequested is dispatched from initState, and with no stored
        // token the bloc settles SYNCHRONOUSLY — so this listener can run while
        // the first frame is still being built. Navigating at that moment makes
        // GoRouter mark widgets dirty mid-build, which the framework reports as
        // "setState() called during build". Defer to just after the frame.
        final destination = target;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(destination);
        });
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
                      child: SizedBox(
                        width: 118,
                        child: Image.asset(
                          // Transparent eagle mark — sits inside the pulsing ring.
                          'assets/images/fyc_mark.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(
                            '🌱',
                            style: TextStyle(fontSize: 46),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 36),

                    // App name
                    Text(
                      trId('fyc_connect'),
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    SizedBox(height: 6),

                    // Tamil tagline
                    Text(
                      'சமூக சேவையில் இணைவோம்',
                      style: TextStyle(
                        color: AppColors.background.withOpacity(0.60),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),

                    SizedBox(height: 60),

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
                                  EdgeInsets.symmetric(horizontal: 4),
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
