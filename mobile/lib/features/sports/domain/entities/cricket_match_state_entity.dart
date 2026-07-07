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
  });

  bool get isLive => status == 'FIRST_INNINGS' || status == 'SECOND_INNINGS';
  bool get isInningsBreak => status == 'INNINGS_BREAK';
  bool get isCompleted => status == 'COMPLETED';

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
      ];
}
