import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/update_dialog.dart';
import '../../../../service_locator.dart';
import '../../../../main.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../thirukkural/presentation/widgets/daily_thirukkural_card.dart';
import '../../../news/presentation/widgets/daily_news_card.dart';
import '../widgets/weather_card.dart';
import '../widgets/gold_price_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _aurora;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    // Best-effort in-app update check once the home screen is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateDialog.maybePrompt(context);
    });
  }

  @override
  void dispose() {
    _aurora.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshKey++);
    // Give the new futures a moment to kick off before hiding the spinner
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) context.go('/login');
      },
      child: Scaffold(
        backgroundColor: context.cBackground,
        extendBody: true,
        body: RefreshIndicator(
          color: AppColors.primaryLight,
          backgroundColor: AppColors.darkSurface,
          onRefresh: _onRefresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(l: l, aurora: _aurora),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cBackground,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthAuthenticated) {
                            if (state.user.isAdmin) {
                              return _ManagerDashboard(l: l, refreshKey: _refreshKey);
                            } else if (state.user.isVolunteer) {
                              return _VolunteerDashboard(l: l, refreshKey: _refreshKey);
                            }
                          }
                          return _CitizenDashboard(l: l, refreshKey: _refreshKey);
                        },
                      ),
                      const SizedBox(height: 130),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const _BottomBar(),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppLocalizations l;
  final AnimationController aurora;
  const _Header({required this.l, required this.aurora});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String firstName = 'Friend';
        if (state is AuthAuthenticated) {
          final fullName = state.user.fullNameEn ?? state.user.fullNameTa ?? '';
          final parts = fullName.trim().split(' ');
          if (parts.isNotEmpty && parts.first.isNotEmpty) firstName = parts.first;
        }

        final hour = DateTime.now().hour;
        final greetingEn = hour < 12
            ? 'Good Morning'
            : hour < 17
                ? 'Good Afternoon'
                : 'Good Evening';

        return SizedBox(
          height: 268,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.darkBg),
              // Photographic backdrop (FYC youth at Kanyakumari) — faded under aurora
              Positioned.fill(
                child: Opacity(
                  opacity: 0.32,
                  child: Image.asset(
                    'assets/images/hero_community.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: aurora,
                builder: (_, __) {
                  final t = aurora.value * 2 * math.pi;
                  return Stack(
                    children: [
                      Positioned(
                        left: -50.0 + 70 * math.sin(t * 0.65),
                        top: -60.0 + 50 * math.cos(t * 0.45),
                        child: _Blob(size: 240, color: const Color(0xFF0F5132).withOpacity(0.60)),
                      ),
                      Positioned(
                        right: -30.0 + 60 * math.sin(t * 0.4 + 1.5),
                        top: 10.0 + 45 * math.cos(t * 0.55 + 0.8),
                        child: _Blob(size: 200, color: const Color(0xFF16A34A).withOpacity(0.38)),
                      ),
                      Positioned(
                        left: 90.0 + 80 * math.sin(t * 0.28 + 2.2),
                        top: 90.0 + 35 * math.cos(t * 0.75 + 1.1),
                        child: _Blob(size: 160, color: const Color(0xFFD4AF37).withOpacity(0.10)),
                      ),
                    ],
                  );
                },
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: Container(color: Colors.transparent),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: logo + title + actions
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Image.asset(
                              'assets/images/fyc_logo.png',
                              width: 30,
                              height: 30,
                              errorBuilder: (_, __, ___) => const Text('🌱', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('FYC Connect',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                                Text('Welcome back!',
                                    style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          _CircleBtn(
                            icon: Icons.translate_rounded,
                            tooltip: 'Change Language',
                            onTap: () => _showLanguagePicker(context),
                          ),
                          const SizedBox(width: 8),
                          const _NotificationBell(),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => context.push('/settings'),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white.withOpacity(0.15),
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('$greetingEn, $firstName! 👋',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      const Text('Everything you need, all in one place.',
                          style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 16),
                      // Search bar
                      GestureDetector(
                        onTap: () => context.push('/search'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.16)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.white60, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Search services, events, and more...',
                                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                              ),
                              Icon(Icons.tune_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _CircleBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.10),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Notification bell with an unread-count badge. Taps through to /notifications.
class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final res = await sl<ApiClient>().dio.get('/api/v1/notifications');
      final list = (res.data as List?) ?? const [];
      final count = list
          .where((e) => e is Map && e['is_read'] != true)
          .length;
      if (mounted) setState(() => _unread = count);
    } catch (_) {/* leave badge hidden on failure */}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _CircleBtn(
          icon: Icons.notifications_outlined,
          onTap: () async {
            await context.push('/notifications');
            _loadUnread();
          },
        ),
        if (_unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBg, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                _unread > 9 ? '9+' : '$_unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Be a Hero (Blood Donation hero card) ─────────────────────────────────────

class _BeAHeroCard extends StatelessWidget {
  const _BeAHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B6E4F), Color(0xFF12A150)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF12A150).withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🩸 Be a Hero',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Icon(Icons.favorite, color: Colors.white.withOpacity(0.85), size: 15),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Donate Blood. Save Lives.',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Your one donation can save up to 3 lives.',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
                const SizedBox(height: 14),
                Pressable(
                  child: GestureDetector(
                    onTap: () => context.push('/blood-donation'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Find Blood Donors',
                              style: TextStyle(color: Color(0xFF0B6E4F), fontSize: 13, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, color: Color(0xFF0B6E4F), size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            height: 96,
            child: CustomPaint(painter: _BloodBagPainter()),
          ),
        ],
      ),
    );
  }
}

class _BloodBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Heartbeat line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final midY = h * 0.78;
    path.moveTo(0, midY);
    path.lineTo(w * 0.28, midY);
    path.lineTo(w * 0.36, midY - h * 0.14);
    path.lineTo(w * 0.46, midY + h * 0.18);
    path.lineTo(w * 0.56, midY);
    path.lineTo(w, midY);
    canvas.drawPath(path, linePaint);

    // Blood bag body
    final bagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.30, h * 0.06, w * 0.42, h * 0.56),
      const Radius.circular(10),
    );
    canvas.drawRRect(bagRect, Paint()..color = Colors.white.withOpacity(0.95));

    // Red fill in bag
    final fillRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.42, h * 0.32),
      bottomLeft: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );
    canvas.drawRRect(fillRect, Paint()..color = const Color(0xFFEF4444));

    // Cross on bag (white area)
    final crossPaint = Paint()..color = const Color(0xFFEF4444);
    final cx = w * 0.51, cy = h * 0.20;
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 4, height: 14), crossPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 4), crossPaint);

    // Hanger nub
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.46, h * 0.0, w * 0.10, h * 0.07), const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    // Drip tube
    canvas.drawLine(Offset(w * 0.51, h * 0.62), Offset(w * 0.51, h * 0.74),
        Paint()..color = Colors.white.withOpacity(0.7)..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Service Bento (rich, web-parity cards) ───────────────────────────────────

class _BentoService {
  final IconData? icon;
  final String? glyph;
  final String title, desc, badge, route;
  final Color color;
  const _BentoService({
    this.icon,
    this.glyph,
    required this.title,
    required this.desc,
    required this.badge,
    required this.route,
    required this.color,
  });
}

class _ServiceBento extends StatelessWidget {
  const _ServiceBento();

  @override
  Widget build(BuildContext context) {
    const items = <_BentoService>[
      _BentoService(icon: Icons.water_drop, title: 'Blood Donation', desc: 'Find verified donors nearby and connect securely in emergencies.', badge: 'URGENT', route: '/blood-donation', color: Color(0xFFEF4444)),
      _BentoService(icon: Icons.event, title: 'Events', desc: 'Upcoming community events, festivals and meetings. Register and attend.', badge: 'LIVE', route: '/events', color: Color(0xFF8B5CF6)),
      _BentoService(icon: Icons.emoji_events, title: 'Sports Hub', desc: 'Track local tournaments, teams, fixtures and live scores.', badge: 'NEW', route: '/sports', color: Color(0xFFF97316)),
      _BentoService(icon: Icons.campaign, title: 'Report Issue', desc: 'Raise civic complaints like water or street lights and track resolution.', badge: 'ACTIVE', route: '/issues', color: Color(0xFFEAB308)),
      _BentoService(icon: Icons.eco, title: 'Green FYC', desc: 'Tree-planting drives, eco initiatives and environmental activities.', badge: 'ECO', route: '/green', color: Color(0xFF16A34A)),
      _BentoService(icon: Icons.contacts, title: 'Skills Directory', desc: 'Find local carpenters, electricians, tutors and verified profiles.', badge: 'NEW', route: '/directory', color: Color(0xFF2563EB)),
      _BentoService(glyph: '♚', title: 'Chess Arena', desc: 'Play, challenge friends and climb the club leaderboard.', badge: 'PLAY', route: '/chess', color: Color(0xFF0F172A)),
      _BentoService(icon: Icons.work, title: 'Opportunities', desc: 'TN & Central govt jobs, scholarships and community openings.', badge: 'JOBS', route: '/opportunities', color: Color(0xFFD97706)),
      _BentoService(icon: Icons.verified_user, title: 'Verify Card', desc: 'Scan and verify FYC membership cards using a QR code.', badge: 'OFFICIAL', route: '/membership', color: Color(0xFF14B8A6)),
      _BentoService(icon: Icons.map, title: 'My Journey', desc: 'Your contributions, impact and volunteer milestones.', badge: 'IMPACT', route: '/journey', color: Color(0xFFEC4899)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Explore', onViewAll: () => _showMoreSheet(context)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.96,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _BentoCard(s: items[i]),
        ),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  final _BentoService s;
  const _BentoCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Pressable(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push(s.route),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? s.color.withOpacity(0.14) : s.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: s.color.withOpacity(dark ? 0.30 : 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: dark ? s.color.withOpacity(0.22) : Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: dark ? null : AppTheme.cardShadow,
                      ),
                      child: Center(
                        child: s.glyph != null
                            ? Text(s.glyph!, style: TextStyle(fontSize: 22, color: dark ? Colors.white : s.color, height: 1))
                            : Icon(s.icon, color: s.color, size: 22),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dark ? Colors.white.withOpacity(0.10) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: s.color.withOpacity(0.25)),
                      ),
                      child: Text(
                        s.badge,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: s.color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s.title,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.cText, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Text(
                    s.desc,
                    style: TextStyle(fontSize: 11, height: 1.32, color: context.cTextSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.color)),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward, size: 13, color: s.color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Announcements bar ────────────────────────────────────────────────────────

class _AnnouncementsBar extends StatelessWidget {
  const _AnnouncementsBar();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: GestureDetector(
        onTap: () => context.push('/announcements'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.primaryLight.withOpacity(0.12) : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryLight.withOpacity(context.isDark ? 0.30 : 0.20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.18), shape: BoxShape.circle),
                child: Icon(Icons.campaign_rounded, color: context.isDark ? AppColors.primaryLight : AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Announcements',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.isDark ? AppColors.primaryLight : AppColors.primary)),
                    Text('Annual Sports Meet on 25th May!',
                        style: TextStyle(fontSize: 11, color: context.cTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.isDark ? AppColors.primaryLight : AppColors.primary)),
              Icon(Icons.chevron_right, color: context.isDark ? AppColors.primaryLight : AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Impact stats ─────────────────────────────────────────────────────────────

class _ImpactStats extends StatelessWidget {
  final AppLocalizations l;
  const _ImpactStats({required this.l});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('1500+', 'Youth Network', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      ('1200+', 'Blood Donors', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      ('80+', 'Events Hosted', const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
      ('5000+', 'Lives Impacted', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Our Impact'),
        const SizedBox(height: 12),
        Row(
          children: stats.map((s) {
            final isLast = s == stats.last;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: isLast ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                decoration: BoxDecoration(
                  color: context.isDark ? s.$3.withOpacity(0.16) : s.$4,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: s.$3.withOpacity(context.isDark ? 0.30 : 0.18)),
                ),
                child: Column(
                  children: [
                    Text(s.$1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.isDark ? s.$3.withOpacity(0.95) : s.$3)),
                    const SizedBox(height: 3),
                    Text(s.$2,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: context.cTextSecondary),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Upcoming Event + Latest News ─────────────────────────────────────────────

class _UpcomingAndNews extends StatelessWidget {
  const _UpcomingAndNews();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MiniCard(
            sectionTitle: 'Upcoming Event',
            onViewAll: () => context.push('/events'),
            icon: Icons.event,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Annual Sports Meet',
            subtitle: '25th May · Nagercoil',
            onTap: () => context.push('/events'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            sectionTitle: 'Latest News',
            onViewAll: () => context.push('/announcements'),
            icon: Icons.article,
            iconColor: const Color(0xFF16A34A),
            title: 'Green Drive Initiative',
            subtitle: '500 trees planted',
            onTap: () => context.push('/green'),
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String sectionTitle, title, subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onViewAll, onTap;
  const _MiniCard({
    required this.sectionTitle,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onViewAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(sectionTitle,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cText),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: const Text('View All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Pressable(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cBorder),
                boxShadow: context.isDark ? null : AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: iconColor.withOpacity(context.isDark ? 0.22 : 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(title,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 10.5, color: context.cTextSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText, letterSpacing: -0.3)),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
      ],
    );
  }
}

// ── Bottom Bar with center Create FAB ────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      color: Colors.transparent,
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Bar
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.cSurface.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: context.cBorder),
                      boxShadow: context.isDark ? null : AppTheme.cardShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(icon: Icons.home_rounded, label: 'Home', active: true, onTap: () {}),
                        _NavItem(icon: Icons.grid_view_rounded, label: 'Services', onTap: () => _showMoreSheet(context)),
                        const SizedBox(width: 56),
                        _NavItem(icon: Icons.people_alt_rounded, label: 'Community', onTap: () => context.push('/community')),
                        _NavItem(icon: Icons.person_rounded, label: 'Profile', onTap: () => context.push('/profile')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Center Create FAB
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => _showCreateSheet(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppTheme.gradientPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cBackground, width: 3),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 2),
                    Text('Create', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: context.isDark ? AppColors.primaryLight : AppColors.primary)),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (context.isDark ? AppColors.primaryLight : AppColors.primary)
        : context.cTextSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Language Picker ──────────────────────────────────────────────────────────

void _showLanguagePicker(BuildContext context) {
  const langs = [
    ('ta', 'அ', 'தமிழ்', 'Tamil', Color(0xFF0F5132)),
    ('en', 'A', 'English', 'English', Color(0xFF2563EB)),
    ('hi', 'अ', 'हिन्दी', 'Hindi', Color(0xFFDC2626)),
    ('ml', 'അ', 'മലയാളം', 'Malayalam', Color(0xFF7C3AED)),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final storage = sl<LocalStorage>();
      String current = storage.getLang();
      return StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          decoration: BoxDecoration(
            color: context.cBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 18),
              Text('Language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText)),
              const SizedBox(height: 14),
              ...langs.map((lang) {
                final selected = current == lang.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () async {
                      await storage.saveLang(lang.$1);
                      localeNotifier.value = Locale(lang.$1);
                      setSt(() => current = lang.$1);
                      await Future.delayed(const Duration(milliseconds: 200));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? lang.$5.withOpacity(0.10) : context.cSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? lang.$5.withOpacity(0.60) : context.cBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: lang.$5.withOpacity(0.14),
                            child: Text(lang.$2,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: lang.$5)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lang.$3,
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700,
                                        color: selected ? lang.$5 : context.cText)),
                                Text(lang.$4,
                                    style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle_rounded, color: lang.$5, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      });
    },
  );
}

// ── Search Sheet ─────────────────────────────────────────────────────────────

class _SearchEntry {
  final String title, subtitle, route;
  final IconData icon;
  final Color color;
  const _SearchEntry(this.title, this.subtitle, this.route, this.icon, this.color);
}

const _allSearchEntries = [
  _SearchEntry('Blood Donors', 'Find donors by blood group', '/blood-donation', Icons.water_drop, Color(0xFFEF4444)),
  _SearchEntry('Register as Donor', 'Donate blood, save lives', '/blood-donation/register', Icons.favorite, Color(0xFFEF4444)),
  _SearchEntry('Events', 'Upcoming community events', '/events', Icons.event, Color(0xFF8B5CF6)),
  _SearchEntry('Chess', 'Play, challenge & spectate', '/chess', Icons.sports_esports, Color(0xFF0F172A)),
  _SearchEntry('Sports Hub', 'Tournaments & challenges', '/sports', Icons.emoji_events, Color(0xFFF97316)),
  _SearchEntry('Report Issue', 'Report a civic problem', '/issues', Icons.campaign, Color(0xFFEAB308)),
  _SearchEntry('Track Issues', 'Check submitted reports', '/issues/track', Icons.search, Color(0xFF14B8A6)),
  _SearchEntry('Green FYC', 'Tree plantation drives', '/green', Icons.eco, Color(0xFF16A34A)),
  _SearchEntry('Register Tree', 'Log a tree you planted', '/green/register', Icons.park, Color(0xFF16A34A)),
  _SearchEntry('Directory', 'Emergency contacts', '/directory', Icons.contacts, Color(0xFF2563EB)),
  _SearchEntry('Membership Card', 'Your FYC digital card', '/membership', Icons.verified_user, Color(0xFF14B8A6)),
  _SearchEntry('Announcements', 'Latest club updates', '/announcements', Icons.notifications, Color(0xFFF59E0B)),
  _SearchEntry('Gallery', 'Event photos', '/gallery', Icons.photo_library, Color(0xFFD97706)),
  _SearchEntry('Community', 'Member directory', '/community', Icons.people, Color(0xFFEC4899)),
  _SearchEntry('Opportunities', 'Jobs, volunteer & skills', '/opportunities', Icons.work, Color(0xFFD97706)),
  _SearchEntry('Certificate', 'Volunteer certificates', '/certificate', Icons.school, Color(0xFF6366F1)),
  _SearchEntry('Settings', 'App preferences', '/settings', Icons.settings, Color(0xFF475569)),
  _SearchEntry('About FYC', 'Our story since 1998', '/about', Icons.info, Color(0xFF475569)),
];

void _showSearchSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SearchSheet(),
  );
}

class _SearchSheet extends StatefulWidget {
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  List<_SearchEntry> _results = _allSearchEntries;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_filter);
  }

  void _filter() {
    final q = _ctrl.text.toLowerCase().trim();
    setState(() {
      _results = q.isEmpty
          ? _allSearchEntries
          : _allSearchEntries.where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.subtitle.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.cBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.cBorder),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(color: context.cText, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search services, events, and more...',
                    hintStyle: TextStyle(color: context.cTextSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: context.cTextSecondary, size: 20),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: context.cTextSecondary, size: 18),
                            onPressed: () { _ctrl.clear(); setState(() => _results = _allSearchEntries); })
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_ctrl.text.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.apps_rounded, size: 14, color: context.cTextSecondary),
                    const SizedBox(width: 6),
                    Text('All Services', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cTextSecondary, letterSpacing: 0.3)),
                  ],
                ),
              ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: context.cTextSecondary),
                          const SizedBox(height: 12),
                          Text('No results for "${_ctrl.text}"',
                              style: TextStyle(color: context.cTextSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Try blood group, event name, or service',
                              style: TextStyle(color: context.cTextSecondary, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: context.cBorder, indent: 60),
                      itemBuilder: (_, i) {
                        final e = _results[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: e.color.withOpacity(context.isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(e.icon, color: e.color, size: 20),
                          ),
                          title: Text(e.title,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.cText)),
                          subtitle: Text(e.subtitle,
                              style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cTextSecondary),
                          onTap: () {
                            final router = GoRouter.of(context);
                            Navigator.pop(context);
                            router.push(e.route);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create sheet ─────────────────────────────────────────────────────────────

void _showCreateSheet(BuildContext context) {
  final actions = <(IconData, String, String, Color)>[
    (Icons.water_drop, 'Register as Donor', '/blood-donation/register', const Color(0xFFEF4444)),
    (Icons.campaign, 'Report an Issue', '/issues', const Color(0xFFEAB308)),
    (Icons.eco, 'Register a Tree', '/green/register', const Color(0xFF16A34A)),
    (Icons.sports_kabaddi, 'Create Challenge', '/sports/challenge', const Color(0xFF8B5CF6)),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: context.cBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 18),
          Text('Create', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText)),
          const SizedBox(height: 14),
          ...actions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push(a.$3);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.cBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: a.$4.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                            child: Icon(a.$1, color: a.$4, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Text(a.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.cText)),
                          const Spacer(),
                          Icon(Icons.chevron_right, color: context.cTextSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    ),
  );
}

// ── More sheet ───────────────────────────────────────────────────────────────

void _showMoreSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _MoreSheet(),
  );
}

class _MenuItem {
  final String icon, label, route;
  final Color color;
  const _MenuItem(this.icon, this.label, this.route, this.color);
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ta = sl<LocalStorage>().getLang() == 'ta';

    final sections = <(String, List<_MenuItem>)>[
      (
        ta ? 'சேவைகள்' : 'Services',
        [
          _MenuItem('🩸', ta ? 'இரத்த தானம்' : 'Blood Donors', '/blood-donation', const Color(0xFFEF4444)),
          _MenuItem('🎉', l.events, '/events', const Color(0xFF8B5CF6)),
          _MenuItem('♟', ta ? 'சதுரங்கம்' : 'Chess', '/chess', const Color(0xFF0F172A)),
          _MenuItem('🏆', ta ? 'விளையாட்டு' : 'Sports Hub', '/sports', const Color(0xFFF97316)),
          _MenuItem('🚧', l.publicIssues, '/issues', AppColors.warning),
          _MenuItem('🔍', ta ? 'புகார் கண்காணிப்பு' : 'Track Issues', '/issues/track', const Color(0xFF14B8A6)),
          _MenuItem('🪪', l.membership, '/membership', AppColors.primary),
          _MenuItem('📋', l.directory, '/directory', const Color(0xFF2563EB)),
          _MenuItem('💼', ta ? 'வாய்ப்புகள்' : 'Opportunities', '/opportunities', const Color(0xFFD97706)),
        ],
      ),
      (
        ta ? 'சமூகம்' : 'Community',
        [
          _MenuItem('🌱', ta ? 'பசுமை FYC' : 'Green FYC', '/green', const Color(0xFF047857)),
          _MenuItem('📢', ta ? 'அறிவிப்புகள்' : 'Announcements', '/announcements', const Color(0xFFF59E0B)),
          _MenuItem('📷', ta ? 'புகைப்படங்கள்' : 'Gallery', '/gallery', const Color(0xFFD97706)),
          _MenuItem('🤝', ta ? 'சமூகம்' : 'Community', '/community', const Color(0xFFEC4899)),
        ],
      ),
      (
        ta ? 'கணக்கு' : 'Account',
        [
          _MenuItem('⚙️', ta ? 'அமைப்புகள்' : 'Settings', '/settings', const Color(0xFF475569)),
          _MenuItem('🎓', ta ? 'சான்றிதழ்' : 'Certificates', '/certificate', const Color(0xFF6366F1)),
          _MenuItem('ℹ️', ta ? 'எங்களைப் பற்றி' : 'About', '/about', AppColors.textSecondary),
        ],
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.cBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              Text(section.$1,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.cTextSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: section.$2.map((item) => _BentoTile(item: item)).toList(),
              ),
              const SizedBox(height: 24),
            ],
            Divider(color: context.cBorder),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: AppColors.accent),
              title: Text(l.logout, style: TextStyle(fontWeight: FontWeight.bold, color: context.cText)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                          context.read<AuthBloc>().add(const AuthLogoutRequested());
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  final _MenuItem item;
  const _BentoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Container(
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: context.cBorder),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            splashColor: item.color.withOpacity(0.08),
            onTap: () {
              Navigator.pop(context);
              context.push(item.route);
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: item.color.withOpacity(context.isDark ? 0.18 : 0.08), shape: BoxShape.circle),
                    child: Text(item.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(item.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.cText),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashboards ───────────────────────────────────────────────────────────────

// ── Next upcoming event (real data) ──────────────────────────────────────────

class _NextEventCard extends StatefulWidget {
  const _NextEventCard();

  @override
  State<_NextEventCard> createState() => _NextEventCardState();
}

class _NextEventCardState extends State<_NextEventCard> {
  Map<String, dynamic>? _event;
  bool _loaded = false;

  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await sl<ApiClient>().dio.get('/api/v1/events');
      final list = (res.data as List?) ?? const [];
      final now = DateTime.now();
      final upcoming = list
          .whereType<Map<String, dynamic>>()
          .where((e) {
            final s = DateTime.tryParse((e['event_start'] as String?) ?? '');
            return s != null && s.isAfter(now);
          })
          .toList()
        ..sort((a, b) => DateTime.parse(a['event_start'])
            .compareTo(DateTime.parse(b['event_start'])));
      if (!mounted) return;
      setState(() {
        _event = upcoming.isNotEmpty ? upcoming.first : null;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = _lang == 'ta';
    if (!_loaded || _event == null) return const SizedBox.shrink();
    final e = _event!;
    final start = DateTime.parse(e['event_start']).toLocal();
    final title = (ta
            ? (e['title_ta'] ?? e['title_en'])
            : (e['title_en'] ?? e['title_ta'])) as String? ??
        '';
    final count = (e['registration_count'] as num?)?.toInt() ?? 0;
    final month = _monthAbbr(start.month, ta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ta ? 'வரவிருக்கும் நிகழ்வு' : 'Upcoming Event',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.cText)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.cBorder),
            boxShadow: context.isDark ? null : AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 52,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(month,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    Text('${start.day}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.cText)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.cText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 13, color: context.cTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${start.day} ${_monthAbbr(start.month, false)}, ${_time(start)}',
                          style: TextStyle(
                              fontSize: 11.5, color: context.cTextSecondary),
                        ),
                      ],
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 4),
                      Text(ta ? '$count பேர் வருகிறார்கள்' : '$count Going',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF12A150))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => context.push('/events'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(ta ? 'பதிவு' : 'Register',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _monthAbbr(int m, bool ta) {
    const en = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return en[m];
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$mm $ap';
  }
}

// ── Live Updates (recent community activity feed) ────────────────────────────

class _LiveUpdates extends StatefulWidget {
  const _LiveUpdates();

  @override
  State<_LiveUpdates> createState() => _LiveUpdatesState();
}

class _LiveUpdatesState extends State<_LiveUpdates> {
  List<Map<String, dynamic>> _items = [];
  bool _loaded = false;

  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await sl<ApiClient>().dio.get('/api/v1/community/feed', queryParameters: {'limit': 5});
      final list = (res.data as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _items = list.whereType<Map<String, dynamic>>().take(3).toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  ({IconData icon, Color color}) _style(String type) {
    switch (type.toUpperCase()) {
      case 'EVENT':
        return (icon: Icons.celebration_rounded, color: const Color(0xFF8B5CF6));
      case 'TOURNAMENT':
        return (icon: Icons.emoji_events_rounded, color: const Color(0xFFF97316));
      case 'ISSUE':
      case 'ISSUE_RESOLVED':
        return (icon: Icons.task_alt_rounded, color: const Color(0xFF0EA5E9));
      case 'BLOOD':
        return (icon: Icons.water_drop_rounded, color: const Color(0xFFEF4444));
      case 'TREE':
      case 'GREEN':
        return (icon: Icons.eco_rounded, color: const Color(0xFF16A34A));
      default:
        return (icon: Icons.campaign_rounded, color: AppColors.primary);
    }
  }

  String _ago(String iso, bool ta) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return ta ? 'இப்போது' : 'just now';
      if (diff.inMinutes < 60) return ta ? '${diff.inMinutes} நிமிடம்' : '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return ta ? '${diff.inHours} மணி' : '${diff.inHours}h ago';
      return ta ? '${diff.inDays} நாள்' : '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = _lang == 'ta';
    // Hide the section entirely when there's nothing to show.
    if (_loaded && _items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEF4444), shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(ta ? 'நேரடி புதுப்பிப்புகள்' : 'Live Updates',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.cText)),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/announcements'),
              child: Text(ta ? 'அனைத்தும்' : 'View All',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF12A150))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_loaded)
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cBorder),
            ),
            child: const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else
          ..._items.map((it) {
            final type = (it['item_type'] as String?) ?? '';
            final s = _style(type);
            final title = (ta
                    ? (it['title_ta'] ?? it['title_en'])
                    : (it['title_en'] ?? it['title_ta'])) as String? ??
                '';
            final sub = (ta
                    ? (it['subtitle_ta'] ?? it['subtitle_en'])
                    : (it['subtitle_en'] ?? it['subtitle_ta'])) as String? ??
                '';
            final ago = _ago((it['created_at'] as String?) ?? '', ta);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cBorder),
                boxShadow: context.isDark ? null : AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: s.color.withOpacity(context.isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(s.icon, color: s.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.cText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (sub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(sub,
                              style: TextStyle(
                                  fontSize: 11.5, color: context.cTextSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  if (ago.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(ago,
                        style: TextStyle(
                            fontSize: 10.5, color: context.cTextSecondary)),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ── Today's Impact Hub (live community stats + quick actions) ────────────────

class _TodayImpactHub extends StatefulWidget {
  final AppLocalizations l;
  const _TodayImpactHub({required this.l});

  @override
  State<_TodayImpactHub> createState() => _TodayImpactHubState();
}

class _TodayImpactHubState extends State<_TodayImpactHub> {
  int _volunteers = 0, _events = 0, _donations = 0, _trees = 0, _issues = 0;
  bool _loaded = false;

  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await sl<ApiClient>().dio.get('/api/v1/community/stats');
      final d = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _volunteers = (d['total_volunteers'] as num?)?.toInt() ?? 0;
        _events = (d['total_events'] as num?)?.toInt() ?? 0;
        _donations = (d['total_blood_donations'] as num?)?.toInt() ?? 0;
        _trees = (d['total_trees_planted'] as num?)?.toInt() ?? 0;
        _issues = (d['total_issues_solved'] as num?)?.toInt() ?? 0;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = _lang == 'ta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location + live pill
        Row(
          children: [
            const Icon(Icons.place_rounded, size: 16, color: Color(0xFF12A150)),
            const SizedBox(width: 4),
            Text(
              ta ? 'நாகர்கோவில், கன்னியாகுமரி' : 'Nagercoil, Kanyakumari',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.cTextSecondary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF12A150).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF12A150), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(ta ? 'நேரலை' : 'LIVE',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B6E4F),
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Community impact card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cBorder),
            boxShadow: context.isDark ? null : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 14),
                child: Row(
                  children: [
                    const Text('🌟', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      ta ? 'நமது சமூகத் தாக்கம்' : 'Our Community Impact',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.cText),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _metric(context, _trees.toString(),
                      ta ? 'மரங்கள்' : 'Trees', Icons.eco, const Color(0xFF16A34A)),
                  _metric(context, _donations.toString(),
                      ta ? 'தானம்' : 'Donations', Icons.water_drop,
                      const Color(0xFFEF4444)),
                  _metric(context, _events.toString(),
                      ta ? 'நிகழ்வுகள்' : 'Events', Icons.event,
                      const Color(0xFF8B5CF6)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metric(context, _volunteers.toString(),
                      ta ? 'தன்னார்வலர்' : 'Volunteers', Icons.people_alt,
                      const Color(0xFF2563EB)),
                  _metric(context, _issues.toString(),
                      ta ? 'தீர்வுகள்' : 'Resolved', Icons.task_alt,
                      const Color(0xFF0EA5E9)),
                  _metric(context, _loaded ? '24/7' : '—',
                      ta ? 'சேவை' : 'Service', Icons.support_agent,
                      const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick actions
        Row(
          children: [
            _quickAction(context, Icons.water_drop_rounded,
                ta ? 'இரத்தம்' : 'Donate', const Color(0xFFEF4444),
                () => context.push('/blood-donation')),
            const SizedBox(width: 10),
            _quickAction(context, Icons.campaign_rounded,
                ta ? 'புகார்' : 'Report', const Color(0xFFEAB308),
                () => context.push('/issues')),
            const SizedBox(width: 10),
            _quickAction(context, Icons.celebration_rounded,
                ta ? 'நிகழ்வு' : 'Events', const Color(0xFF8B5CF6),
                () => context.push('/events')),
            const SizedBox(width: 10),
            _quickAction(context, Icons.eco_rounded,
                ta ? 'பசுமை' : 'Green', const Color(0xFF16A34A),
                () => context.push('/green')),
          ],
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(context.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.cText)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: context.cTextSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: Pressable(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cBorder),
              boxShadow: context.isDark ? null : AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: color.withOpacity(context.isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.cText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CitizenDashboard extends StatelessWidget {
  final AppLocalizations l;
  final int refreshKey;
  const _CitizenDashboard({required this.l, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TodayImpactHub(l: l),
        const SizedBox(height: 22),
        const _LiveUpdates(),
        const SizedBox(height: 22),
        const _NextEventCard(),
        const SizedBox(height: 22),
        const _BeAHeroCard(),
        const SizedBox(height: 22),
        const _ServiceBento(),
        const SizedBox(height: 10),
        const _AnnouncementsBar(),
        const SizedBox(height: 22),
        _SectionHeader(title: 'Today'),
        const SizedBox(height: 12),
        DailyThirukkuralCard(key: ValueKey('kural-$refreshKey')),
        const SizedBox(height: 14),
        DailyNewsCard(key: ValueKey('news-$refreshKey')),
        const SizedBox(height: 14),
        WeatherCard(key: ValueKey('weather-$refreshKey')),
        const SizedBox(height: 14),
        GoldPriceCard(key: ValueKey('gold-$refreshKey')),
      ],
    );
  }
}

class _VolunteerDashboard extends StatelessWidget {
  final AppLocalizations l;
  final int refreshKey;
  const _VolunteerDashboard({required this.l, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.volunteer_activism, color: Color(0xFF8B5CF6), size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Volunteer Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF8B5CF6))),
                    Text('Thanks for making a difference!', style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8B5CF6)),
                onPressed: () => context.push('/journey'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _ServiceBento(),
        const SizedBox(height: 22),
        _SectionHeader(title: "Today's Activities"),
        const SizedBox(height: 12),
        _MiniCard(
          sectionTitle: 'Activity',
          title: 'Tree Plantation Drive',
          subtitle: '9:00 AM - 12:00 PM',
          icon: Icons.eco,
          iconColor: const Color(0xFF16A34A),
          onViewAll: () {},
          onTap: () => context.push('/green'),
        ),
        const SizedBox(height: 22),
        _SectionHeader(title: "My Contributions"),
        const SizedBox(height: 12),
        _ImpactStats(l: l),
        const SizedBox(height: 22),
        _SectionHeader(title: 'Today'),
        const SizedBox(height: 12),
        DailyThirukkuralCard(key: ValueKey('kural-$refreshKey')),
        const SizedBox(height: 14),
        DailyNewsCard(key: ValueKey('news-$refreshKey')),
        const SizedBox(height: 14),
        WeatherCard(key: ValueKey('weather-$refreshKey')),
        const SizedBox(height: 14),
        GoldPriceCard(key: ValueKey('gold-$refreshKey')),
      ],
    );
  }
}

class _ManagerDashboard extends StatelessWidget {
  final AppLocalizations l;
  final int refreshKey;
  const _ManagerDashboard({required this.l, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Color(0xFFF59E0B), size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manager Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF59E0B))),
                    Text('Manage club activities and requests', style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _ServiceBento(),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                sectionTitle: 'Pending Items',
                title: '3 New Approvals',
                subtitle: 'Action required',
                icon: Icons.pending_actions,
                iconColor: const Color(0xFFF59E0B),
                onViewAll: () {},
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                sectionTitle: 'Registrations',
                title: '12 New Members',
                subtitle: 'Last 7 days',
                icon: Icons.people,
                iconColor: const Color(0xFF3B82F6),
                onViewAll: () {},
                onTap: () => context.push('/community'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _ImpactStats(l: l),
        const SizedBox(height: 22),
        _SectionHeader(title: 'Recent Reports'),
        const SizedBox(height: 12),
        _MiniCard(
          sectionTitle: 'Issue',
          title: 'Street Light Broken',
          subtitle: 'Main Road, Zone 3',
          icon: Icons.report_problem,
          iconColor: const Color(0xFFEF4444),
          onViewAll: () => context.push('/issues/track'),
          onTap: () => context.push('/issues/track'),
        ),
        const SizedBox(height: 22),
        _SectionHeader(title: 'Today'),
        const SizedBox(height: 12),
        DailyThirukkuralCard(key: ValueKey('kural-$refreshKey')),
        const SizedBox(height: 14),
        DailyNewsCard(key: ValueKey('news-$refreshKey')),
        const SizedBox(height: 14),
        WeatherCard(key: ValueKey('weather-$refreshKey')),
        const SizedBox(height: 14),
        GoldPriceCard(key: ValueKey('gold-$refreshKey')),
      ],
    );
  }
}
