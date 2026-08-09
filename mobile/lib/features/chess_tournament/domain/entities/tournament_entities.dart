/// What a knockout tournament is made of, and the questions it can answer.
///
/// The previous model was four flat files: raw JSON shapes handed straight to
/// a 705-line widget that computed tournament rules inline with `setState`.
/// The rules now live here, on the entities, where they can be tested without
/// a widget tree — and where every surface answers the same way.
///
/// The organising idea: **a knockout is a round-based queue with a blocking
/// join.** Everyone in the event is waiting on the slowest match of the
/// current round. So the entity's job is to answer, instantly and in one
/// place: what round are we in, what blocks it, what is *my* match, and what
/// should each kind of person do next.
library;

import 'package:equatable/equatable.dart';

enum TournamentStatus { open, closed, inProgress, completed, unknown }

enum MatchStatus { pending, ready, live, done, bye, unknown }

/// What one member can do about one match, right now.
///
/// Derived here rather than in a widget, because "which button do I show" IS
/// the tournament rulebook, and the rulebook must not be duplicated per
/// screen.
enum MatchAction {
  /// Mark yourself ready.
  ready,

  /// You are ready; the opponent is not yet.
  waitOpponent,

  /// Both ready — open the board.
  play,

  /// The game is on — return to the board.
  resume,

  /// The opponent never turned up; the walkover can be claimed.
  claimWalkover,

  /// Played in person: turn up at the venue.
  attendVenue,

  /// The round has not been started by the organiser yet.
  waitRound,

  /// Nothing — decided, or not yours.
  none,
}

class PlayerRef extends Equatable {
  const PlayerRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

class TournamentEntry extends Equatable {
  const TournamentEntry(
      {required this.id, required this.name, required this.status});

  final String id;
  final String name;
  final String status; // PENDING / APPROVED / REJECTED

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';

  @override
  List<Object?> get props => [id, status];
}

class BracketMatch extends Equatable {
  const BracketMatch({
    required this.id,
    required this.round,
    required this.slot,
    required this.status,
    this.playerA,
    this.playerB,
    this.winnerId,
    this.gameId,
    this.conductMode = 'APP',
    this.activated = false,
    this.aReady = false,
    this.bReady = false,
    this.venue,
    this.reportingTime,
  });

  final String id;
  final int round;
  final int slot;
  final MatchStatus status;
  final PlayerRef? playerA;
  final PlayerRef? playerB;
  final String? winnerId;
  final String? gameId;
  final String conductMode;
  final bool activated;
  final bool aReady;
  final bool bReady;
  final String? venue;
  final DateTime? reportingTime;

  bool get isPhysical => conductMode == 'PHYSICAL';
  bool get isDecided => winnerId != null;
  bool get isBye => status == MatchStatus.bye;
  bool get bothSeated => playerA != null && playerB != null;

  bool involves(String? uid) =>
      uid != null && (playerA?.id == uid || playerB?.id == uid);

  PlayerRef? opponentOf(String uid) =>
      playerA?.id == uid ? playerB : (playerB?.id == uid ? playerA : null);

  bool myReady(String uid) =>
      (playerA?.id == uid && aReady) || (playerB?.id == uid && bReady);

  bool opponentReady(String uid) =>
      (playerA?.id == uid && bReady) || (playerB?.id == uid && aReady);

  /// The colour [uid] plays on the board: seat A is white, seat B is black —
  /// the same rule the server applies when it creates the game.
  String colorFor(String uid) => playerA?.id == uid ? 'white' : 'black';

  /// Undecided and not a bye: the definition of "blocks the round". The same
  /// predicate the server's gate uses — duplicated knowingly, and pinned by a
  /// test, because the organiser's worklist must never disagree with the
  /// button the server will refuse.
  bool get blocksRound => !isDecided && !isBye;

  /// What [uid] can do about this match right now.
  MatchAction actionFor(String? uid) {
    if (uid == null || isDecided || !involves(uid)) return MatchAction.none;
    if (isPhysical) return MatchAction.attendVenue;
    if (!activated) return MatchAction.waitRound;
    if (!bothSeated) return MatchAction.waitRound;
    if (status == MatchStatus.live && gameId != null) return MatchAction.resume;
    if (myReady(uid) && opponentReady(uid)) return MatchAction.play;
    if (myReady(uid)) return MatchAction.waitOpponent;
    return MatchAction.ready;
  }

  @override
  List<Object?> get props =>
      [id, round, slot, status, winnerId, gameId, activated, aReady, bReady];
}

class Tournament extends Equatable {
  const Tournament({
    required this.id,
    required this.name,
    required this.status,
    required this.entryCount,
    this.description,
    this.shortCode,
    this.registrationDeadline,
    this.pendingCount = 0,
    this.currentRound = 0,
    this.isRegistered = false,
    this.myStatus,
    this.champion,
    this.timeControl = 'rapid_10_0',
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final TournamentStatus status;

  /// The typeable public code for the telecast link. Carried by the API since
  /// the model gained it, rendered by the app for the first time now.
  final String? shortCode;

  final DateTime? registrationDeadline;
  final int entryCount;
  final int pendingCount;
  final int currentRound;
  final bool isRegistered;
  final String? myStatus;
  final PlayerRef? champion;
  final String timeControl;
  final DateTime? createdAt;

  bool get isOpen => status == TournamentStatus.open;
  bool get isClosed => status == TournamentStatus.closed;
  bool get inProgress => status == TournamentStatus.inProgress;
  bool get isCompleted => status == TournamentStatus.completed;

  @override
  List<Object?> get props =>
      [id, status, entryCount, pendingCount, currentRound, myStatus, champion];
}

/// The full event: the tournament, its people, and its bracket — plus every
/// derived answer a surface needs.
class TournamentDetail extends Tournament {
  const TournamentDetail({
    required super.id,
    required super.name,
    required super.status,
    required super.entryCount,
    super.description,
    super.shortCode,
    super.registrationDeadline,
    super.pendingCount,
    super.currentRound,
    super.isRegistered,
    super.myStatus,
    super.champion,
    super.timeControl,
    super.createdAt,
    required this.entries,
    required this.rounds,
    required this.matches,
  });

  final List<TournamentEntry> entries;
  final int rounds;
  final List<BracketMatch> matches;

  List<TournamentEntry> get pendingEntries =>
      entries.where((e) => e.isPending).toList(growable: false);

  List<TournamentEntry> get approvedEntries =>
      entries.where((e) => e.isApproved).toList(growable: false);

  // ── The player's question: what do I do next? ────────────────────────────

  /// The one match [uid] should be looking at.
  ///
  /// Their undecided match in the newest activated round; failing that, their
  /// next known pairing. A player must never need the bracket to find it.
  BracketMatch? myMatch(String? uid) {
    if (uid == null) return null;
    final mine = matches
        .where((m) => m.involves(uid) && !m.isDecided && !m.isBye)
        .toList()
      ..sort((a, b) => a.round.compareTo(b.round));
    if (mine.isEmpty) return null;
    return mine.first;
  }

  /// Whether [uid] is still in the event (has not lost).
  bool stillIn(String? uid) {
    if (uid == null) return false;
    if (!matches.any((m) => m.involves(uid))) return false;
    return !matches.any(
        (m) => m.involves(uid) && m.isDecided && m.winnerId != uid);
  }

  // ── The organiser's question: what blocks this round? ────────────────────

  List<BracketMatch> get currentRoundMatches => matches
      .where((m) => m.round == currentRound)
      .toList(growable: false)
    ..sort((a, b) => a.slot.compareTo(b.slot));

  /// The matches stopping the next round from starting — the worklist.
  List<BracketMatch> get blocking =>
      currentRoundMatches.where((m) => m.blocksRound).toList(growable: false);

  /// The current round is decided and another exists to start.
  bool get canStartNextRound =>
      inProgress && blocking.isEmpty && currentRound < rounds;

  // ── Everyone's question: how is it going? ────────────────────────────────

  /// The final, once both seats are known — the match the champion banner is
  /// explained by, and the one a completed tournament must show.
  BracketMatch? get finalMatch {
    if (rounds == 0) return null;
    final last = matches.where((m) => m.round == rounds);
    return last.isEmpty ? null : last.first;
  }

  /// A round's display position: 0 = final, 1 = semi-final, 2 = quarter-final.
  int fromFinal(int round) => rounds - round;

  @override
  List<Object?> get props => [...super.props, entries, rounds, matches];
}
