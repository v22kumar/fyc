class ChessGameModel {
  final String id;
  final String mode;
  final String timeControl;
  final String? whiteId;
  final String? blackId;
  final String? whiteName;
  final String? blackName;
  final String? result;
  final String? drawReason;
  final int totalMoves;
  final double? whiteRatingBefore;
  final double? whiteRatingAfter;
  final String? createdAt;
  final String? endedAt;

  const ChessGameModel({
    required this.id,
    required this.mode,
    required this.timeControl,
    this.whiteId,
    this.blackId,
    this.whiteName,
    this.blackName,
    this.result,
    this.drawReason,
    required this.totalMoves,
    this.whiteRatingBefore,
    this.whiteRatingAfter,
    this.createdAt,
    this.endedAt,
  });

  factory ChessGameModel.fromJson(Map<String, dynamic> json) {
    return ChessGameModel(
      id: json['id'] as String,
      mode: json['mode'] as String? ?? 'local',
      timeControl: json['time_control'] as String? ?? 'untimed',
      whiteId: json['white_id'] as String?,
      blackId: json['black_id'] as String?,
      whiteName: json['white_name'] as String?,
      blackName: json['black_name'] as String?,
      result: json['result'] as String?,
      drawReason: json['draw_reason'] as String?,
      totalMoves: json['total_moves'] as int? ?? 0,
      whiteRatingBefore: (json['white_rating_before'] as num?)?.toDouble(),
      whiteRatingAfter: (json['white_rating_after'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
      endedAt: json['ended_at'] as String?,
    );
  }

  String get resultLabel {
    if (result == null) return 'In progress';
    final w = whiteName ?? 'White';
    final b = blackName ?? 'Black';
    return switch (result) {
      'white_wins' => '$w wins',
      'black_wins' => '$b wins',
      'draw' => 'Draw',
      'abandoned' => 'Abandoned',
      _ => result!,
    };
  }

  String get resultEmoji => switch (result) {
    'white_wins' => '♔',
    'black_wins' => '♚',
    'draw' => '½½',
    _ => '—',
  };
}

class ChessStatsModel {
  final double glickoRating;
  final double glickoRd;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int currentStreak;
  final int longestWinStreak;
  final double winRate;

  const ChessStatsModel({
    required this.glickoRating,
    required this.glickoRd,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.currentStreak,
    required this.longestWinStreak,
    required this.winRate,
  });

  factory ChessStatsModel.fromJson(Map<String, dynamic> json) {
    return ChessStatsModel(
      glickoRating: (json['glicko_rating'] as num?)?.toDouble() ?? 1500.0,
      glickoRd: (json['glicko_rd'] as num?)?.toDouble() ?? 350.0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestWinStreak: json['longest_win_streak'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory ChessStatsModel.empty() => const ChessStatsModel(
    glickoRating: 1500,
    glickoRd: 350,
    gamesPlayed: 0,
    wins: 0,
    losses: 0,
    draws: 0,
    currentStreak: 0,
    longestWinStreak: 0,
    winRate: 0.0,
  );

  String get ratingDisplay => '${glickoRating.round()}';
  String get winRateDisplay => '${(winRate * 100).round()}%';
}
