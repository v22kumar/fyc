import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/features/chess_tournament/presentation/bloc/tournament_bloc.dart';

import 'fake_tournament_repository.dart';
import 'tournament_fixtures.dart';

/// The bloc's contract: state comes from the server, never from patching.
void main() {
  test('loading a tournament exposes the domain, not raw JSON', () async {
    final bloc = TournamentBloc(FakeTournamentRepository(stageRoundOneLive));
    addTearDown(bloc.close);

    bloc.add(TournamentRequested(uid(1000)));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.loading, isFalse);
    final d = bloc.state.detail!;
    expect(d.currentRound, 1);
    expect(d.blocking.length, 3, reason: 'one DONE, three undecided');
  });

  test('every mutation replaces the detail with the server answer', () async {
    final repo = FakeTournamentRepository(stageRoundOneLive);
    final bloc = TournamentBloc(repo);
    addTearDown(bloc.close);
    bloc.add(TournamentRequested(uid(1000)));
    await Future<void>.delayed(Duration.zero);

    // The server moves on to "between rounds"; a ready-press must bring the
    // NEW truth back, not patch the old copy.
    repo.serve(stageBetweenRounds);
    bloc.add(const ReadyPressed('m'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.detail!.blocking, isEmpty,
        reason: 'the screen now shows what the server said, not a local edit');
    expect(repo.calls, contains('ready:m'));
  });

  test('a double-tap fires one request, not two', () async {
    final repo = FakeTournamentRepository(stageRoundOneLive);
    final bloc = TournamentBloc(repo);
    addTearDown(bloc.close);
    bloc.add(TournamentRequested(uid(1000)));
    await Future<void>.delayed(Duration.zero);

    bloc.add(const NextRoundPressed());
    bloc.add(const NextRoundPressed()); // the second lands while busy
    await Future<void>.delayed(Duration.zero);

    expect(repo.calls.where((c) => c == 'next-round').length, 1);
  });

  test('play emits a complete board ticket once, then clears it', () async {
    final repo = FakeTournamentRepository(stageMyTurn);
    final bloc =
        TournamentBloc(repo, authToken: () async => 'jwt-abc');
    addTearDown(bloc.close);
    bloc.add(TournamentRequested(uid(1000)));
    await Future<void>.delayed(Duration.zero);

    final seen = <BoardTicket?>[];
    final sub = bloc.stream.listen((s) => seen.add(s.openGame));
    // Prakash (uid 15) sits in seat B of round 1 slot 2 → plays black.
    bloc.add(PlayPressed(uid(102), uid: uid(15)));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(
        seen,
        contains(const BoardTicket(
            gameId: 'game-1', token: 'jwt-abc', color: 'black')),
        reason: 'the widget navigates with what the bloc hands it — '
            'the token and the colour are the bloc\'s job, not the screen\'s');
    expect(bloc.state.openGame, isNull,
        reason: 'a later rebuild must not re-open the board');
  });

  test('a refresh failure keeps the last known state, silently', () async {
    final repo = FakeTournamentRepository(stageRoundOneLive);
    final bloc = TournamentBloc(repo);
    addTearDown(bloc.close);
    bloc.add(TournamentRequested(uid(1000)));
    await Future<void>.delayed(Duration.zero);
    final before = bloc.state.detail;

    repo.failNext = true;
    bloc.add(const TournamentRefreshed());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.detail, same(before));
    expect(bloc.state.failure, isNull,
        reason: 'a background refresh failing is not the member\'s problem');
  });

  test('an action failure carries the server\'s words', () async {
    final repo = FakeTournamentRepository(stageRoundOneLive);
    final bloc = TournamentBloc(repo);
    addTearDown(bloc.close);
    bloc.add(TournamentRequested(uid(1000)));
    await Future<void>.delayed(Duration.zero);

    repo.failNext = true;
    bloc.add(const NextRoundPressed());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.failure, 'Finish the current round first',
        reason: '"action failed" would erase the instruction');
  });
}
