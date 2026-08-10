import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../features/auth/presentation/widgets/sign_in_sheet.dart';
import '../../services/shake_detector.dart';
import '../../services/sos_service.dart';
import 'package:go_router/go_router.dart';
import '../patterns/kolam_background.dart';
import '../tokens.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

/// The live navigation shell (mounted at `/app`): 4 tabs (Home · Feed · Play ·
/// Serve) + a persistent SOS control reachable from every tab. Account/profile
/// access ("Me") lives behind the avatar in Home's top-right corner instead of
/// a fifth tab — that spot already existed and was previously wired straight
/// to Settings, skipping the richer Me hub (profile card, membership,
/// directory). Feed and Community remain distinct destinations — Community
/// (member directory) is still reached via Home's Services sheet, not a
/// bottom-nav tab.
class AppShellV2 extends StatefulWidget {
  /// The 4 tab bodies, index-aligned with `_tabMeta` (Home/Feed/Play/Serve).
  /// Wired to real screens by `_appShellBuilder` in app_router.dart. Defaults
  /// to placeholders so the shell can be previewed standalone (design-system
  /// gallery, widget tests) without a full app context.
  final List<Widget>? tabs;

  /// Tapped from the center Create FAB (the yellow "+" in the mockup). The
  /// router wires this to the Home create-actions sheet.
  final VoidCallback? onCreate;

  /// Whether opening the app asks who you are, once, before anything else.
  ///
  /// The club's call, and it overrides the older "no door" stance: a member
  /// should be met by the sign-in sheet the moment the app opens, so signing in
  /// is the default rather than something you have to go looking for. Ignoring
  /// it is a real answer — dismiss and the whole noticeboard is still there,
  /// exactly as before. Once signed in, the session is stored and this never
  /// appears again.
  ///
  /// Off by default so the design-system gallery and widget tests can mount the
  /// shell without a modal opening over them.
  final bool askWhoYouAreOnLaunch;

  const AppShellV2({
    super.key,
    this.tabs,
    this.onCreate,
    this.askWhoYouAreOnLaunch = false,
  });

  /// Whether this launch has already asked. Once per launch, not once per
  /// rebuild: the shell rebuilds on every tab change and on `/app` ↔ `/v2`, and
  /// a sheet that reappears after being dismissed is nagging, not asking.
  ///
  /// Process-lifetime on purpose — "next launch" means the next launch, and a
  /// member who said no is left alone until then. Tests share one process, so
  /// they reset it between cases.
  @visibleForTesting
  static bool askedThisLaunch = false;

  @override
  State<AppShellV2> createState() => _AppShellV2State();
}

/// Vertical space the floating SOS disc and the docked "+" occupy above the
/// navigation bar. Published to the tab bodies as bottom padding.
const double _floatingChromeHeight = 84;

class _AppShellV2State extends State<AppShellV2> {
  int _index = 0;
  ShakeDetector? _shake;
  DateTime? _lastBackPress;

  // Ids, not literals: the four labels now come from the same registry as the
  // rest of the app, so Hindi and Malayalam get them too. The old pair of
  // hardcoded strings could only ever have served English and Tamil — and in
  // practice served only English, because the Tamil half was never read.
  static const _tabMeta = [
    ('nav_home', Icons.home_rounded),
    ('nav_feed', Icons.dynamic_feed_rounded),
    ('nav_play', Icons.sports_cricket_rounded),
    ('nav_serve', Icons.volunteer_activism_rounded),
  ];

  List<Widget> get _bodies =>
      widget.tabs ?? List.generate(_tabMeta.length, (i) => _PlaceholderTab(label: trId(_tabMeta[i].$1)));

  @override
  void initState() {
    super.initState();
    _initShake();
    // React live to the Safety-settings toggle — no app restart needed.
    SosService.shakeToTriggerListenable.addListener(_applyShakePref);
    if (widget.askWhoYouAreOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askWhoYouAre());
    }
  }

  /// Meet the member at the door, unless we already know them.
  ///
  /// The wait matters. At this point the startup session check may still be in
  /// flight, and the bloc's state is `AuthInitial` — which is not "signed out",
  /// it is "we haven't looked yet". Asking on that would put a login sheet in
  /// front of somebody who has been signed in for months, every single launch.
  /// So we wait for the check to settle, and only ask if the answer is really
  /// nobody. The timeout is the honest fallback: if the keyring or the network
  /// never answers, asking is better than a door that never opens.
  Future<void> _askWhoYouAre() async {
    if (AppShellV2.askedThisLaunch || !mounted) return;
    AppShellV2.askedThisLaunch = true;

    final auth = context.read<AuthBloc>();
    var state = auth.state;
    if (state is! AuthAuthenticated && state is! AuthUnauthenticated) {
      state = await auth.stream
          .firstWhere((s) => s is AuthAuthenticated || s is AuthUnauthenticated)
          .timeout(const Duration(seconds: 5), onTimeout: () => auth.state);
    }
    if (state is AuthAuthenticated) return; // we know them — never ask again
    if (!mounted) return;
    await SignInSheet.ensure(context);
  }

  // Shake-to-trigger opens the same Safety Center sheet as the SOS button —
  // it never fires an alert by itself, just gives a fast, no-look way to
  // reach the sheet so the user can confirm/send. Best-effort: a missing
  // accelerometer plugin (e.g. widget tests, unsupported platform) must
  // never crash the shell, only silently skip the feature.
  Future<void> _initShake() async {
    try {
      // Seed the live notifier from storage, then apply. (getShakeToTrigger
      // updates the notifier; call apply directly since the value may be
      // unchanged from its default and so wouldn't notify.)
      await SosService.getShakeToTrigger();
      _applyShakePref();
    } catch (_) {}
  }

  void _applyShakePref() {
    try {
      if (SosService.shakeToTriggerListenable.value) {
        _shake ??= ShakeDetector(onShake: () {
          // Opens the trigger screen — it does not send anything. The hold and
          // the countdown are still in front of the alert, which is what makes
          // a hair-trigger like this affordable at all.
          if (mounted) context.push('/sos');
        });
        _shake!.start();
      } else {
        _shake?.stop();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    SosService.shakeToTriggerListenable.removeListener(_applyShakePref);
    _shake?.stop();
    super.dispose();
  }

  void _onSosTap() {
    // A full screen with one thing on it, not a sheet with four buttons and a
    // list of claims. See docs/safety/01-architecture.md §8.1.
    context.push('/sos');
  }

  // The shell sits at the bottom of the GoRouter stack (reached via
  // context.go(), which replaces history), so a system back press here has
  // nothing left to pop and Flutter's default behaviour closes the app
  // instantly. Require a second press within 2s instead, with a toast on the
  // first one — the standard Android "press back again to exit" pattern.
  void _onBackInvoked(bool didPop, Object? result) {
    if (didPop) return;
    final now = DateTime.now();
    if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(trId('press_back_again_to_exit')),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBackInvoked,
      child: Scaffold(
        backgroundColor: context.dsBackground,
        // Kolam texture sits between the scaffold color and the tabs —
        // visible wherever a tab leaves its background transparent
        // (docs/design/md3-elite-redesign.md §3.4).
        body: KolamBackground(
          child: Stack(
            children: [
              // The floating controls draw over the tab body, so the body has
              // to know they are there. Publishing their height as bottom
              // padding means every tab — and every tab added later — clears
              // them, instead of each screen guessing a magic number. Before
              // this, Home's last card sat under the "+" and the SOS disc
              // covered the card behind it.
              MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.of(context).padding.copyWith(
                        bottom: MediaQuery.of(context).padding.bottom +
                            _floatingChromeHeight,
                      ),
                ),
                child: IndexedStack(index: _index, children: _bodies),
              ),
              // Persistent SOS control — reachable from every tab, never buried.
              Positioned(
                right: DSSpacing.sm,
                bottom: 90,
                child: _SosButton(onTap: _onSosTap),
              ),
            ],
          ),
        ),
        // Center Create FAB (the yellow "+" in the mockup), docked over the nav
        // bar between Play and Serve. Only shown once a create handler is wired.
        floatingActionButton: widget.onCreate == null
            ? null
            : FloatingActionButton(
                onPressed: widget.onCreate,
                backgroundColor: DSColors.amber500,
                foregroundColor: AppColors.background,
                elevation: DSElevation.floating,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_rounded, size: 30),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: context.dsSurface,
          indicatorColor: context.dsAccent.withValues(alpha: 0.15),
          destinations: [
            for (final (id, icon) in _tabMeta)
              NavigationDestination(
                icon: Icon(icon, color: context.dsTextSecondary),
                selectedIcon: Icon(icon, color: context.dsAccent),
                label: trId(id),
                tooltip: trId(id),
              ),
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SosButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DSColors.danger,
      shape: const CircleBorder(),
      elevation: DSElevation.floating,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(Icons.sos_rounded, color: AppColors.background, size: 22),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$label tab\n(content migrates here in Sprint 2)',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.dsTextSecondary),
      ),
    );
  }
}
