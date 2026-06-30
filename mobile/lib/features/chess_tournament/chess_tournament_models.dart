class PlayerRef {
  final String id;
  final String name;
  const PlayerRef({required this.id, required this.name});

  factory PlayerRef.fromJson(Map<String, dynamic> j) =>
      PlayerRef(id: (j['id'] ?? '').toString(), name: (j['name'] as String?) ?? 'Player');
}

class ChessTournament {
  final String id;
  final String name;
  final String? description;
  final String status; // REGISTRATION_OPEN / IN_PROGRESS / COMPLETED
  final String? registrationDeadline;
  final int entryCount;
  final bool isRegistered;
  final PlayerRef? champion;

  const ChessTournament({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.registrationDeadline,
    required this.entryCount,
    required this.isRegistered,
    this.champion,
  });

  factory ChessTournament.fromJson(Map<String, dynamic> j) => ChessTournament(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] as String?) ?? '',
        description: j['description'] as String?,
        status: (j['status'] as String?) ?? 'REGISTRATION_OPEN',
        registrationDeadline: j['registration_deadline'] as String?,
        entryCount: (j['entry_count'] as num?)?.toInt() ?? 0,
        isRegistered: j['is_registered'] as bool? ?? false,
        champion: j['champion'] != null
            ? PlayerRef.fromJson((j['champion'] as Map).cast<String, dynamic>())
            : null,
      );
}

class BracketMatch {
  final String id;
  final int round;
  final int slot;
  final PlayerRef? playerA;
  final PlayerRef? playerB;
  final String? winnerId;
  final String? gameId;
  final String status; // PENDING/READY/LIVE/DONE/BYE

  const BracketMatch({
    required this.id,
    required this.round,
    required this.slot,
    this.playerA,
    this.playerB,
    this.winnerId,
    this.gameId,
    required this.status,
  });

  factory BracketMatch.fromJson(Map<String, dynamic> j) => BracketMatch(
        id: (j['id'] ?? '').toString(),
        round: (j['round'] as num?)?.toInt() ?? 1,
        slot: (j['slot'] as num?)?.toInt() ?? 0,
        playerA: j['player_a'] != null
            ? PlayerRef.fromJson((j['player_a'] as Map).cast<String, dynamic>())
            : null,
        playerB: j['player_b'] != null
            ? PlayerRef.fromJson((j['player_b'] as Map).cast<String, dynamic>())
            : null,
        winnerId: j['winner_id']?.toString(),
        gameId: j['game_id']?.toString(),
        status: (j['status'] as String?) ?? 'PENDING',
      );
}

class ChessTournamentDetail extends ChessTournament {
  final List<PlayerRef> entries;
  final int rounds;
  final List<BracketMatch> matches;

  const ChessTournamentDetail({
    required super.id,
    required super.name,
    super.description,
    required super.status,
    super.registrationDeadline,
    required super.entryCount,
    required super.isRegistered,
    super.champion,
    required this.entries,
    required this.rounds,
    required this.matches,
  });

  factory ChessTournamentDetail.fromJson(Map<String, dynamic> j) {
    final t = ChessTournament.fromJson(j);
    return ChessTournamentDetail(
      id: t.id,
      name: t.name,
      description: t.description,
      status: t.status,
      registrationDeadline: t.registrationDeadline,
      entryCount: t.entryCount,
      isRegistered: t.isRegistered,
      champion: t.champion,
      entries: ((j['entries'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PlayerRef.fromJson(e.cast<String, dynamic>()))
          .toList(),
      rounds: (j['rounds'] as num?)?.toInt() ?? 0,
      matches: ((j['matches'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BracketMatch.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
