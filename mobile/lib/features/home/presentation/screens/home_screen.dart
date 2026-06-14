import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
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
          title: Text(l.appName),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
              tooltip: 'Notifications',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'logout') {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                }
              },
              itemBuilder: (_) => [
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeGreeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Friends Youth Club – Nagercoil',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text('🌱', style: TextStyle(fontSize: 36)),
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
      ('1500+', '🌱', l.statsTreesPlanted),
      ('1200+', '🩸', l.statsDonors),
      ('80+',   '🎉', l.statsEvents),
      ('5000+', '❤️', l.statsImpacted),
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: s == stats.last ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(s.$2, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  s.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  s.$3,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary),
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
    final items = [
      (icon: '🩸', label: l.bloodDonation, route: '/blood-donation',
       color: AppColors.accent),
      (icon: '🚧', label: l.publicIssues, route: '/issues',
       color: AppColors.warning),
      (icon: '📋', label: l.directory, route: '/directory',
       color: const Color(0xFF1D4ED8)),
      (icon: '📚', label: l.opportunityHub, route: '/opportunities',
       color: const Color(0xFF7C3AED)),
      (icon: '🎗️', label: l.events, route: '/events',
       color: AppColors.primary),
      (icon: '📷', label: l.gallery, route: '/gallery',
       color: const Color(0xFFD97706)),
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
          onTap: () => context.go(item.route),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: () => context.go('/blood-donation'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppColors.accentSurface),
        ),
        child: Row(
          children: [
            const Text('🩸', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'இரத்த அவசரநிலை?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    l.searchDonors,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
