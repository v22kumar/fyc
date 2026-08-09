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
import 'package:fyc_connect/features/complaint_box/domain/entities/complaint_entities.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/complaint_timeline.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/ladder_list.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/send_letter_sheet.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/suggest_contact_sheet.dart';
import 'package:fyc_connect/features/complaint_box/domain/repositories/complaint_repository.dart';
import 'package:fyc_connect/features/complaint_box/presentation/bloc/complaint_bloc.dart';
import 'package:fyc_connect/features/complaint_box/presentation/bloc/complaint_list_bloc.dart';
import 'package:fyc_connect/features/complaint_box/presentation/screens/complaint_detail_screen.dart';
import 'package:fyc_connect/features/complaint_box/presentation/screens/my_complaints_screen.dart';

/// Renders the Complaint Box surfaces to PNGs so a human can look at them.
///
/// A camera, not an assertion suite. Deliberately named without the `_test`
/// suffix so `flutter test` never collects it: it drives the real widget tree
/// and, in a headless container, does not always shut down cleanly. Left in
/// the default run it fails CI over screenshots nobody asked for — or worse,
/// hangs it, and a hung build burns the runner's timeout while telling you
/// nothing.
///
/// Run it deliberately:
///
///     flutter test test/features/complaint_box/render_harness.dart
///
/// Output lands in build/ui_shots/.
Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 300));
  final el = find.byType(RepaintBoundary).evaluate().first;
  final boundary = el.renderObject! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  // An undisposed image leaves the binding with pending work, and the run
  // stalls after the first shot instead of failing.
  image.dispose();
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Set the frame once, and always give it back.
Future<void> _phone(WidgetTester t, Widget w) async {
  await t.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(w);
}

Widget _frame(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightFor("en")
          : AppTheme.darkFor("en"),
      home: RepaintBoundary(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

const _ladder = CallLadder(
  category: 'STREET_LIGHT',
  placeName: 'Vadasery',
  rungs: [
    LadderRung(
      position: 1, departmentCode: 'ULB', departmentName: 'Nagercoil Corporation',
      covers: 'your ward', canCall: false, canWrite: false, waitDays: 14,
      designation: 'Ward Councillor',
    ),
    LadderRung(
      position: 2, departmentCode: 'ULB', departmentName: 'Nagercoil Corporation',
      covers: 'your area', canCall: true, canWrite: true, waitDays: 14,
      designation: 'Assistant Engineer — Street Lighting',
      phone: '9443132365', email: 'ae.light@nagercoil.gov.in',
    ),
    LadderRung(
      position: 3, departmentCode: 'ULB', departmentName: 'Nagercoil Corporation',
      covers: 'the local body', canCall: false, canWrite: true, waitDays: 14,
      designation: 'Commissioner', email: 'commr.nagarcoil@tn.gov.in',
    ),
    LadderRung(
      position: 4, departmentCode: 'REV', departmentName: 'Revenue',
      covers: 'the district', canCall: true, canWrite: true, waitDays: 21,
      designation: 'District Collector',
      phone: '04652279090', email: 'collrkkl@nic.in',
    ),
  ],
);

ComplaintState _state({bool closed = false, int? waiting}) => ComplaintState(
      id: 'c1',
      category: 'STREET_LIGHT',
      description: 'The street light opposite Vadasery bus stand has been '
          'dead for three weeks.',
      placeName: 'Vadasery bus stand, Nagercoil',
      lane: ComplaintLane.self,
      severity: ComplaintSeverity.serious,
      status: closed ? 'RESOLVED' : 'UNDER_REVIEW',
      isClosed: closed,
      waitingDays: waiting,
      closedReason: closed ? 'Fixed the next week' : null,
      events: [
        ComplaintEvent(
          id: '1', author: ComplaintAuthor.member, authorName: 'Arun Kumar',
          type: 'CALLED', callOutcome: CallOutcome.promised,
          authorityLabel: 'Assistant Engineer — Street Lighting',
          at: DateTime(2026, 8, 1),
        ),
        ComplaintEvent(
          id: '2', author: ComplaintAuthor.member, authorName: 'Arun Kumar',
          type: 'DRAFTED', authorityLabel: 'Assistant Engineer — Street Lighting',
          at: DateTime(2026, 8, 5),
        ),
        ComplaintEvent(
          id: '3', author: ComplaintAuthor.member, authorName: 'Arun Kumar',
          type: 'SENT', authorityLabel: 'Assistant Engineer — Street Lighting',
          at: DateTime(2026, 8, 5),
        ),
        ComplaintEvent(
          id: '4', author: ComplaintAuthor.club, type: 'FYC_FORWARDED',
          authorityLabel: 'Executive Engineer, TWAD', at: DateTime(2026, 8, 6),
        ),
      ],
    );

/// One of every standing the list can render, in the order the server sends
/// them: open before closed, longest-ignored first.
final _mine = <ComplaintSummary>[
  ComplaintSummary(
    id: 'a', category: 'DRINKING_WATER',
    description: 'The main pipe on Kottar Road has been leaking for a month '
        'and the road is always wet.',
    placeName: 'Kottar Road, Nagercoil',
    lane: ComplaintLane.self, severity: ComplaintSeverity.serious,
    status: 'UNDER_REVIEW', isClosed: false,
    waitingDays: 23, lastEvent: 'SENT', lastEventAt: DateTime(2026, 7, 17),
    createdAt: DateTime(2026, 7, 15),
  ),
  ComplaintSummary(
    id: 'b', category: 'STREET_LIGHT',
    description: 'Street light opposite the bus stand is dead.',
    placeName: 'Vadasery bus stand',
    lane: ComplaintLane.self, severity: ComplaintSeverity.routine,
    status: 'UNDER_REVIEW', isClosed: false,
    waitingDays: 4, lastEvent: 'CALLED', lastEventAt: DateTime(2026, 8, 5),
    createdAt: DateTime(2026, 8, 1),
  ),
  ComplaintSummary(
    id: 'c', category: 'GARBAGE',
    description: 'Bin at the corner has not been cleared since Monday.',
    placeName: 'Anna Nagar 3rd Street',
    lane: ComplaintLane.viaClub, severity: ComplaintSeverity.routine,
    status: 'UNDER_REVIEW', isClosed: false,
    waitingDays: 2, lastEvent: 'FYC_FORWARDED',
    lastEventAt: DateTime(2026, 8, 7), createdAt: DateTime(2026, 8, 6),
  ),
  ComplaintSummary(
    id: 'd', category: 'DRAINAGE',
    description: 'Open drain beside the school gate.',
    placeName: 'Government School, Ozhuginasery',
    lane: ComplaintLane.self, severity: ComplaintSeverity.serious,
    status: 'NEW', isClosed: false,
    createdAt: DateTime(2026, 8, 8),
  ),
  ComplaintSummary(
    id: 'e', category: 'ROAD',
    description: 'Pothole at the junction, two people have fallen.',
    placeName: 'Parvathipuram junction',
    lane: ComplaintLane.self, severity: ComplaintSeverity.serious,
    status: 'RESOLVED', isClosed: true, closedReason: 'Filled the next week',
    lastEvent: 'RESOLVED', lastEventAt: DateTime(2026, 7, 2),
    createdAt: DateTime(2026, 6, 20),
  ),
];

Widget _list(List<ComplaintSummary> all,
        {Brightness brightness = Brightness.light, bool showClosed = false}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightFor('en')
          : AppTheme.darkFor('en'),
      home: RepaintBoundary(
        child: BlocProvider<ComplaintListBloc>(
          create: (_) => ComplaintListBloc(_StubRepo(_state(waiting: 12), all)),
          child: const MyComplaintsScreen(),
        ),
      ),
    );

const _draft = ComplaintDraft(
  toLabel: 'Assistant Engineer — Street Lighting, Nagercoil Corporation',
  toEmail: 'ae.light@nagercoil.gov.in',
  subject: 'Street light not working at Vadasery bus stand',
  body: 'To: Assistant Engineer — Street Lighting, Nagercoil Corporation\n\n'
      'Sir / Madam,\n\n'
      'The street light opposite Vadasery bus stand has been dead for three '
      'weeks. The stretch is used by schoolchildren in the early morning.\n\n'
      'I spoke to the Assistant Engineer on 1 August 2026, who said it would '
      'be attended to. There has been no action since.\n\n'
      'Location:  Vadasery bus stand\n'
      '           https://www.google.com/maps/search/?api=1&query=8.1833,77.4119\n'
      'Reported:  2026-08-07\n'
      'Reference: F3DD5504\n\n'
      'Arun Kumar\n+91 98400 00000',
  cc: ['commr.nagarcoil@tn.gov.in'],
  bcc: ['complaints@fyc.local'],
  aiWritten: true,
);

void main() {
  setUpAll(() async {
    // main.dart does this at startup; without it DateFormat throws for any
    // locale and the timeline renders as a red error screen.
    await initializeDateFormatting();

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');

    // Without a real font every glyph renders as a filled box, which is fine
    // for layout and useless for judging whether a screen reads well. Load the
    // app's actual typeface so these are worth looking at.
    for (final family in ['Plus Jakarta Sans', 'Noto Sans Tamil']) {
      final file = family == 'Plus Jakarta Sans'
          ? 'assets/fonts/PlusJakartaSans-400.ttf'
          : 'assets/fonts/NotoSansTamil-400.ttf';
      final loader = FontLoader(family)
        ..addFont(File(file).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    // Without this every icon is a filled box, and a screenshot full of tofu
    // cannot answer the question these shots exist to answer. The font ships
    // with the SDK; the test binding just never registers it.
    for (final path in [
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}'
          '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final icons = FontLoader('MaterialIcons')
        ..addFont(f.readAsBytes().then((b) => b.buffer.asByteData()));
      await icons.load();
      break;
    }

    final bold = FontLoader('Plus Jakarta Sans')
      ..addFont(File('assets/fonts/PlusJakartaSans-700.ttf')
          .readAsBytes()
          .then((b) => b.buffer.asByteData()));
    await bold.load();
  });

  testWidgets('ladder — light', (t) async {
    await _phone(t, _frame(LadderList(ladder: _ladder, onCalled: (_) {}, onWrite: (_) {},
        onSuggestContact: (_) {})));
    await _shoot(t, '01_ladder_light');
  });

  testWidgets('ladder — dark', (t) async {
    await _phone(t, _frame(LadderList(ladder: _ladder, onCalled: (_) {}, onWrite: (_) {},
        onSuggestContact: (_) {}),
        brightness: Brightness.dark));
    await _shoot(t, '02_ladder_dark');
  });

  testWidgets('timeline — waiting', (t) async {
    await _phone(t, _frame(ComplaintTimeline(state: _state(waiting: 12))));
    await _shoot(t, '03_timeline_waiting');
  });

  testWidgets('timeline — closed', (t) async {
    await _phone(t, _frame(ComplaintTimeline(state: _state(closed: true))));
    await _shoot(t, '04_timeline_closed');
  });

  testWidgets('send sheet', (t) async {
    await _phone(t, _frame(SendLetterSheet(
      draft: _draft, onSentConfirmed: () {}, onBccChanged: (_) {},
    )));
    await _shoot(t, '05_send_sheet');
  });

  testWidgets('detail — light', (t) async {
    await _phone(t, _screen(_state(waiting: 12), brightness: Brightness.light));
    await _shoot(t, '06_detail_light');
  });

  testWidgets('detail — dark', (t) async {
    await _phone(t, _screen(_state(waiting: 12), brightness: Brightness.dark));
    await _shoot(t, '07_detail_dark');
  });

  testWidgets('detail — closed', (t) async {
    await _phone(t, _screen(_state(closed: true)));
    await _shoot(t, '08_detail_closed');
  });

  testWidgets('suggest contact sheet', (t) async {
    await _phone(t, _frame(SuggestContactSheet(
      rung: _ladder.rungs.first,
      onSubmit: (_, __, ___) {},
    )));
    await _shoot(t, '10_suggest_contact');
  });

  testWidgets('detail — outside our area', (t) async {
    // A pothole photographed in Bengaluru. The ladder must not offer four
    // officers in Nagercoil, and the screen must say why it is offering none.
    await _phone(t, _screen(_state(waiting: 3),
        ladder: const CallLadder(
          category: 'ROAD', rungs: [], covered: false,
          outsidePlace: 'Indiranagar, Bengaluru',
        )));
    await _shoot(t, '14_detail_outside_area');
  });

  testWidgets('my complaints — light', (t) async {
    await _phone(t, _list(_mine));
    await _shoot(t, '11_my_complaints_light');
  });

  testWidgets('my complaints — dark', (t) async {
    await _phone(t, _list(_mine, brightness: Brightness.dark));
    await _shoot(t, '12_my_complaints_dark');
  });

  testWidgets('my complaints — nothing yet', (t) async {
    await _phone(t, _list(const []));
    await _shoot(t, '13_my_complaints_empty');
  });

  testWidgets('empty ladder', (t) async {
    await _phone(t, _frame(LadderList(
      ladder: const CallLadder(
          category: 'OTHER', rungs: [], fallbackHelpline: '1100'),
      onCalled: (_) {},
    )));
    await _shoot(t, '09_no_route');
  });
}

/// A fake that answers from a fixed state, so the whole screen can be
/// photographed without a server.
class _StubRepo implements ComplaintRepository {
  _StubRepo(this._state, [this._all = const [], this._ladderOverride]);
  final ComplaintState _state;
  final List<ComplaintSummary> _all;
  final CallLadder? _ladderOverride;

  @override
  Future<CallLadder> ladder({required String category, String? geographyId,
          String? complaintId}) async => _ladderOverride ?? _ladder;
  @override
  Future<List<ComplaintSummary>> mine({bool includeClosed = true}) async => _all;
  @override
  Future<ComplaintState> load(String id) async => _state;
  @override
  Future<ComplaintState> logCall(String id,
          {required CallOutcome outcome, String? authorityId,
          String? authorityLabel, String? note}) async => _state;
  @override
  Future<ComplaintDraft> draft(String id,
          {String? authorityId, bool bccClub = true, bool useAi = true}) async => _draft;
  @override
  Future<ComplaintState> markSent(String id,
          {String? authorityId, String? authorityLabel}) async => _state;
  @override
  Future<ComplaintState> markReplied(String id, {String? note}) async => _state;
  @override
  Future<ComplaintState> close(String id,
          {required bool resolved, String? reason}) async => _state;
  @override
  Future<ComplaintState> reopen(String id) async => _state;
  @override
  Future<ComplaintState> handToClub(String id) async => _state;
  @override
  Future<void> suggestContact(String authorityId,
      {String? phone, String? email, String? howTheyKnow}) async {}
}

Widget _screen(ComplaintState state,
        {Brightness brightness = Brightness.light, CallLadder? ladder}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightFor('en')
          : AppTheme.darkFor('en'),
      home: RepaintBoundary(
        child: BlocProvider(
          create: (_) =>
              ComplaintBloc(_StubRepo(state, const [], ladder))
                ..add(const LoadComplaint('c1', category: 'STREET_LIGHT')),
          child: const ComplaintDetailScreen(
              complaintId: 'c1', category: 'STREET_LIGHT'),
        ),
      ),
    );
