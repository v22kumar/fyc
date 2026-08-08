import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/design_system/surfaces/glass_card.dart';
import 'package:fyc_connect/core/design_system/surfaces/mesh_backdrop.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';

/// The launcher, in the layout Home puts it in.
///
/// Home itself cannot be pumped in a widget test without standing up most of
/// the app's dependency graph, so this covers the part that changed: eight
/// glass tiles, four across, inside a mesh ground, inside a scrolling sliver —
/// which is the nesting where a BackdropFilter is most likely to assert.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
  });

  const tiles = [
    ('Blood', Color(0xFFE0245E)),
    ('Sports', Color(0xFFF59E0B)),
    ('Feed', Color(0xFF14B8A6)),
    ('Report', Color(0xFF8B5CF6)),
    ('Green', Color(0xFF22C55E)),
    ('Work', Color(0xFF0E7C66)),
    ('Events', Color(0xFF3B82F6)),
    ('More', Color(0xFF64748B)),
  ];

  Widget subject({double scroll = 0}) => MaterialApp(
        theme: AppTheme.darkFor('en'),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: MeshBackdrop(
                  scroll: scroll,
                  colors: const [
                    Color(0xFF0E7C66), Color(0xFF1E3A8A),
                    Color(0xFF7C2D6B), Color(0xFFB45309),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.80,
                      ),
                      itemCount: tiles.length,
                      itemBuilder: (_, i) => GlassCard(
                        tint: tiles[i].$2,
                        onTap: () {},
                        child: Center(child: Text(tiles[i].$1)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('eight glass tiles render inside a mesh inside a sliver',
      (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(subject());
    await t.pump(const Duration(milliseconds: 200));

    expect(tester_exception(), isNull,
        reason: 'a BackdropFilter nested in a mesh inside a sliver is the '
            'combination most likely to assert');
    for (final (label, _) in tiles) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('all eight fit within one phone screen', (t) async {
    // The whole point of the change: seven tiles at two across ran to three
    // screens. Eight at four across has to fit in one, or nothing was gained.
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(subject());
    await t.pump(const Duration(milliseconds: 200));

    final grid = t.getRect(find.byType(GridView));
    expect(grid.height, lessThan(320),
        reason: 'eight tiles in two rows should be about 220 points, not three '
            'screens');
  });

  testWidgets('the mesh repaints on scroll without disturbing the tiles',
      (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(subject());
    final before = t.getRect(find.text('Blood'));

    await t.pumpWidget(subject(scroll: 400));
    await t.pump(const Duration(milliseconds: 100));

    expect(t.getRect(find.text('Blood')), before,
        reason: 'the ground drifts; the content must not move with it');
    expect(tester_exception(), isNull);
  });
}

Object? tester_exception() =>
    TestWidgetsFlutterBinding.instance.takeException();
