import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/features/news/data/datasources/news_datasource.dart';
import 'package:fyc_connect/features/news/data/models/news_item_model.dart';
import 'package:fyc_connect/features/news/presentation/widgets/daily_news_card.dart';

/// Photographs of the news card, for a person to look at.
///
/// Named without `_test` so `flutter test` never collects it — it drives the
/// real widget tree and does not always shut down cleanly headless.
///
///     flutter test test/features/news/render_harness.dart
Future<void> _shoot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  final boundary = find.byType(RepaintBoundary).evaluate().first.renderObject!
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

DateTime _ago(Duration d) => DateTime.now().subtract(d);

const _kanyakumari = <NewsItemModel>[];

class _Stub implements NewsDataSource {
  List<NewsItemModel> _items() => [
        NewsItemModel(
            title: 'UPSC Civil Services Mains Admit Card 2026 Soon: '
                'Check Steps To Download And Instructions',
            source: 'NDTV',
            link: 'https://example.test/1',
            publishedAt: _ago(const Duration(hours: 6))),
        NewsItemModel(
            title: 'UPSC Mains Current Affairs for 10 August 2026',
            source: 'Vajiram & Ravi',
            link: 'https://example.test/2',
            publishedAt: _ago(const Duration(hours: 6))),
        NewsItemModel(
            title: 'Top 20 UPSC Current Affairs Pointers of the past week | '
                'August 3 to 9, 2026',
            source: 'The Indian Express',
            link: 'https://example.test/3',
            publishedAt: _ago(const Duration(hours: 2))),
        NewsItemModel(
            title: 'Inside the SAFAR 4.0 SSC CGL | CHSL 2027 Batch: '
                'Plans, Features, and Learning Resources',
            source: 'PW',
            link: 'https://example.test/4',
            publishedAt: _ago(const Duration(hours: 8))),
        NewsItemModel(
            title: 'Graduate turns down Rs 40 lakh job to prepare for UPSC!',
            source: 'Udayavani',
            link: 'https://example.test/5',
            publishedAt: _ago(const Duration(hours: 2))),
      ];

  @override
  Future<List<NewsItemModel>> fetchTop({int limit = 10}) async => _items();
  @override
  Future<List<NewsItemModel>> fetchIndia({int limit = 5}) async => _items();
  @override
  Future<List<NewsItemModel>> fetchKanyakumari({int limit = 8}) async =>
      _items();
  @override
  Future<List<NewsItemModel>> fetchTnJobs({int limit = 8}) async => _items();
  @override
  Future<List<NewsItemModel>> fetchCentralJobs({int limit = 8}) async =>
      _items();
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Widget _frame(Widget child) => MaterialApp(
      theme: AppTheme.darkFor('en'),
      home: RepaintBoundary(
        child: Scaffold(
          backgroundColor: const Color(0xFF0B1020),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.I.reset();
    GetIt.I.registerSingleton<LocalStorage>(
        LocalStorage(await SharedPreferences.getInstance()));
    GetIt.I.registerSingleton<NewsDataSource>(_Stub());
  });

  tearDown(() => GetIt.I.reset());

  testWidgets('news card as it ships today', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_frame(const DailyNewsCard()));
    await t.pump(const Duration(milliseconds: 600));
    await _shoot(t, 'news_current');
  });
}
