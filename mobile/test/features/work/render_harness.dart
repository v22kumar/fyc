import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';
import 'package:fyc_connect/features/work/domain/entities/work_entities.dart';
import 'package:fyc_connect/features/work/domain/repositories/work_repository.dart';
import 'package:fyc_connect/features/work/presentation/bloc/work_bloc.dart';
import 'package:fyc_connect/features/work/presentation/screens/create_listing_screen.dart';
import 'package:fyc_connect/features/work/presentation/screens/work_home_screen.dart';
import 'package:fyc_connect/features/work/presentation/widgets/listing_card.dart';

/// Photographs of the Work index, for a person to look at.
///
/// Named without the `_test` suffix on purpose so `flutter test` never
/// collects it — it drives the real widget tree and does not always shut down
/// cleanly headless, which would fail CI over screenshots nobody asked for.
///
///     flutter test test/features/work/render_harness.dart
Future<void> _shoot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 300));
  final boundary = find.byType(RepaintBoundary).evaluate().first.renderObject!
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _phone(WidgetTester t, Widget w) async {
  await t.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(w);
}

Widget _frame(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightFor('en')
          : AppTheme.darkFor('en'),
      home: RepaintBoundary(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

final _worked = WorkListing(
  id: 'l1', kind: ListingKind.person, displayName: 'Murugan A.',
  category: 'CARPENTRY', phone: '9443132365', area: 'Vadasery',
  about: 'interlock brick work, doors, window frames',
  trust: const ListingTrust(
      phoneVerified: true, jobsConfirmed: 9, isNew: false,
      memberSinceYear: 2022),
);

final _fresh = WorkListing(
  id: 'l2', kind: ListingKind.business, displayName: 'Selvam Furniture',
  category: 'CARPENTRY', phone: '9443100000', area: 'Putheri',
  about: 'Custom furniture and repairs',
  hours: '9am – 8pm',
  trust: const ListingTrust(
      phoneVerified: true, jobsConfirmed: 0, isNew: true,
      memberSinceYear: 2026),
);

class _Stub implements WorkRepository {
  _Stub({this.cats = const [], this.results = const []});
  final List<WorkCategoryCount> cats;
  final List<WorkListing> results;

  @override
  Future<List<WorkCategoryCount>> categories() async => cats;
  @override
  Future<List<WorkListing>> search({String? q, String? category, String? area}) async =>
      results;
  @override
  Future<WorkListing> listing(String id) async => results.first;
  @override
  Future<void> recordView(String id) async {}
  @override
  Future<MyListing> create({
    required String displayName, required String category,
    required String phone, ListingKind kind = ListingKind.person,
    String? about, String? area, String? whatsapp, String? address,
    String? hours,
  }) async =>
      MyListing(listing: _fresh, viewCount: 0, isActive: true, isHidden: false);
  @override
  Future<List<MyListing>> mine() async => [];
  @override
  Future<void> report(String listingId,
      {required ReportReason reason, String? note}) async {}
}

Widget _home(_Stub stub, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightFor('en')
          : AppTheme.darkFor('en'),
      home: RepaintBoundary(
        child: BlocProvider(
          create: (_) => WorkBloc(stub),
          child: const WorkHomeScreen(),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');

    for (final entry in {
      'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-400.ttf',
      'Noto Sans Tamil': 'assets/fonts/NotoSansTamil-400.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    final bold = FontLoader('Plus Jakarta Sans')
      ..addFont(File('assets/fonts/PlusJakartaSans-700.ttf')
          .readAsBytes().then((b) => b.buffer.asByteData()));
    await bold.load();
  });

  testWidgets('cards', (t) async {
    await _phone(t, _frame(Column(children: [
      ListingCard(listing: _worked, onOpened: (_) {}),
      ListingCard(listing: _fresh, onOpened: (_) {}),
    ])));
    await _shoot(t, 'w01_cards');
  });

  testWidgets('cards dark', (t) async {
    await _phone(t, _frame(Column(children: [
      ListingCard(listing: _worked, onOpened: (_) {}),
      ListingCard(listing: _fresh, onOpened: (_) {}),
    ]), brightness: Brightness.dark));
    await _shoot(t, 'w02_cards_dark');
  });

  testWidgets('home with categories', (t) async {
    await _phone(t, _home(_Stub(cats: const [
      WorkCategoryCount(code: 'CARPENTRY', count: 12),
      WorkCategoryCount(code: 'MOBILE_REPAIR', count: 8),
      WorkCategoryCount(code: 'TUITION', count: 5),
      WorkCategoryCount(code: 'ELECTRICAL', count: 3),
      WorkCategoryCount(code: 'DAILY_LABOUR', count: 2),
    ])));
    await _shoot(t, 'w03_home');
  });

  testWidgets('home empty', (t) async {
    await _phone(t, _home(_Stub()));
    await _shoot(t, 'w04_home_empty');
  });

  testWidgets('create listing', (t) async {
    await _phone(t, MaterialApp(
      theme: AppTheme.lightFor('en'),
      home: RepaintBoundary(child: CreateListingScreen(repo: _Stub())),
    ));
    await _shoot(t, 'w05_create');
  });
}
