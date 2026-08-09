import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/features/complaint_box/domain/entities/complaint_entities.dart';
import 'package:fyc_connect/features/complaint_box/domain/repositories/complaint_repository.dart';
import 'package:fyc_connect/features/complaint_box/presentation/bloc/complaint_list_bloc.dart';

/// A repository that only answers the one question this bloc asks.
class _Fake implements ComplaintRepository {
  _Fake(this._all);
  final List<ComplaintSummary> _all;
  bool throws = false;

  @override
  Future<List<ComplaintSummary>> mine({bool includeClosed = true}) async {
    if (throws) throw const NetworkFailure();
    return _all;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the list screen asks for nothing else');
}

ComplaintSummary _c(String id, {required bool closed, int? waiting}) =>
    ComplaintSummary(
      id: id,
      category: 'STREET_LIGHT',
      description: 'A light is out',
      lane: ComplaintLane.self,
      severity: ComplaintSeverity.routine,
      status: closed ? 'RESOLVED' : 'UNDER_REVIEW',
      isClosed: closed,
      waitingDays: waiting,
      createdAt: DateTime(2026, 8, 1),
    );

void main() {
  test('open and closed are separated without a second request', () async {
    final bloc = ComplaintListBloc(_Fake([
      _c('a', closed: false, waiting: 20),
      _c('b', closed: false, waiting: 3),
      _c('c', closed: true),
    ]));
    addTearDown(bloc.close);

    bloc.add(const ComplaintsRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.open.map((c) => c.id), ['a', 'b']);
    expect(bloc.state.closed.map((c) => c.id), ['c']);
    // The open ones are what the screen opens on. Somebody who has finished
    // with a complaint is not looking for it.
    expect(bloc.state.visible.map((c) => c.id), ['a', 'b']);
  });

  test('switching to the finished tab does not refetch', () async {
    // The server already sent both. A spinner between two tabs of the same
    // data is a wait the member pays for nothing.
    final repo = _Fake([_c('a', closed: false), _c('c', closed: true)]);
    final bloc = ComplaintListBloc(repo);
    addTearDown(bloc.close);

    bloc.add(const ComplaintsRequested());
    await Future<void>.delayed(Duration.zero);

    repo.throws = true; // any refetch from here would fail loudly
    bloc.add(const ComplaintFilterChanged(true));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.failure, isNull);
    expect(bloc.state.visible.map((c) => c.id), ['c']);
  });

  test('the order the server chose is preserved', () async {
    // Longest-ignored first. Re-sorting on the client would quietly undo the
    // one decision that makes the list worth opening.
    final bloc = ComplaintListBloc(_Fake([
      _c('oldest', closed: false, waiting: 30),
      _c('newer', closed: false, waiting: 1),
    ]));
    addTearDown(bloc.close);

    bloc.add(const ComplaintsRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.visible.first.id, 'oldest');
  });

  test('a failure keeps the words the member can act on', () async {
    final repo = _Fake([])..throws = true;
    final bloc = ComplaintListBloc(repo);
    addTearDown(bloc.close);

    bloc.add(const ComplaintsRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.failure, const NetworkFailure().message);
  });

  test('nothing reported is a different screen from nothing open', () async {
    final bloc = ComplaintListBloc(_Fake([_c('c', closed: true)]));
    addTearDown(bloc.close);

    bloc.add(const ComplaintsRequested());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.isEmpty, isFalse,
        reason: 'they have reported something — it is just finished');
    expect(bloc.state.visible, isEmpty);
  });
}
