import 'package:flutter/material.dart';
import '../tokens.dart';
import 'sos_sheet.dart';

/// The v2 navigation shell: 4 tabs (Home · Play · Serve · Me) + a persistent
/// SOS control reachable from every tab, per the locked IA decision (no
/// separate Community tab — community lives inside Home).
///
/// This widget is NOT wired as the app's live entry point yet. Cutting over
/// production navigation happens in Sprint 2, once Home/Play/Serve/Me each
/// have real migrated content — switching today would orphan every screen
/// that hasn't been sorted into a bucket yet (chess, green, gallery,
/// directory, …), which would be a regression, not a foundation.
class AppShellV2 extends StatefulWidget {
  /// Real screens plug in here once each bucket has content (Sprint 2+).
  /// Defaults to placeholders so the shell can be previewed standalone today.
  final List<Widget>? tabs;

  const AppShellV2({super.key, this.tabs});

  @override
  State<AppShellV2> createState() => _AppShellV2State();
}

class _AppShellV2State extends State<AppShellV2> {
  int _index = 0;

  static const _tabMeta = [
    ('Home', 'ஊர்', Icons.home_rounded),
    ('Play', 'விளையாட்டு', Icons.sports_cricket_rounded),
    ('Serve', 'சேவை', Icons.volunteer_activism_rounded),
    ('Me', 'என்', Icons.person_rounded),
  ];

  List<Widget> get _bodies => widget.tabs ?? List.generate(4, (i) => _PlaceholderTab(label: _tabMeta[i].$1));

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
