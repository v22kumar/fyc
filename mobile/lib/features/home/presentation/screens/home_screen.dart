import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_localizations.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/design_system/shell/sos_sheet.dart';
import '../../../../core/design_system/components/ds_feature_card.dart';
import '../../../../core/design_system/components/ds_badge.dart';
import '../../../../core/design_system/patterns/kolam_background.dart';
import '../../../../core/design_system/components/spot_illustration.dart';
import '../../../sports/presentation/screens/live_scorecard_screen.dart';
import '../../../../core/design_system/components/ds_skeleton.dart';
import '../../../../core/design_system/components/ds_animated_counter.dart';
import '../../../../core/design_system/components/last_updated_pill.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/update_sheet.dart';
import '../../../../core/services/update_installer.dart';
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
  /// Home is always hosted inside [AppShellV2], which provides the single
  /// bottom navigation + center Create FAB. It never draws its own nav bar
  /// (audit #05: one navigation shell, not two divergent ones).
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Opens the Home create-actions sheet from outside this file (e.g. the shell's
/// center Create FAB). Kept as a thin public wrapper over the private sheet.
void showHomeCreateSheet(BuildContext context) => _showCreateSheet(context);

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _aurora;
  int _refreshKey = 0;
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _lastRefreshed = DateTime.now();
    // Purge any leftover update installer from a previous update (best-effort),
    // then check for a newer build once the home screen is shown.
    UpdateInstaller.cleanupAfterUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateSheet.maybeShow(context);
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
    if (mounted) setState(() => _lastRefreshed = DateTime.now());
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
          // V2 1.1: sliver scaffold — the compact header collapses while the
          // brand row + search stay pinned, and body sections are slivers so
          // later slices can reorder/lazy-load them individually.
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _Header(l: l, aurora: _aurora),
              SliverToBoxAdapter(
                child: _HomeBackdrop(
                  child: Padding(
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
                          return _CitizenDashboard(l: l, refreshKey: _refreshKey, lastRefreshed: _lastRefreshed);
                        },
                      ),
                      const SizedBox(height: 130),
                    ],
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Home canvas: a soft brand-tinted gradient with a low-opacity kolam
/// texture and two faint radial glows, so the body reads as an illustrated
/// surface instead of flat white. Theme-aware; clipped to the rounded top.
class _HomeBackdrop extends StatelessWidget {
  final Widget child;
  const _HomeBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF10162E), AppColors.darkBackground]
                : const [Color(0xFFF1F5FF), Color(0xFFFBFCFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
                top: -70,
                left: -60,
                child: _glow(AppColors.primaryLight.withOpacity(dark ? 0.12 : 0.16), 220)),
            Positioned(
                top: 20,
                right: -70,
                child: _glow(AppColors.gold.withOpacity(dark ? 0.08 : 0.12), 200)),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: KolamPattern(
                    color: (dark ? Colors.white : const Color(0xFF0A1128))
                        .withOpacity(dark ? 0.045 : 0.03),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _glow(Color c, double d) => IgnorePointer(
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
          ),
        ),
      );
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
            ? tr(en: 'Good Morning', ta: 'காலை வணக்கம்', hi: 'सुप्रभात', ml: 'സുപ്രഭാതം')
            : hour < 17
                ? tr(en: 'Good Afternoon', ta: 'மதிய வணக்கம்', hi: 'नमस्कार', ml: 'ഉച്ച വണക്കം')
                : tr(en: 'Good Evening', ta: 'மாலை வணக்கம்', hi: 'शुभ संध्या', ml: 'ശുഭ സായാഹ്നം');

        // V2 1.1 — compact collapsing header. The toolbar row (brand · language
        // · bell · avatar) and the search pill stay pinned; the aurora backdrop
        // and greeting collapse away as the user scrolls. ~190px expanded vs
        // the old fixed 268px block.
        return SliverAppBar(
          pinned: true,
          expandedHeight: 190,
          backgroundColor: AppColors.darkBg,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Image.asset(
                  'assets/images/fyc_mark.png',
                  width: 26,
                  height: 26,
                  errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, size: 14, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 10),
              const Text('FYC Connect',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ],
          ),
          actions: [
            _CircleBtn(
              icon: Icons.translate_rounded,
              tooltip: tr(en: 'Change Language', ta: 'மொழியை மாற்று', hi: 'भाषा बदलें', ml: 'ഭാഷ മാറ്റുക'),
              onTap: () => _showLanguagePicker(context),
            ),
            const SizedBox(width: 8),
            const _NotificationBell(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/me'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.15),
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
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
                // Greeting — bottom-aligned above the pinned search pill.
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 70),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$greetingEn, $firstName!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 3),
                        Text(tr(en: 'Everything you need, all in one place.', ta: 'உங்களுக்குத் தேவையான அனைத்தும் ஒரே இடத்தில்.', hi: 'आपकी ज़रूरत की हर चीज़, एक ही जगह।', ml: 'നിങ്ങൾക്ക് വേണ്ടതെല്ലാം, ഒരിടത്ത്.'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(62),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
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
                        child: Text(tr(en: 'Search services, events, and more...', ta: 'சேவைகள், நிகழ்வுகள் மற்றும் பலவற்றைத் தேடுங்கள்...', hi: 'सेवाएँ, कार्यक्रम और बहुत कुछ खोजें...', ml: 'സേവനങ്ങൾ, പരിപാടികൾ എന്നിവ തിരയുക...'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                      ),
                      Icon(Icons.tune_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                    ],
                  ),
                ),
              ),
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
          colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF43F5E).withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 8)),
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
                    Text(tr(en: 'Be a Hero', ta: 'ஒரு ஹீரோவாகுங்கள்', hi: 'हीरो बनें', ml: 'ഒരു ഹീറോ ആകൂ'),
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Icon(Icons.favorite, color: Colors.white.withOpacity(0.85), size: 15),
                  ],
                ),
                const SizedBox(height: 6),
                Text(tr(en: 'Donate Blood. Save Lives.', ta: 'இரத்த தானம் செய்யுங்கள். உயிர்களைக் காப்பாற்றுங்கள்.', hi: 'रक्तदान करें। जीवन बचाएँ।', ml: 'രക്തദാനം ചെയ്യൂ. ജീവൻ രക്ഷിക്കൂ.'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(tr(en: 'Your one donation can save up to 3 lives.', ta: 'உங்கள் ஒரு தானம் 3 உயிர்களைக் காப்பாற்றும்.', hi: 'आपका एक दान 3 जीवन तक बचा सकता है।', ml: 'നിങ്ങളുടെ ഒരു ദാനം 3 ജീവൻ വരെ രക്ഷിക്കാം.'),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr(en: 'Find Blood Donors', ta: 'இரத்த தானம் செய்பவர்களைக் கண்டறியுங்கள்', hi: 'रक्तदाता खोजें', ml: 'രക്തദാതാക്കളെ കണ്ടെത്തുക'),
                              style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, color: Color(0xFFE11D48), size: 16),
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

// ── Discover grid (the web-parity "Explore FYC" feature grid) ──

class _Service {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final String route;
  final String? pill;
  final Color? pillColor;
  final String? illustration;
  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.route,
    this.pill,
    this.pillColor,
    this.illustration,
  });
}

class _ServiceBento extends StatelessWidget {
  const _ServiceBento();

  @override
  Widget build(BuildContext context) {
    final services = <_Service>[
      _Service(
        title: tr(en: 'Blood Donation', ta: 'இரத்த தானம்', hi: 'रक्तदान', ml: 'രക്തദാനം'),
        subtitle: tr(en: 'Verified donors near you', ta: 'அருகில் சரிபார்க்கப்பட்ட நன்கொடையாளர்கள்', hi: 'आस-पास सत्यापित दाता', ml: 'അടുത്തുള്ള സ്ഥിരീകരിച്ച ദാതാക്കൾ'),
        icon: Icons.bloodtype_rounded,
        tint: AppColors.accent,
        route: '/blood-donation',
        illustration: 'blood',
      ),
      _Service(
        title: tr(en: 'Sports Arena', ta: 'விளையாட்டு', hi: 'खेल', ml: 'സ്പോർട്സ്'),
        subtitle: tr(en: 'Tournaments, chess & live scores', ta: 'போட்டிகள், சதுரங்கம் & நேரடி மதிப்பெண்', hi: 'टूर्नामेंट, शतरंज और लाइव स्कोर', ml: 'ടൂർണമെന്റുകൾ, ചെസ്സ്, തത്സമയ സ്കോർ'),
        icon: Icons.sports_cricket_rounded,
        tint: AppColors.warning,
        route: '/sports',
        illustration: 'sports',
      ),
      _Service(
        title: tr(en: 'Community Feed', ta: 'சமூகம்', hi: 'समुदाय', ml: 'സമൂഹം'),
        subtitle: tr(en: 'Threads, gallery & updates', ta: 'இழைகள், படத்தொகுப்பு & புதுப்பிப்புகள்', hi: 'थ्रेड्स, गैलरी और अपडेट', ml: 'ത്രെഡുകൾ, ഗാലറി, അപ്ഡേറ്റുകൾ'),
        icon: Icons.dynamic_feed_rounded,
        tint: AppColors.primaryLight,
        route: '/feed',
        illustration: 'community',
      ),
      _Service(
        title: tr(en: 'Report an Issue', ta: 'புகார் அளி', hi: 'समस्या दर्ज करें', ml: 'പ്രശ്നം രേഖപ്പെടുത്തുക'),
        subtitle: tr(en: 'Civic complaints, tracked to fix', ta: 'குடிமை புகார்கள், தீர்வு வரை கண்காணிப்பு', hi: 'नागरिक शिकायतें, समाधान तक ट्रैक', ml: 'പൗര പരാതികൾ, പരിഹാരം വരെ'),
        icon: Icons.campaign_rounded,
        tint: AppColors.gold,
        route: '/issues',
        illustration: 'report',
      ),
      _Service(
        title: tr(en: 'Green FYC', ta: 'பசுமை', hi: 'हरित', ml: 'ഹരിതം'),
        subtitle: tr(en: 'Tree drives & eco initiatives', ta: 'மரம் நடும் இயக்கம் & சூழல் முயற்சிகள்', hi: 'वृक्षारोपण और पर्यावरण पहल', ml: 'വൃക്ഷത്തൈ & പരിസ്ഥിതി സംരംഭങ്ങൾ'),
        icon: Icons.eco_rounded,
        tint: AppColors.success,
        route: '/green',
        illustration: 'green',
        pill: tr(en: 'Eco', ta: 'சூழல்', hi: 'इको', ml: 'ഇക്കോ'),
        pillColor: AppColors.success,
      ),
      _Service(
        title: tr(en: 'Skills Directory', ta: 'திறன் அடைவு', hi: 'कौशल निर्देशिका', ml: 'നൈപുണ്യ ഡയറക്ടറി'),
        subtitle: tr(en: 'Carpenters, electricians, tutors', ta: 'தச்சர், மின்சாரி, ஆசிரியர்', hi: 'बढ़ई, इलेक्ट्रीशियन, शिक्षक', ml: 'ആശാരി, ഇലക്ട്രീഷ്യൻ, ട്യൂട്ടർ'),
        icon: Icons.handyman_rounded,
        tint: AppColors.primary,
        route: '/community',
        illustration: 'skills',
        pill: tr(en: 'New', ta: 'புதியது', hi: 'नया', ml: 'പുതിയത്'),
        pillColor: AppColors.primaryLight,
      ),
      _Service(
        title: tr(en: 'Opportunities', ta: 'வாய்ப்புகள்', hi: 'अवसर', ml: 'അവസരങ്ങൾ'),
        subtitle: tr(en: 'Jobs, scholarships & community gigs', ta: 'வேலை, உதவித்தொகை & பணிகள்', hi: 'नौकरियाँ, छात्रवृत्ति और काम', ml: 'ജോലി, സ്കോളർഷിപ്പ്, ഗിഗുകൾ'),
        icon: Icons.work_rounded,
        tint: AppColors.gold,
        route: '/opportunities',
        illustration: 'opportunities',
        pill: tr(en: 'Jobs', ta: 'வேலை', hi: 'नौकरी', ml: 'ജോലി'),
        pillColor: AppColors.gold,
      ),
      _Service(
        title: tr(en: 'Events', ta: 'நிகழ்வுகள்', hi: 'कार्यक्रम', ml: 'പരിപാടികൾ'),
        subtitle: tr(en: 'Festivals & meetings — register', ta: 'விழாக்கள் & கூட்டங்கள் — பதிவு', hi: 'त्योहार और बैठकें — पंजीकरण', ml: 'ഉത്സവങ്ങൾ & മീറ്റിംഗുകൾ — രജിസ്റ്റർ'),
        icon: Icons.event_rounded,
        tint: AppColors.primaryLight,
        route: '/events',
        illustration: 'events',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: tr(en: 'Explore FYC', ta: 'FYC ஐ ஆராயுங்கள்', hi: 'FYC एक्सप्लोर करें', ml: 'FYC പര്യവേക്ഷണം'),
          onViewAll: () => _showMoreSheet(context),
        ),
        const SizedBox(height: 12),
        const _FeaturedSportsHero(),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: services.length,
          itemBuilder: (_, i) {
            final s = services[i];
            return DSFeatureCard(
              icon: s.icon,
              title: s.title,
              subtitle: s.subtitle,
              tint: s.tint,
              pillLabel: s.pill,
              pillColor: s.pillColor,
              illustration: s.illustration,
              actionLabel: tr(en: 'Open', ta: 'திற', hi: 'खोलें', ml: 'തുറക്കുക'),
              onTap: () => context.push(s.route),
            );
          },
        ),
      ],
    );
  }
}

/// A full-width featured hero for the live sports feature — brand gradient, a
/// large sports spot-illustration and a Lottie "live" pulse. The visual anchor
/// of the Explore section.
class _FeaturedSportsHero extends StatelessWidget {
  const _FeaturedSportsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => context.push('/sports'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LivePulse(size: 22),
                            const SizedBox(width: 6),
                            Text(
                              tr(en: 'LIVE SPORTS', ta: 'நேரடி விளையாட்டு', hi: 'लाइव खेल', ml: 'ലൈവ് സ്പോർട്സ്'),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(en: 'Sports Arena', ta: 'விளையாட்டு அரங்கம்', hi: 'खेल एरिना', ml: 'സ്പോർട്സ് അരീന'),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tr(en: 'Tournaments, chess & live scores', ta: 'போட்டிகள், சதுரங்கம் & நேரடி மதிப்பெண்', hi: 'टूर्नामेंट, शतरंज और लाइव स्कोर', ml: 'ടൂർണമെന്റുകൾ, ചെസ്സ്, തത്സമയ സ്കോർ'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr(en: 'Watch live', ta: 'நேரடியாகப் பார்', hi: 'लाइव देखें', ml: 'ലൈവ് കാണുക'),
                                style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const SpotIllustration('sports', size: 116),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick Actions row (mockup: Blood Request · Report · Create · Weekly · SOS) ──

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, Color, String, VoidCallback)>[
      (Icons.bloodtype_rounded, const Color(0xFFEF4444),
          tr(en: 'Blood\nRequest', ta: 'இரத்தம்', hi: 'रक्त', ml: 'രക്തം'),
          () => context.push('/blood-donation')),
      (Icons.report_problem_rounded, const Color(0xFFF59E0B),
          tr(en: 'Report\nIssue', ta: 'புகார்', hi: 'शिकायत', ml: 'റിപ്പോർട്ട്'),
          () => context.push('/issues')),
      (Icons.event_rounded, const Color(0xFF16A34A),
          tr(en: 'Create\nEvent', ta: 'நிகழ்வு', hi: 'कार्यक्रम', ml: 'ഇവന്റ്'),
          () => showHomeCreateSheet(context)),
      (Icons.emoji_events_rounded, const Color(0xFFD97706),
          tr(en: 'Weekly\nGame', ta: 'விளையாட்டு', hi: 'खेल', ml: 'ഗെയിം'),
          () => context.push('/sports')),
      (Icons.emergency_share_rounded, const Color(0xFFDC2626),
          tr(en: 'Emergency\nContacts', ta: 'அவசரம்', hi: 'आपातकाल', ml: 'അടിയന്തരം'),
          () => showSosSheet(context)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: tr(en: 'Quick Actions', ta: 'விரைவு செயல்கள்', hi: 'त्वरित कार्य', ml: 'ദ്രുത പ്രവർത്തനങ്ങൾ')),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, color, label, onTap) in actions)
              Expanded(
                // Shadow on the outer Container; Ink paints the gradient; the
                // InkWell sits above it so the ripple isn't hidden.
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: context.isDark
                              ? [color.withOpacity(0.20), context.cSurface]
                              : [color.withOpacity(0.10), Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: context.isDark
                                ? context.cBorder.withOpacity(0.5)
                                : color.withOpacity(0.22)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: Icon(icon, color: Colors.white, size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  color: context.cTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
      (1500, 'Youth Network', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      (1200, 'Blood Donors', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      (80, 'Events Hosted', const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
      (5000, 'Lives Impacted', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
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
                  boxShadow: [
                    BoxShadow(
                      color: s.$3.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    DSAnimatedCounter(
                        value: s.$1,
                        suffix: '+',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.isDark ? s.$3.withOpacity(0.95) : s.$3)),
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
  final Widget? trailing;
  const _SectionHeader({required this.title, this.onViewAll, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText, letterSpacing: -0.3)),
        if (trailing != null)
          trailing!
        else if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
      ],
    );
  }
}

// ── Bottom Bar with center Create FAB ────────────────────────────────────────

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

// ── Create sheet ─────────────────────────────────────────────────────────────

void _showCreateSheet(BuildContext context) {
  final actions = <(IconData, String, String, Color)>[
    (Icons.edit_note_rounded, 'Share a Post', '/feed/create', const Color(0xFF0B6E4F)),
    (Icons.water_drop, 'Register as Donor', '/blood-donation/register', const Color(0xFFEF4444)),
    (Icons.campaign, 'Report an Issue', '/issues', const Color(0xFFEAB308)),
    (Icons.eco, 'Register a Tree', '/green/register', const Color(0xFF16A34A)),
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
  final IconData icon;
  final String label, route;
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
          _MenuItem(Icons.water_drop_rounded, ta ? 'இரத்த தானம்' : 'Blood Donors', '/blood-donation', const Color(0xFFEF4444)),
          _MenuItem(Icons.celebration_rounded, l.events, '/events', const Color(0xFF8B5CF6)),
          _MenuItem(Icons.castle_rounded, ta ? 'சதுரங்கம்' : 'Chess', '/chess', const Color(0xFF334155)),
          _MenuItem(Icons.emoji_events_rounded, ta ? 'விளையாட்டு' : 'Sports Hub', '/sports', const Color(0xFFF97316)),
          _MenuItem(Icons.report_problem_rounded, l.publicIssues, '/issues', AppColors.warning),
          _MenuItem(Icons.travel_explore_rounded, ta ? 'புகார் கண்காணிப்பு' : 'Track Issues', '/issues/track', const Color(0xFF14B8A6)),
          _MenuItem(Icons.badge_rounded, l.membership, '/membership', AppColors.primary),
          _MenuItem(Icons.contacts_rounded, l.directory, '/directory', const Color(0xFF2563EB)),
          _MenuItem(Icons.work_rounded, ta ? 'வாய்ப்புகள்' : 'Opportunities', '/opportunities', const Color(0xFFD97706)),
        ],
      ),
      (
        ta ? 'சமூகம்' : 'Community',
        [
          _MenuItem(Icons.eco_rounded, ta ? 'பசுமை FYC' : 'Green FYC', '/green', const Color(0xFF047857)),
          _MenuItem(Icons.campaign_rounded, ta ? 'அறிவிப்புகள்' : 'Announcements', '/announcements', const Color(0xFFF59E0B)),
          _MenuItem(Icons.photo_library_rounded, ta ? 'புகைப்படங்கள்' : 'Gallery', '/gallery', const Color(0xFFD97706)),
          _MenuItem(Icons.groups_rounded, ta ? 'உறுப்பினர்கள்' : 'Members', '/members', const Color(0xFFEC4899)),
        ],
      ),
      (
        ta ? 'கணக்கு' : 'Account',
        [
          _MenuItem(Icons.settings_rounded, ta ? 'அமைப்புகள்' : 'Settings', '/settings', const Color(0xFF475569)),
          _MenuItem(Icons.school_rounded, ta ? 'சான்றிதழ்' : 'Certificates', '/certificate', const Color(0xFF6366F1)),
          _MenuItem(Icons.info_rounded, ta ? 'எங்களைப் பற்றி' : 'About', '/about', AppColors.textSecondary),
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
                children: section.$2
                    .asMap()
                    .entries
                    .map((e) => FadeSlideIn(
                          delay: Duration(milliseconds: e.key * 45),
                          child: _BentoTile(item: e.value),
                        ))
                    .toList(),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [item.color, Color.lerp(item.color, Colors.black, 0.30)!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withOpacity(context.isDark ? 0.35 : 0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(item.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText, height: 1.15),
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
    if (!_loaded) {
      // Card-shaped placeholder while /events loads, so the section doesn't
      // pop in and shift the page (the section still collapses when there is
      // genuinely no upcoming event).
      return const DSSkeletonBlock(width: double.infinity, height: 92, radius: 18);
    }
    if (_event == null) return const SizedBox.shrink();
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
          // Skeleton shaped like the real update rows — never a bare spinner.
          Column(
            children: List.generate(
              2,
              (i) => Padding(
                padding: EdgeInsets.only(bottom: i == 0 ? 10 : 0),
                child: Row(
                  children: [
                    const DSSkeletonBlock(width: 40, height: 40, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          DSSkeletonBlock(width: double.infinity, height: 13, radius: 6),
                          SizedBox(height: 7),
                          DSSkeletonBlock(width: 160, height: 11, radius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.gold),
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
          // Numeric metrics count up on first build; non-numeric values
          // ("24/7", em dash) render as plain text.
          Builder(builder: (context) {
            final style = TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.cText);
            final n = int.tryParse(value);
            return n != null
                ? DSAnimatedCounter(value: n, style: style)
                : Text(value, style: style);
          }),
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

/// Live cross-tournament cricket scores on Home — visible to every user, and
/// auto-refreshing so scores "stream" while the screen is open. Falls back to
/// recent results when nothing is live; hides entirely when there is no sport.
class _LiveScoresSection extends StatefulWidget {
  const _LiveScoresSection();

  @override
  State<_LiveScoresSection> createState() => _LiveScoresSectionState();
}

class _LiveScoresSectionState extends State<_LiveScoresSection> {
  List<Map<String, dynamic>> _live = const [];
  List<Map<String, dynamic>> _recent = const [];
  List<Map<String, dynamic>> _upcoming = const [];
  bool _loaded = false;
  bool _fetching = false; // in-flight guard so a slow poll can't stack another
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final res = await sl<ApiClient>().dio.get('/api/v1/sports/live');
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      List<Map<String, dynamic>> pick(String k) =>
          ((data[k] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
      setState(() {
        _live = pick('live');
        _recent = pick('recent');
        _upcoming = pick('upcoming');
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    // Precedence: live > recent > upcoming; hide only when all three are empty.
    final String mode;
    final List<Map<String, dynamic>> items;
    if (_live.isNotEmpty) {
      mode = 'live';
      items = _live;
    } else if (_recent.isNotEmpty) {
      mode = 'recent';
      items = _recent;
    } else if (_upcoming.isNotEmpty) {
      mode = 'upcoming';
      items = _upcoming;
    } else {
      return const SizedBox.shrink();
    }
    final title = mode == 'live'
        ? tr(en: 'Live Now', ta: 'நேரலை', hi: 'लाइव', ml: 'തത്സമയം')
        : mode == 'recent'
            ? tr(en: 'Recent Results', ta: 'சமீபத்திய முடிவுகள்', hi: 'हाल के परिणाम', ml: 'സമീപകാല ഫലങ്ങൾ')
            : tr(en: 'Upcoming Matches', ta: 'வரவிருக்கும் போட்டிகள்', hi: 'आगामी मैच', ml: 'വരാനിരിക്കുന്ന മത്സരങ്ങൾ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (mode == 'live') ...[
              const DSBadge(kind: DSBadgeKind.live),
              const SizedBox(width: 8),
            ],
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText, letterSpacing: -0.3)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/sports'),
              behavior: HitTestBehavior.opaque,
              child: Text(
                tr(en: 'View all', ta: 'அனைத்தும்', hi: 'सभी देखें', ml: 'എല്ലാം'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MatchCard(data: items[i], mode: mode),
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String mode; // 'live' | 'recent' | 'upcoming'
  const _MatchCard({required this.data, required this.mode});

  /// Chase state, localized client-side from the structured fields the API
  /// sends (no server-authored English).
  String? _liveNote() {
    if (data['innings_break'] == true) {
      return tr(en: 'Innings break', ta: 'இன்னிங்ஸ் இடைவேளை', hi: 'पारी विश्राम', ml: 'ഇന്നിംഗ്സ് ബ്രേക്ക്');
    }
    final needed = (data['runs_needed'] as num?)?.toInt();
    if (needed == null) return null;
    if (needed <= 0) {
      return tr(en: 'Target reached', ta: 'இலக்கை எட்டியது', hi: 'लक्ष्य पूरा', ml: 'ലക്ഷ്യത്തിലെത്തി');
    }
    return tr(
        en: 'Need $needed run${needed == 1 ? '' : 's'}',
        ta: '$needed ரன் தேவை',
        hi: '$needed रन चाहिए',
        ml: '$needed റൺ വേണം');
  }

  @override
  Widget build(BuildContext context) {
    final live = mode == 'live';
    final batting = data['batting_team'] as String?;
    final String scoreLine;
    if (live) {
      scoreLine = '${batting != null ? '$batting  ' : ''}${data['summary'] ?? ''}';
    } else if (mode == 'recent') {
      scoreLine = (data['result'] as String?) ?? tr(en: 'Completed', ta: 'முடிந்தது', hi: 'पूर्ण', ml: 'പൂർത്തിയായി');
    } else {
      scoreLine = (data['venue'] as String?) ?? tr(en: 'Scheduled', ta: 'திட்டமிடப்பட்டது', hi: 'निर्धारित', ml: 'ഷെഡ്യൂൾ ചെയ്തു');
    }
    final note = live ? _liveNote() : null;
    return GestureDetector(
      onTap: () {
        final fid = data['fixture_id'] as String?;
        if (live && fid != null) {
          // Open the read-only live scorecard (batsman/bowler streaming view).
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LiveScorecardScreen(
              fixtureId: fid,
              teamA: (data['team_a'] as String?) ?? '',
              teamB: (data['team_b'] as String?) ?? '',
            ),
          ));
        } else {
          context.push('/sports');
        }
      },
      child: Container(
        width: 258,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (live) ...[
                  const DSBadge(kind: DSBadgeKind.live),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    (data['tournament_name'] as String?) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.cTextSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${data['team_a']}  vs  ${data['team_b']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.cText),
            ),
            const SizedBox(height: 6),
            Text(
              scoreLine,
              maxLines: live ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: live ? 15 : 12.5,
                fontWeight: live ? FontWeight.w800 : FontWeight.w600,
                color: live
                    ? AppColors.primary
                    : (mode == 'recent' ? AppColors.success : context.cTextSecondary),
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: context.cTextSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitizenDashboard extends StatelessWidget {
  final AppLocalizations l;
  final int refreshKey;
  final DateTime? lastRefreshed;
  const _CitizenDashboard({required this.l, required this.refreshKey, this.lastRefreshed});

  @override
  Widget build(BuildContext context) {
    // V2 1.3 — IA order (docs/v2/home-information-architecture.md):
    // time-sensitive and actionable first (announcements, actions, live feed,
    // events, blood), evergreen dailies after, impact stats near the bottom.
    // The announcements slot becomes the hero carousel in slice 2.1.
    // V2 1.4 — sections enter with a top-to-bottom stagger (FadeSlideIn is
    // reduce-motion aware, so this is a no-op when animations are disabled).
    final sections = <Widget>[
      const _AnnouncementsBar(),
      const _LiveScoresSection(),
      const _QuickActions(),
      const _ServiceBento(),
      const _LiveUpdates(),
      const _NextEventCard(),
      const _BeAHeroCard(),
      _SectionHeader(
        title: 'Today',
        trailing: lastRefreshed != null ? LastUpdatedPill(timestamp: lastRefreshed!) : null,
      ),
      DailyNewsCard(key: ValueKey('news-$refreshKey')),
      DailyThirukkuralCard(key: ValueKey('kural-$refreshKey')),
      WeatherCard(key: ValueKey('weather-$refreshKey')),
      GoldPriceCard(key: ValueKey('gold-$refreshKey')),
      _TodayImpactHub(l: l),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0)
            SizedBox(
                height: sections[i - 1] is _SectionHeader
                    ? 12
                    : (sections[i - 1] is DailyNewsCard ||
                            sections[i - 1] is DailyThirukkuralCard ||
                            sections[i - 1] is WeatherCard
                        ? 14
                        : 22)),
          FadeSlideIn(
            delay: Duration(milliseconds: (i * 60).clamp(0, 480)),
            child: sections[i],
          ),
        ],
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
          title: 'Green FYC Drives',
          subtitle: 'Tree plantation & clean-ups',
          icon: Icons.eco,
          iconColor: const Color(0xFF16A34A),
          onViewAll: () => context.push('/green'),
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
                title: 'Team Approvals',
                subtitle: 'Review tournament teams',
                icon: Icons.pending_actions,
                iconColor: const Color(0xFFF59E0B),
                onViewAll: () => context.push('/sports'),
                onTap: () => context.push('/sports'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                sectionTitle: 'Community',
                title: 'Members',
                subtitle: 'Club member directory',
                icon: Icons.people,
                iconColor: const Color(0xFF3B82F6),
                onViewAll: () => context.push('/members'),
                onTap: () => context.push('/members'),
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
          title: 'Track Reported Issues',
          subtitle: 'Status of citizen reports',
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
