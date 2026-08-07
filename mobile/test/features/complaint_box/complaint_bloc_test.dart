import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/features/complaint_box/domain/entities/complaint_entities.dart';
import 'package:fyc_connect/features/complaint_box/domain/repositories/complaint_repository.dart';
import 'package:fyc_connect/features/complaint_box/presentation/bloc/complaint_bloc.dart';

/// A repository that records what it was asked to do, so the tests can check
/// the bloc never invents a state change of its own.
class _Fake implements ComplaintRepository {
  final List<String> calls = [];

  /// When set, the next ladder fetch throws — standing in for a dropped
  /// connection rather than an empty directory.
  bool ladderThrows = false;

  /// When set, mutating actions throw.
  bool actionsThrow = false;
  ComplaintState current = const ComplaintState(
    id: 'c1',
    lane: ComplaintLane.self,
    severity: ComplaintSeverity.routine,
    status: 'NEW',
    isClosed: false,
    events: [],
  );

  ComplaintState _with({bool? closed, ComplaintLane? lane, int? waiting}) {
    current = ComplaintState(
      id: current.id,
      lane: lane ?? current.lane,
      severity: current.severity,
      status: current.status,
      isClosed: closed ?? current.isClosed,
      events: current.events,
      waitingDays: waiting ?? current.waitingDays,
    );
    return current;
  }

  @override
  Future<CallLadder> ladder({required String category, String? geographyId}) async {
    calls.add('ladder');
    if (ladderThrows) throw Exception('network');
    return CallLadder(category: category, rungs: const [
      LadderRung(
        position: 1, departmentCode: 'ULB', departmentName: 'Corporation',
        covers: 'your ward', canCall: true, canWrite: false, waitDays: 14,
        designation: 'Assistant Engineer', phone: '9443132365',
      ),
      LadderRung(
        position: 2, departmentCode: 'ULB', departmentName: 'Corporation',
        covers: 'the local body', canCall: false, canWrite: false, waitDays: 14,
        designation: 'Commissioner',
      ),
    ]);
  }

  @override
  Future<ComplaintState> load(String id) async {
    calls.add('load');
    return current;
  }

  @override
  Future<ComplaintState> logCall(String id,
      {required CallOutcome outcome,
      String? authorityId,
      String? authorityLabel,
      String? note}) async {
    calls.add('logCall:${outcome.name}');
    return current;
  }

  @override
  Future<ComplaintDraft> draft(String id,
      {String? authorityId, bool bccClub = true, bool useAi = true}) async {
    calls.add('draft:bcc=$bccClub');
    return ComplaintDraft(
      toLabel: 'Assistant Engineer, Corporation',
      subject: 'Street light out',
      body: 'body',
      cc: const [],
      bcc: bccClub ? const ['club@example.invalid'] : const [],
      aiWritten: false,
    );
  }

  @override
  Future<ComplaintState> markSent(String id,
      {String? authorityId, String? authorityLabel}) async {
    calls.add('markSent');
    return current;
  }

  @override
  Future<ComplaintState> markReplied(String id, {String? note}) async {
    calls.add('markReplied');
    return current;
  }

  @override
  Future<ComplaintState> close(String id,
      {required bool resolved, String? reason}) async {
    calls.add('close:$resolved');
    if (actionsThrow) throw Exception('network');
    return _with(closed: true);
  }

  @override
  Future<ComplaintState> reopen(String id) async {
    calls.add('reopen');
    return _with(closed: false);
  }

  @override
  Future<ComplaintState> handToClub(String id) async {
    calls.add('handToClub');
    return _with(lane: ComplaintLane.viaClub);
  }
}

void main() {
  late _Fake repo;
  late ComplaintBloc bloc;

  setUp(() {
    repo = _Fake();
    bloc = ComplaintBloc(repo);
  });

  tearDown(() => bloc.close());

  test('loading fetches the ladder too, so "who do I call" needs no second wait',
      () async {
    bloc.add(const LoadComplaint('c1', category: 'STREET_LIGHT'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, containsAll(['load', 'ladder']));
    expect(bloc.state.ladder!.rungs.length, 2);
  });

  test('a missing ladder does not fail the screen', () async {
    // Without a category there is no ladder to fetch; the member can still
    // write or hand it to the club, so the screen must still load.
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.complaint, isNotNull);
    expect(bloc.state.failure, isNull);
  });

  test('drafting never marks the letter sent', () async {
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const DraftRequested());
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, contains('draft:bcc=true'));
    expect(repo.calls, isNot(contains('markSent')),
        reason: 'the draft goes to another app; this one cannot see what '
            'happens next and must not pretend otherwise');
  });

  test('turning the copy off asks for a draft with no bcc', () async {
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const DraftRequested(bccClub: false));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, contains('draft:bcc=false'));
    expect(bloc.state.draft!.bcc, isEmpty);
  });

  test('the member confirming a send is what records it', () async {
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const SendConfirmed());
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, contains('markSent'));
  });

  test('closing and reopening both work', () async {
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const Closed(resolved: true));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.complaint!.isClosed, isTrue);

    bloc.add(const Reopened());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.complaint!.isClosed, isFalse);
  });

  test('handing it to the club changes lane', () async {
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const HandedToClub());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.complaint!.lane, ComplaintLane.viaClub);
  });

  test('a failed ladder is not the same as an empty one', () async {
    // These used to be indistinguishable, so somebody whose train went into a
    // tunnel was told "no office is listed for this yet" — which is a
    // different problem with a different fix.
    repo.ladderThrows = true;
    bloc.add(const LoadComplaint('c1', category: 'STREET_LIGHT'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.ladderFailed, isTrue);
    expect(bloc.state.ladder, isNull);
    expect(bloc.state.complaint, isNotNull,
        reason: 'the rest of the screen must still work — they can still '
            'write, or hand it to the club');
  });

  test('a failed action reports itself instead of doing nothing', () async {
    // The screen only rendered `failure` when the complaint had not loaded, so
    // tapping "mark resolved" on a bad connection was silent.
    bloc.add(const LoadComplaint('c1'));
    await Future<void>.delayed(Duration.zero);
    repo.actionsThrow = true;

    bloc.add(const Closed(resolved: true));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.failure, isNotNull);
    expect(bloc.state.busy, isFalse, reason: 'the spinner must not get stuck');
    expect(bloc.state.complaint!.isClosed, isFalse,
        reason: 'a failed close must not look like a successful one');
  });

  test('the ladder keeps offices with no number, marked', () async {
    bloc.add(const LoadComplaint('c1', category: 'STREET_LIGHT'));
    await Future<void>.delayed(Duration.zero);
    final rungs = bloc.state.ladder!.rungs;
    expect(rungs.any((r) => r.canCall), isTrue);
    expect(rungs.any((r) => !r.canCall), isTrue,
        reason: 'a gap the club cannot see is a gap nobody fills');
  });
}
