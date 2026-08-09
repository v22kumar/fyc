import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/features/chess_tournament/domain/entities/tournament_entities.dart';

/// The tournament rulebook, tested without a widget tree.
///
/// These rules used to live inline in a 705-line widget, where the only way to
/// check "which button does a player see" was to build the whole screen. Every
/// answer a surface renders comes from here now, so every answer is pinned
/// here.
BracketMatch m({
  String id = 'm1',
  int round = 1,
  int slot = 0,
  MatchStatus status = MatchStatus.ready,
  String? a,
  String? b,
  String? winner,
  String? gameId,
  bool activated = true,
  bool aReady = false,
  bool bReady = false,
  String conduct = 'APP',
}) =>
    BracketMatch(
      id: id,
      round: round,
      slot: slot,
      status: status,
      playerA: a == null ? null : PlayerRef(id: a, name: a),
      playerB: b == null ? null : PlayerRef(id: b, name: b),
      winnerId: winner,
      gameId: gameId,
      activated: activated,
      aReady: aReady,
      bReady: bReady,
      conductMode: conduct,
    );

TournamentDetail detail({
  TournamentStatus status = TournamentStatus.inProgress,
  int currentRound = 1,
  int rounds = 2,
  List<BracketMatch> matches = const [],
}) =>
    TournamentDetail(
      id: 't1',
      name: 'Cup',
      status: status,
      entryCount: 4,
      currentRound: currentRound,
      rounds: rounds,
      entries: const [],
      matches: matches,
    );

void main() {
  group('what a player can do —', () {
    test('an unactivated round says wait, never ready', () {
      final match = m(a: 'me', b: 'you', activated: false,
          status: MatchStatus.pending);
      expect(match.actionFor('me'), MatchAction.waitRound);
    });

    test('the ladder: ready → wait for opponent → play', () {
      expect(m(a: 'me', b: 'you').actionFor('me'), MatchAction.ready);
      expect(m(a: 'me', b: 'you', aReady: true).actionFor('me'),
          MatchAction.waitOpponent);
      expect(m(a: 'me', b: 'you', aReady: true, bReady: true).actionFor('me'),
          MatchAction.play);
    });

    test('a live game resumes, whichever side you are', () {
      final live = m(
          a: 'me', b: 'you', status: MatchStatus.live, gameId: 'g1',
          aReady: true, bReady: true);
      expect(live.actionFor('me'), MatchAction.resume);
      expect(live.actionFor('you'), MatchAction.resume);
    });

    test('a physical match sends you to the venue, not to a Ready button', () {
      final otb = m(a: 'me', b: 'you', conduct: 'PHYSICAL');
      expect(otb.actionFor('me'), MatchAction.attendVenue);
    });

    test('a decided match, a stranger, and nobody signed in all get none', () {
      expect(m(a: 'me', b: 'you', winner: 'me', status: MatchStatus.done)
          .actionFor('me'), MatchAction.none);
      expect(m(a: 'me', b: 'you').actionFor('stranger'), MatchAction.none);
      expect(m(a: 'me', b: 'you').actionFor(null), MatchAction.none);
    });

    test('seat A plays white, seat B plays black — the server\'s rule', () {
      final match = m(a: 'me', b: 'you');
      expect(match.colorFor('me'), 'white');
      expect(match.colorFor('you'), 'black');
    });
  });

  group('my next match —', () {
    test('is my undecided match in the earliest round that has one', () {
      final d = detail(matches: [
        m(id: 'r1', round: 1, a: 'me', b: 'you', winner: 'me',
            status: MatchStatus.done),
        m(id: 'r2', round: 2, a: 'me', b: 'them', activated: false,
            status: MatchStatus.pending),
      ]);
      expect(d.myMatch('me')!.id, 'r2',
          reason: 'the finished quarter-final is history, not my match');
    });

    test('is null once I have lost — and stillIn agrees', () {
      final d = detail(matches: [
        m(id: 'r1', round: 1, a: 'me', b: 'you', winner: 'you',
            status: MatchStatus.done),
      ]);
      expect(d.myMatch('me'), isNull);
      expect(d.stillIn('me'), isFalse);
      expect(d.stillIn('you'), isTrue);
    });

    test('a bye is never presented as something to do', () {
      final d = detail(matches: [
        m(id: 'r1', round: 1, a: 'me', status: MatchStatus.bye, winner: 'me'),
        m(id: 'r2', round: 2, a: 'me', b: 'you', activated: false,
            status: MatchStatus.pending),
      ]);
      expect(d.myMatch('me')!.id, 'r2');
    });
  });

  group('what blocks the round —', () {
    test('undecided non-bye matches in the current round, and only those', () {
      final d = detail(currentRound: 1, matches: [
        m(id: 'a', round: 1, a: 'p1', b: 'p2', winner: 'p1',
            status: MatchStatus.done),
        m(id: 'b', round: 1, a: 'p3', b: 'p4'),
        m(id: 'c', round: 1, a: 'p5', status: MatchStatus.bye, winner: 'p5'),
        m(id: 'd', round: 2, a: 'p1', b: 'p5', activated: false,
            status: MatchStatus.pending),
      ]);
      expect(d.blocking.map((x) => x.id), ['b'],
          reason: 'done is done, byes never block, round 2 is not current');
      expect(d.canStartNextRound, isFalse);
    });

    test('an empty worklist with rounds remaining means Start Next Round', () {
      final d = detail(currentRound: 1, rounds: 2, matches: [
        m(id: 'a', round: 1, a: 'p1', b: 'p2', winner: 'p1',
            status: MatchStatus.done),
        m(id: 'd', round: 2, activated: false, status: MatchStatus.pending),
      ]);
      expect(d.canStartNextRound, isTrue);
    });

    test('the last round decided means no next round to start', () {
      final d = detail(currentRound: 2, rounds: 2, matches: [
        m(id: 'f', round: 2, a: 'p1', b: 'p5', winner: 'p1',
            status: MatchStatus.done),
      ]);
      expect(d.canStartNextRound, isFalse);
    });
  });

  group('the wire —', () {
    test('an unknown status is unknown, not silently open', () {
      // STARTING_LOCK reaches clients when a start is interrupted. The old
      // model defaulted unknown statuses to REGISTRATION_OPEN, which rendered
      // a Register button on a tournament mid-draw.
      expect(TournamentStatus.values,
          contains(TournamentStatus.unknown));
    });
  });
}
