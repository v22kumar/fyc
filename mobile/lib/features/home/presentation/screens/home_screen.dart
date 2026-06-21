import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../service_locator.dart';
import '../../../../main.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _aurora;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _aurora.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) context.go('/login');
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        extendBody: true,
        body: RefreshIndicator(
          color: AppColors.primaryLight,
          backgroundColor: AppColors.darkSurface,
          onRefresh: () async => await Future.delayed(const Duration(milliseconds: 600)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(l: l, aurora: _aurora),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BeAHeroCard(),
                      const SizedBox(height: 22),
                      _QuickServices(),
                      const SizedBox(height: 18),
                      const _AnnouncementsBar(),
                      const SizedBox(height: 22),
                      _ImpactStats(l: l),
                      const SizedBox(height: 22),
                      const _UpcomingAndNews(),
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
                            onTap: () async {
                              final storage = sl<LocalStorage>();
                              final next = storage.getLang() == 'ta' ? 'en' : 'ta';
                              await storage.saveLang(next);
                              localeNotifier.value = Locale(next);
                            },
                          ),
                          const SizedBox(width: 8),
                          _CircleBtn(
                            icon: Icons.notifications_outlined,
                            onTap: () => context.push('/announcements'),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showMoreSheet(context),
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
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Search coming soon')),
                        ),
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

// ── Quick Services ───────────────────────────────────────────────────────────

class _Service {
  final IconData? icon;
  final String? glyph;
  final String label, sub, route;
  final Color color;
  const _Service({this.icon, this.glyph, required this.label, required this.sub, required this.route, required this.color});
}

class _QuickServices extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final services = <_Service>[
      const _Service(icon: Icons.water_drop, label: 'Blood Donors', sub: 'Find Donors', route: '/blood-donation', color: Color(0xFFEF4444)),
      const _Service(icon: Icons.event, label: 'Events', sub: 'Explore', route: '/events', color: Color(0xFF8B5CF6)),
      const _Service(glyph: '♚', label: 'Chess', sub: 'Play & Connect', route: '/chess', color: Color(0xFF0F172A)),
      const _Service(icon: Icons.emoji_events, label: 'Sports Hub', sub: 'Live Scores', route: '/sports', color: Color(0xFFF97316)),
      const _Service(icon: Icons.campaign, label: 'Report Issue', sub: 'Raise Report', route: '/issues', color: Color(0xFFEAB308)),
      const _Service(icon: Icons.eco, label: 'Green FYC', sub: 'Discover', route: '/green', color: Color(0xFF16A34A)),
      const _Service(icon: Icons.contacts, label: 'Directory', sub: 'Contacts', route: '/directory', color: Color(0xFF2563EB)),
      const _Service(icon: Icons.verified_user, label: 'Verify Card', sub: 'Verify Now', route: '/membership', color: Color(0xFF14B8A6)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Quick Services', onViewAll: () => _showMoreSheet(context)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.74,
          children: services.map((s) => _ServiceTile(s: s)).toList(),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final _Service s;
  const _ServiceTile({required this.s});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: s.color.withOpacity(0.08),
          onTap: () => context.push(s.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: s.glyph != null
                        ? Text(s.glyph!, style: TextStyle(fontSize: 22, color: s.color, height: 1))
                        : Icon(s.icon, color: s.color, size: 21),
                  ),
                ),
                const SizedBox(height: 7),
                Text(s.label,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(s.sub,
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryLight.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.14), shape: BoxShape.circle),
                child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Announcements',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Text('Annual Sports Meet on 25th May!',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
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
                  color: s.$4,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: s.$3.withOpacity(0.18)),
                ),
                child: Column(
                  children: [
                    Text(s.$1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: s.$3)),
                    const SizedBox(height: 3),
                    Text(s.$2,
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
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
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
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
                      color: AppColors.surface.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(icon: Icons.home_rounded, label: 'Home', active: true, onTap: () {}),
                        _NavItem(icon: Icons.grid_view_rounded, label: 'Services', onTap: () => _showMoreSheet(context)),
                        const SizedBox(width: 56),
                        _NavItem(icon: Icons.celebration_rounded, label: 'Events', onTap: () => context.push('/events')),
                        _NavItem(icon: Icons.more_horiz_rounded, label: 'More', onTap: () => _showMoreSheet(context)),
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
                        border: Border.all(color: AppColors.background, width: 3),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 2),
                    const Text('Create', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
    final color = active ? AppColors.primary : AppColors.textSecondary;
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
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 18),
          const Text('Create', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: a.$4.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(a.$1, color: a.$4, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Text(a.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              Text(section.$1,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
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
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: AppColors.accent),
              title: Text(l.logout, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(const AuthLogoutRequested());
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.cardShadow,
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
                    decoration: BoxDecoration(color: item.color.withOpacity(0.08), shape: BoxShape.circle),
                    child: Text(item.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(item.label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
