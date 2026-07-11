import 'package:flutter/material.dart';
import '../../services/shake_detector.dart';
import '../../services/sos_service.dart';
import '../tokens.dart';
import 'sos_sheet.dart';

/// The live navigation shell (mounted at `/app`): 5 tabs (Home · Feed · Play ·
/// Serve · Me) + a persistent SOS control reachable from every tab. Feed and
/// Community remain distinct destinations — Community (member directory) is
/// still reached via Home's Services sheet, not a bottom-nav tab.
class AppShellV2 extends StatefulWidget {
  /// The 5 tab bodies, index-aligned with `_tabMeta` (Home/Feed/Play/Serve/Me).
  /// Wired to real screens by `_appShellBuilder` in app_router.dart. Defaults
  /// to placeholders so the shell can be previewed standalone (design-system
  /// gallery, widget tests) without a full app context.
  final List<Widget>? tabs;

  /// Tapped from the center Create FAB (the yellow "+" in the mockup). The
  /// router wires this to the Home create-actions sheet.
  final VoidCallback? onCreate;

  const AppShellV2({super.key, this.tabs, this.onCreate});

  @override
  State<AppShellV2> createState() => _AppShellV2State();
}

class _AppShellV2State extends State<AppShellV2> {
  int _index = 0;
  ShakeDetector? _shake;

  static const _tabMeta = [
    ('Home', 'ஊர்', Icons.home_rounded),
    ('Feed', 'செய்திகள்', Icons.dynamic_feed_rounded),
    ('Play', 'விளையாட்டு', Icons.sports_cricket_rounded),
    ('Serve', 'சேவை', Icons.volunteer_activism_rounded),
    ('Me', 'என்', Icons.person_rounded),
  ];

  List<Widget> get _bodies =>
      widget.tabs ?? List.generate(_tabMeta.length, (i) => _PlaceholderTab(label: _tabMeta[i].$1));

  @override
  void initState() {
    super.initState();
    _initShake();
  }

  // Shake-to-trigger opens the same Safety Center sheet as the SOS button —
  // it never fires an alert by itself, just gives a fast, no-look way to
  // reach the sheet so the user can confirm/send. Best-effort: a missing
  // accelerometer plugin (e.g. widget tests, unsupported platform) must
  // never crash the shell, only silently skip the feature.
  Future<void> _initShake() async {
    try {
      final enabled = await SosService.getShakeToTrigger();
      if (!mounted || !enabled) return;
      _shake = ShakeDetector(onShake: () {
        if (mounted) showSosSheet(context);
      });
      _shake!.start();
    } catch (_) {}
  }

  @override
  void dispose() {
    _shake?.stop();
    super.dispose();
  }

  void _onSosTap() {
    // Real SOS: location SMS to trusted contacts + emergency dial.
    showSosSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dsBackground,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _bodies),
          // Persistent SOS control — reachable from every tab, never buried.
          Positioned(
            right: DSSpacing.sm,
            bottom: 90,
            child: _SosButton(onTap: _onSosTap),
          ),
        ],
      ),
      // Center Create FAB (the yellow "+" in the mockup), docked over the nav
      // bar between Play and Serve. Only shown once a create handler is wired.
      floatingActionButton: widget.onCreate == null
          ? null
          : FloatingActionButton(
              onPressed: widget.onCreate,
              backgroundColor: DSColors.amber500,
              foregroundColor: Colors.white,
              elevation: DSElevation.floating,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: context.dsSurface,
        indicatorColor: context.dsAccent.withOpacity(0.15),
        destinations: [
          for (final (en, ta, icon) in _tabMeta)
            NavigationDestination(
              icon: Icon(icon, color: context.dsTextSecondary),
              selectedIcon: Icon(icon, color: context.dsAccent),
              label: en,
              tooltip: ta,
            ),
        ],
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
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(Icons.sos_rounded, color: Colors.white, size: 22),
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
