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
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/fyc_logo.png',
                  width: 26,
                  height: 26,
                  errorBuilder: (_, __, ___) => const Text('🌱', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Text(l.appName),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go('/announcements'),
              tooltip: 'Notifications',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'logout') {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                } else if (value == 'lang') {
                  final storage = sl<LocalStorage>();
                  final currentLang = storage.getLang();
                  final newLang = currentLang == 'ta' ? 'en' : 'ta';
                  await storage.saveLang(newLang);
                  localeNotifier.value = Locale(newLang);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'lang',
                  child: Row(
                    children: [
                      const Icon(Icons.language, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        sl<LocalStorage>().getLang() == 'ta'
                            ? 'English-க்கு மாற்றவும்'
                            : 'தமிழுக்கு மாற்றவும்',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(l.logout),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.paddingPage),
            children: [
              // Greeting
              _GreetingCard(l: l),
              const SizedBox(height: 20),

              // Stats
              _StatsRow(l: l),
              const SizedBox(height: 24),

              // Quick Access Grid
              Text(
                l.homeSubtitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _QuickAccessGrid(l: l),
              const SizedBox(height: 24),

              // Emergency Blood CTA
              _EmergencyBloodBanner(l: l),
            ],
          ),
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

class _QuickAccessGrid extends StatelessWidget {
  final AppLocalizations l;
  const _QuickAccessGrid({required this.l});

  @override
  Widget build(BuildContext context) {
    final ta = sl<LocalStorage>().getLang() == 'ta';
    final items = [
      (icon: '🩸', label: l.bloodDonation, route: '/blood-donation',
       color: AppColors.accent),
      (icon: '🚧', label: l.publicIssues, route: '/issues',
       color: AppColors.warning),
      (icon: '🔎', label: ta ? 'புகார் நிலை' : 'Track Issues',
       route: '/issues/track', color: const Color(0xFFB45309)),
      (icon: '🪪', label: l.membership, route: '/membership',
       color: AppColors.primary),
      (icon: '🎗️', label: l.events, route: '/events',
       color: const Color(0xFF7C3AED)),
      (icon: '🏅', label: ta ? 'விளையாட்டு' : 'Sports',
       route: '/sports', color: const Color(0xFF059669)),
      (icon: '🌱', label: ta ? 'பசுமை FYC' : 'Green FYC',
       route: '/green', color: const Color(0xFF16A34A)),
      (icon: '📢', label: ta ? 'அறிவிப்புகள்' : 'Announcements',
       route: '/announcements', color: const Color(0xFFDC2626)),
      (icon: '📷', label: l.gallery, route: '/gallery',
       color: const Color(0xFFD97706)),
      (icon: '📋', label: l.directory, route: '/directory',
       color: const Color(0xFF1D4ED8)),
      (icon: '👥', label: ta ? 'சமூகம்' : 'Community',
       route: '/community', color: const Color(0xFF0891B2)),
      (icon: '🎓', label: ta ? 'சான்றிதழ்' : 'Certificate',
       route: '/certificate', color: const Color(0xFF9333EA)),
      (icon: 'ℹ️', label: ta ? 'எங்களைப் பற்றி' : 'About',
       route: '/about', color: AppColors.textSecondary),
       color: const Color(0xFF8B5CF6)),
      (icon: '📷', label: l.gallery, route: '/gallery',
       color: const Color(0xFFD97706)),
      (icon: '📋', label: l.directory, route: '/directory',
       color: const Color(0xFF2563EB)),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items.map((item) {
        return _GridTile(
          icon: item.icon,
          label: item.label,
          color: item.color,
          onTap: () => context.push(item.route),
        );
      }).toList(),
    );
  }
}

class _GridTile extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GridTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          splashColor: color.withOpacity(0.08),
          highlightColor: color.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
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

class _EmergencyBloodBanner extends StatelessWidget {
  final AppLocalizations l;
  const _EmergencyBloodBanner({required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFFBE123C)], // Rose 600 to Rose 700
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/blood-donation'),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          splashColor: Colors.white.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🩸', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'இரத்த அவசரநிலை?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.searchDonors,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
