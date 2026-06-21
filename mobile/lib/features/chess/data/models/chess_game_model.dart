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
  final String title;
  final String titleEmoji;

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
    this.title = 'Newcomer',
    this.titleEmoji = '🌱',
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
      title: json['title'] as String? ?? 'Newcomer',
      titleEmoji: json['title_emoji'] as String? ?? '🌱',
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

class ChessChallengeModel {
  final String id;
  final String challengerId;
  final String challengedId;
  final String? challengerName;
  final String? challengedName;
  final String timeControl;
  final String status;
  final String? gameId;
  final String? message;
  final String createdAt;

  const ChessChallengeModel({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    this.challengerName,
    this.challengedName,
    required this.timeControl,
    required this.status,
    this.gameId,
    this.message,
    required this.createdAt,
  });

  factory ChessChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChessChallengeModel(
      id: json['id'] as String,
      challengerId: json['challenger_id'] as String,
      challengedId: json['challenged_id'] as String,
      challengerName: json['challenger_name'] as String?,
      challengedName: json['challenged_name'] as String?,
      timeControl: json['time_control'] as String? ?? 'untimed',
      status: json['status'] as String? ?? 'pending',
      gameId: json['game_id'] as String?,
      message: json['message'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ChessMemberModel {
  final String userId;
  final String name;
  final String? area;
  final double glickoRating;
  final int gamesPlayed;

  const ChessMemberModel({
    required this.userId,
    required this.name,
    this.area,
    required this.glickoRating,
    required this.gamesPlayed,
  });

  factory ChessMemberModel.fromJson(Map<String, dynamic> json) {
    return ChessMemberModel(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      area: json['area'] as String?,
      glickoRating: (json['glicko_rating'] as num?)?.toDouble() ?? 1500.0,
      gamesPlayed: json['games_played'] as int? ?? 0,
    );
  }

  String get ratingDisplay => glickoRating.round().toString();
}

class LiveGameModel {
  final String id;
  final String whiteName;
  final String blackName;
  final int ply;
  final String timeControl;
  final int spectatorCount;

  const LiveGameModel({
    required this.id,
    required this.whiteName,
    required this.blackName,
    required this.ply,
    required this.timeControl,
    required this.spectatorCount,
  });

  factory LiveGameModel.fromJson(Map<String, dynamic> json) {
    return LiveGameModel(
      id: json['id'] as String,
      whiteName: json['white_name'] as String? ?? 'White',
      blackName: json['black_name'] as String? ?? 'Black',
      ply: json['ply'] as int? ?? 0,
      timeControl: json['time_control'] as String? ?? 'untimed',
      spectatorCount: json['spectator_count'] as int? ?? 0,
    );
  }
}

// ── Game detail (with full move list) ────────────────────────────────────────

class ChessMoveModel {
  final int ply;
  final String uci;
  final String san;
  final String? fenAfter;

  const ChessMoveModel({
    required this.ply,
    required this.uci,
    required this.san,
    this.fenAfter,
  });

  factory ChessMoveModel.fromJson(Map<String, dynamic> json) {
    return ChessMoveModel(
      ply: json['ply'] as int? ?? 0,
      uci: json['uci'] as String? ?? '',
      san: json['san'] as String? ?? '',
      fenAfter: json['fen_after'] as String?,
    );
  }
}

class ChessGameDetailModel extends ChessGameModel {
  final List<ChessMoveModel> moves;

  const ChessGameDetailModel({
    required super.id,
    required super.mode,
    required super.timeControl,
    super.whiteId,
    super.blackId,
    super.whiteName,
    super.blackName,
    super.result,
    super.drawReason,
    required super.totalMoves,
    super.whiteRatingBefore,
    super.whiteRatingAfter,
    super.createdAt,
    super.endedAt,
    required this.moves,
  });

  factory ChessGameDetailModel.fromJson(Map<String, dynamic> json) {
    final base = ChessGameModel.fromJson(json);
    final movesRaw = json['moves'] as List? ?? [];
    return ChessGameDetailModel(
      id: base.id,
      mode: base.mode,
      timeControl: base.timeControl,
      whiteId: base.whiteId,
      blackId: base.blackId,
      whiteName: base.whiteName,
      blackName: base.blackName,
      result: base.result,
      drawReason: base.drawReason,
      totalMoves: base.totalMoves,
      whiteRatingBefore: base.whiteRatingBefore,
      whiteRatingAfter: base.whiteRatingAfter,
      createdAt: base.createdAt,
      endedAt: base.endedAt,
      moves: movesRaw
          .map((m) => ChessMoveModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  String get pgn {
    final white = whiteName ?? 'White';
    final black = blackName ?? 'Black';
    final date = _pgnDate();
    final resultStr = result == 'white_wins'
        ? '1-0'
        : result == 'black_wins'
            ? '0-1'
            : '1/2-1/2';

    final header = '[Event "FYC Chess"]\n'
        '[Site "fyc-web.fly.dev"]\n'
        '[Date "$date"]\n'
        '[White "$white"]\n'
        '[Black "$black"]\n'
        '[Result "$resultStr"]\n\n';

    final buffer = StringBuffer();
    for (var i = 0; i < moves.length; i++) {
      if (i % 2 == 0) buffer.write('${i ~/ 2 + 1}. ');
      buffer.write('${moves[i].san} ');
    }
    buffer.write(resultStr);

    return header + buffer.toString();
  }

  String _pgnDate() {
    if (createdAt == null) return '????.??.??';
    try {
      final dt = DateTime.parse(createdAt!).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '????.??.??';
    }
  }
}

// ── Weekly Awards ─────────────────────────────────────────────────────────────

class AwardWinnerModel {
  final String userId;
  final String name;

  const AwardWinnerModel({required this.userId, required this.name});

  factory AwardWinnerModel.fromJson(Map<String, dynamic> json) =>
      AwardWinnerModel(
        userId: json['user_id'] as String,
        name: json['name'] as String,
      );
}

class WeeklyAwardsModel {
  final String weekStart;
  final AwardWinnerModel? topPlayer;
  final AwardWinnerModel? mostActive;
  final AwardWinnerModel? bestNewcomer;
  final AwardWinnerModel? sharpestMind;

  const WeeklyAwardsModel({
    required this.weekStart,
    this.topPlayer,
    this.mostActive,
    this.bestNewcomer,
    this.sharpestMind,
  });

  factory WeeklyAwardsModel.fromJson(Map<String, dynamic> json) {
    AwardWinnerModel? _parse(String key) {
      final v = json[key];
      if (v == null) return null;
      return AwardWinnerModel.fromJson(v as Map<String, dynamic>);
    }

    return WeeklyAwardsModel(
      weekStart: json['week_start'] as String? ?? '',
      topPlayer: _parse('top_player'),
      mostActive: _parse('most_active'),
      bestNewcomer: _parse('best_newcomer'),
      sharpestMind: _parse('sharpest_mind'),
    );
  }
}

class ChallengeAcceptResult {
  final String gameId;
  final String color; // "white" | "black"
  final String? opponentName;
  final String timeControl;

  const ChallengeAcceptResult({
    required this.gameId,
    required this.color,
    this.opponentName,
    required this.timeControl,
  });

  factory ChallengeAcceptResult.fromJson(Map<String, dynamic> json) {
    return ChallengeAcceptResult(
      gameId: json['game_id'] as String,
      color: json['color'] as String,
      opponentName: json['opponent_name'] as String?,
      timeControl: json['time_control'] as String? ?? 'untimed',
    );
  }
}
