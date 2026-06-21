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

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
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
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primaryLight,
            backgroundColor: AppColors.darkSurface,
            onRefresh: () async {},
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Dark aurora hero (full-bleed)
                _AuroraHero(l: l, aurora: _aurora),

                // Light content card rising from dark
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModuleGrid(l: l),
                      const SizedBox(height: 20),
                      _CommunityPulse(),
                      const SizedBox(height: 12),
                      _TodaysSpotlight(),
                      const SizedBox(height: 20),
                      _StatsRow(l: l),
                      const SizedBox(height: 20),
                      const DailyThirukkuralCard(),
                      const SizedBox(height: 16),
                      const DailyNewsCard(),
                      const SizedBox(height: 16),
                      const WeatherCard(),
                      const SizedBox(height: 16),
                      const GoldPriceCard(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const _FloatingDock(),
      ),
    );
  }
}

// ── Aurora Hero ──────────────────────────────────────────────────────────────

class _AuroraHero extends StatelessWidget {
  final AppLocalizations l;
  final AnimationController aurora;
  const _AuroraHero({required this.l, required this.aurora});

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
        final greetingTa = hour < 12
            ? 'காலை வணக்கம்'
            : hour < 17
                ? 'மதிய வணக்கம்'
                : 'மாலை வணக்கம்';
        final greetingEn = hour < 12
            ? 'Good Morning'
            : hour < 17
                ? 'Good Afternoon'
                : 'Good Evening';

        return SizedBox(
          height: 230,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Dark base
                Container(color: AppColors.darkBg),

                // Animated aurora blobs
                AnimatedBuilder(
                  animation: aurora,
                  builder: (_, __) {
                    final t = aurora.value * 2 * math.pi;
                    return Stack(
                      children: [
                        Positioned(
                          left: -50.0 + 70 * math.sin(t * 0.65),
                          top: -60.0 + 50 * math.cos(t * 0.45),
                          child: _Blob(
                            size: 240,
                            color: const Color(0xFF0F5132).withOpacity(0.60),
                          ),
                        ),
                        Positioned(
                          right: -30.0 + 60 * math.sin(t * 0.4 + 1.5),
                          top: 10.0 + 45 * math.cos(t * 0.55 + 0.8),
                          child: _Blob(
                            size: 200,
                            color: const Color(0xFF16A34A).withOpacity(0.38),
                          ),
                        ),
                        Positioned(
                          left: 90.0 + 80 * math.sin(t * 0.28 + 2.2),
                          top: 90.0 + 35 * math.cos(t * 0.75 + 1.1),
                          child: _Blob(
                            size: 160,
                            color: const Color(0xFFD4AF37).withOpacity(0.10),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Blur layer — blurs blobs into smooth aurora
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                  child: Container(color: Colors.transparent),
                ),

                // Vignette — subtle bottom fade to blend into content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.darkBg.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top nav row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: Image.asset(
                              'assets/images/fyc_logo.png',
                              width: 26,
                              height: 26,
                              errorBuilder: (_, __, ___) =>
                                  const Text('🌱', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          _DarkIconBtn(
                            icon: Icons.notifications_outlined,
                            onTap: () => context.go('/announcements'),
                          ),
                          const SizedBox(width: 8),
                          _DarkIconBtn(
                            icon: Icons.translate_rounded,
                            onTap: () async {
                              final storage = sl<LocalStorage>();
                              final cur = storage.getLang();
                              final next = cur == 'ta' ? 'en' : 'ta';
                              await storage.saveLang(next);
                              localeNotifier.value = Locale(next);
                            },
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Greeting
                      Text(
                        greetingTa,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$greetingEn, $firstName! 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Text(
                          '🌱 Friends Youth Club · Nagercoil · Since 1998',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DarkIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DarkIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.10),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ── 8-Module Bento Grid ──────────────────────────────────────────────────────

class _Module {
  final String emoji, label, route;
  final Color color;
  const _Module(this.emoji, this.label, this.route, this.color);
}

class _ModuleGrid extends StatelessWidget {
  final AppLocalizations l;
  const _ModuleGrid({required this.l});

  @override
  Widget build(BuildContext context) {
    final ta = sl<LocalStorage>().getLang() == 'ta';
    final modules = [
      _Module('🩸', ta ? 'இரத்த தானம்' : 'Blood Donors',
          '/blood-donation', const Color(0xFFEF4444)),
      _Module('🎉', ta ? 'நிகழ்வுகள்' : 'Events',
          '/events', const Color(0xFF8B5CF6)),
      _Module('♟', ta ? 'சதுரங்கம்' : 'Chess',
          '/chess', const Color(0xFF0F172A)),
      _Module('🏆', ta ? 'விளையாட்டு' : 'Sports Hub',
          '/sports', const Color(0xFF10B981)),
      _Module('🚧', ta ? 'புகார்' : 'Report Issue',
          '/issues', AppColors.warning),
      _Module('🌱', ta ? 'பசுமை FYC' : 'Green FYC',
          '/green', const Color(0xFF047857)),
      _Module('📋', ta ? 'அகவடை' : 'Directory',
          '/directory', const Color(0xFF2563EB)),
      _Module('🪪', ta ? 'அட்டை சரி' : 'Verify Card',
          '/membership', AppColors.primary),
      _Module('💼', ta ? 'வாய்ப்புகள்' : 'Opportunities',
          '/opportunities', const Color(0xFFD97706)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ta ? 'சேவைகள்' : 'Services',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: modules.map((m) => _ModuleTile(m: m)).toList(),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final _Module m;
  const _ModuleTile({required this.m});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: m.color.withOpacity(0.08),
          onTap: () => context.push(m.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: m.color.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text(m.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 6),
                Text(
                  m.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Community Pulse ──────────────────────────────────────────────────────────

class _CommunityPulse extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: const [
          _PulseCard(label: 'Members', value: '847+', icon: Icons.people, color: Color(0xFF0F5132)),
          _PulseCard(label: 'Blood Donors', value: '120', icon: Icons.favorite, color: Color(0xFFF43F5E)),
          _PulseCard(label: 'Active Now', value: '43', icon: Icons.circle, color: Color(0xFF10B981)),
          _PulseCard(label: 'Events', value: '12', icon: Icons.event, color: Color(0xFFD4AF37)),
        ],
      ),
    );
  }
}

// ── Today's Spotlight ─────────────────────────────────────────────────────────

class _TodaysSpotlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Spotlight', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('🌳 15 trees planted this week', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('🩸 3 blood donation events upcoming', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        ],
      ),
    );
  }
}

// ── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AppLocalizations l;
  const _StatsRow({required this.l});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('1500+', '🌱', l.statsTreesPlanted, AppColors.success),
      ('1200+', '🩸', l.statsDonors, AppColors.accent),
      ('80+',   '🎉', l.statsEvents, const Color(0xFF8B5CF6)),
      ('5000+', '❤️', l.statsImpacted, const Color(0xFFF43F5E)),
    ];

    return Row(
      children: stats.map((s) {
        final isLast = s == stats.last;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: s.$4.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Text(s.$2, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 8),
                Text(
                  s.$1,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: s.$4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.$3,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Floating Dock ─────────────────────────────────────────────────────────────

class _FloatingDock extends StatelessWidget {
  const _FloatingDock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DockItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: true,
                  onTap: () {},
                ),
                _DockItem(
                  icon: Icons.bloodtype_rounded,
                  label: 'Blood',
                  onTap: () => context.push('/blood-donation'),
                ),
                _DockItem(
                  icon: Icons.celebration_rounded,
                  label: 'Events',
                  onTap: () => context.push('/events'),
                ),
                _DockItem(
                  icon: Icons.grid_view_rounded,
                  label: 'More',
                  onTap: () => _showMoreSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return Pressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: active ? 14 : 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withOpacity(0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showMoreSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _MoreSheet(),
  );
}

class _MenuItem {
  final String icon;
  final String label;
  final String route;
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
          _MenuItem('🚧', l.publicIssues, '/issues', AppColors.warning),
          _MenuItem('🔍', ta ? 'புகார் கண்காணிப்பு' : 'Track Issues',
              '/issues/track', const Color(0xFF14B8A6)),
          _MenuItem('🪪', l.membership, '/membership', AppColors.primary),
          _MenuItem('📋', l.directory, '/directory', const Color(0xFF2563EB)),
        ],
      ),
      (
        ta ? 'சமூகம்' : 'Community',
        [
          _MenuItem('🏆', ta ? 'விளையாட்டு' : 'Sports Hub', '/sports',
              const Color(0xFF10B981)),
          _MenuItem('🌱', ta ? 'பசுமை FYC' : 'Green FYC', '/green',
              const Color(0xFF047857)),
          _MenuItem('📢', ta ? 'அறிவிப்புகள்' : 'Announcements',
              '/announcements', const Color(0xFFF59E0B)),
          _MenuItem('📷', ta ? 'புகைப்படங்கள்' : 'Gallery', '/gallery',
              const Color(0xFFD97706)),
          _MenuItem('🤝', ta ? 'சமூகம்' : 'Community', '/community',
              const Color(0xFFEC4899)),
        ],
      ),
      (
        ta ? 'கணக்கு' : 'Account',
        [
          _MenuItem('🎓', ta ? 'சான்றிதழ்' : 'Certificates', '/certificate',
              const Color(0xFF6366F1)),
          _MenuItem('ℹ️', ta ? 'எங்களைப் பற்றி' : 'About', '/about',
              AppColors.textSecondary),
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
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              Text(
                section.$1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: section.$2
                    .map((item) => _BentoTile(item: item))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: AppColors.accent),
              title: Text(
                l.logout,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
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
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Text(item.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pulse Card ───────────────────────────────────────────────────────────────

class _PulseCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _PulseCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}
