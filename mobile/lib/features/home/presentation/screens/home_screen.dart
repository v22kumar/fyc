import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../main.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../thirukkural/presentation/widgets/daily_thirukkural_card.dart';
import '../../../news/presentation/widgets/daily_news_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.paddingPage, 8, AppTheme.paddingPage, 120,
              ),
              children: [
                _HomeHeader(l: l),
                const SizedBox(height: 18),

                // Greeting
                _GreetingCard(l: l),
                const SizedBox(height: 20),

                // Daily Thirukkural (bilingual couplet of the day)
                const DailyThirukkuralCard(),
                const SizedBox(height: 16),

                // Daily Tamil news (Google News RSS, top 10)
                const DailyNewsCard(),
                const SizedBox(height: 24),

                // Stats
                _StatsRow(l: l),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const _FloatingDock(),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final AppLocalizations l;
  const _HomeHeader({required this.l});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppTheme.cardShadow,
          ),
          child: Image.asset(
            'assets/images/fyc_logo.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => const Text('🌱', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l.appName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        _HeaderIconButton(
          icon: Icons.notifications_outlined,
          onTap: () => context.go('/announcements'),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.translate_rounded,
          onTap: () async {
            final storage = sl<LocalStorage>();
            final currentLang = storage.getLang();
            final newLang = currentLang == 'ta' ? 'en' : 'ta';
            await storage.saveLang(newLang);
            localeNotifier.value = Locale(newLang);
          },
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final AppLocalizations l;
  const _GreetingCard({required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0891B2)], // Cyan 700 to Cyan 600
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.homeGreeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Friends Youth Club – Nagercoil',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Active since 1998',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/fyc_logo.png',
              width: 52,
              height: 52,
              errorBuilder: (_, __, ___) =>
                  const Text('🌱', style: TextStyle(fontSize: 36)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AppLocalizations l;
  const _StatsRow({required this.l});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('1500+', '🌱', l.statsTreesPlanted, AppColors.success),
      ('1200+', '🩸', l.statsDonors, AppColors.accent),
      ('80+',   '🎉', l.statsEvents, const Color(0xFF8B5CF6)), // Purple
      ('5000+', '❤️', l.statsImpacted, const Color(0xFFF43F5E)), // Rose
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: s == stats.last ? 0 : 8,
            ),
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
                      color: AppColors.textSecondary),
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

/// Floating "dock" bottom navigation. Deliberately not an edge-to-edge
/// Material BottomNavigationBar — a frosted, rounded island that surfaces
/// the most-used destinations, with everything else one tap away in
/// [_MoreSheet].
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ],
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

/// Bento-grid "More" menu — every destination that used to live in the
/// flat quick-access grid, grouped by purpose so the dock stays minimal.
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
          _MenuItem('🔍', ta ? 'புகார் கண்காணிப்பு' : 'Track Issues', '/issues/track',
              const Color(0xFF14B8A6)),
          _MenuItem('🪪', l.membership, '/membership', AppColors.primary),
          _MenuItem('📋', l.directory, '/directory', const Color(0xFF2563EB)),
        ],
      ),
      (
        ta ? 'சமூகம்' : 'Community',
        [
          _MenuItem('🏆', ta ? 'விளையாட்டு' : 'Sports Hub', '/sports', const Color(0xFF10B981)),
          _MenuItem('🌱', ta ? 'பசுமை FYC' : 'Green FYC', '/green', const Color(0xFF047857)),
          _MenuItem('📢', ta ? 'அறிவிப்புகள்' : 'Announcements', '/announcements',
              const Color(0xFFF59E0B)),
          _MenuItem('📷', ta ? 'புகைப்படங்கள்' : 'Gallery', '/gallery', const Color(0xFFD97706)),
          _MenuItem('🤝', ta ? 'சமூகம்' : 'Community', '/community', const Color(0xFFEC4899)),
        ],
      ),
      (
        ta ? 'கணக்கு' : 'Account',
        [
          _MenuItem('🎓', ta ? 'சான்றிதழ்' : 'Certificates', '/certificate',
              const Color(0xFF6366F1)),
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
                children: section.$2.map((item) => _BentoTile(item: item)).toList(),
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
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
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
                  child: Text(item.icon, style: const TextStyle(fontSize: 22)),
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
    );
  }
}
