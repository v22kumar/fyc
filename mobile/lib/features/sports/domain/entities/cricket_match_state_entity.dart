import 'package:equatable/equatable.dart';

/// One batter's live scorecard line, keyed by the backend Player UUID.
class CricketBatterEntity extends Equatable {
  final String id;
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool out;

  const CricketBatterEntity({
    required this.id,
    required this.name,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.out,
  });

  @override
  List<Object?> get props => [id, name, runs, balls, fours, sixes, out];
}

/// One bowler's live scorecard line, keyed by the backend Player UUID.
class CricketBowlerEntity extends Equatable {
  final String id;
  final String name;
  final int legalBalls;
  final int runs;
  final int wickets;

  const CricketBowlerEntity({
    required this.id,
    required this.name,
    required this.legalBalls,
    required this.runs,
    required this.wickets,
  });

  String get oversText => '${legalBalls ~/ 6}.${legalBalls % 6}';

  @override
  List<Object?> get props => [id, name, legalBalls, runs, wickets];
}

/// The three players currently involved in the ball being bowled. The
/// backend returns this from init / second-innings so the scorer never
/// has to type Player UUIDs.
class CricketPlayersEntity extends Equatable {
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final String strikerName;
  final String nonStrikerName;
  final String bowlerName;

  const CricketPlayersEntity({
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
    required this.strikerName,
    required this.nonStrikerName,
    required this.bowlerName,
  });

  CricketPlayersEntity copyWith({
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
    String? strikerName,
    String? nonStrikerName,
    String? bowlerName,
  }) {
    return CricketPlayersEntity(
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      bowlerId: bowlerId ?? this.bowlerId,
      strikerName: strikerName ?? this.strikerName,
      nonStrikerName: nonStrikerName ?? this.nonStrikerName,
      bowlerName: bowlerName ?? this.bowlerName,
    );
  }

  CricketPlayersEntity swapped() => CricketPlayersEntity(
        strikerId: nonStrikerId,
        nonStrikerId: strikerId,
        strikerName: nonStrikerName,
        nonStrikerName: strikerName,
        bowlerId: bowlerId,
        bowlerName: bowlerName,
      );

  @override
  List<Object?> get props =>
      [strikerId, nonStrikerId, bowlerId, strikerName, nonStrikerName, bowlerName];
}

class CricketMatchStateEntity extends Equatable {
  final int innings;
  final String? battingTeamId;
  final String? bowlingTeamId;
  final int score;
  final int wickets;
  final int overs;
  final int balls;
  final int? target;

  /// Lifecycle: FIRST_INNINGS / INNINGS_BREAK / SECOND_INNINGS / COMPLETED.
  final String status;
  final List<CricketBatterEntity> batters;
  final List<CricketBowlerEntity> bowlers;
  final Map<String, int> extras;
  final List<String> recentBalls;
  final List<CricketOverHistoryEntity> oversHistory;

  /// Village house-rule: first two wides per over carry no penalty run.
  final bool villageWides;
  /// Wides landed in the over currently in progress (drives whether the next
  /// wide is still "free" under the village rule).
  final int widesThisOver;

  const CricketMatchStateEntity({
    required this.innings,
    this.battingTeamId,
    this.bowlingTeamId,
    required this.score,
    required this.wickets,
    required this.overs,
    required this.balls,
    this.target,
    this.status = 'FIRST_INNINGS',
    this.batters = const [],
    this.bowlers = const [],
    this.extras = const {},
    this.recentBalls = const [],
    this.oversHistory = const [],
    this.villageWides = false,
    this.widesThisOver = 0,
  });

  bool get isLive => status == 'FIRST_INNINGS' || status == 'SECOND_INNINGS';
  bool get isInningsBreak => status == 'INNINGS_BREAK';
  bool get isCompleted => status == 'COMPLETED';

  /// True when the next wide would be free under the village rule.
  bool get nextWideIsFree => villageWides && widesThisOver < 2;

  String get oversText => '$overs.$balls';
  int get extrasTotal => extras.values.fold(0, (a, b) => a + b);

  @override
  List<Object?> get props => [
        innings,
        battingTeamId,
        bowlingTeamId,
        score,
        wickets,
        overs,
        balls,
        target,
        status,
        batters,
        bowlers,
        extras,
        recentBalls,
        oversHistory,
        villageWides,
        widesThisOver,
      ];
}

class CricketBallEntity extends Equatable {
  final String id;
  final int ballIndex;
  final String strikerId;
  final String strikerName;
  final String nonStrikerId;
  final String nonStrikerName;
  final String bowlerId;
  final String bowlerName;
  final int runsBatter;
  final String? extrasType;
  final int extrasRuns;
  final bool isWicket;
  final String? wicketType;
  final String? playerDismissedId;
  final String ballStr;
  final bool isLegal;
  final String? notes;
  final bool hasEditHistory;

  const CricketBallEntity({
    required this.id,
    required this.ballIndex,
    required this.strikerId,
    required this.strikerName,
    required this.nonStrikerId,
    required this.nonStrikerName,
    required this.bowlerId,
    required this.bowlerName,
    required this.runsBatter,
    this.extrasType,
    required this.extrasRuns,
    required this.isWicket,
    this.wicketType,
    this.playerDismissedId,
    required this.ballStr,
    required this.isLegal,
    this.notes,
    this.hasEditHistory = false,
  });

  @override
  List<Object?> get props => [
        id,
        ballIndex,
        strikerId,
        strikerName,
        nonStrikerId,
        nonStrikerName,
        bowlerId,
        bowlerName,
        runsBatter,
        extrasType,
        extrasRuns,
        isWicket,
        wicketType,
        playerDismissedId,
        ballStr,
        isLegal,
        notes,
        hasEditHistory,
      ];
}

class CricketOverHistoryEntity extends Equatable {
  final int overIndex;
  final List<CricketBallEntity> balls;

  const CricketOverHistoryEntity({
    required this.overIndex,
    required this.balls,
  });

  @override
  List<Object?> get props => [overIndex, balls];
}
