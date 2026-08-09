import '../../domain/entities/tournament_entities.dart';

TournamentStatus statusFromWire(String? v) => switch (v) {
      'REGISTRATION_OPEN' => TournamentStatus.open,
      'REGISTRATION_CLOSED' => TournamentStatus.closed,
      'IN_PROGRESS' => TournamentStatus.inProgress,
      'COMPLETED' => TournamentStatus.completed,
      // STARTING_LOCK and anything else the server grows later: unknown, not a
      // crash and not silently "open". The screen says the state is unknown.
      _ => TournamentStatus.unknown,
    };

MatchStatus matchStatusFromWire(String? v) => switch (v) {
      'PENDING' => MatchStatus.pending,
      'READY' => MatchStatus.ready,
      'LIVE' => MatchStatus.live,
      'DONE' => MatchStatus.done,
      'BYE' => MatchStatus.bye,
      _ => MatchStatus.unknown,
    };

PlayerRef? playerFromJson(Object? j) => j is Map
    ? PlayerRef(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] as String?) ?? 'Player')
    : null;

TournamentEntry entryFromJson(Map<String, dynamic> j) => TournamentEntry(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] as String?) ?? 'Player',
      status: (j['status'] as String?) ?? 'APPROVED',
    );

BracketMatch matchFromJson(Map<String, dynamic> j) => BracketMatch(
      id: (j['id'] ?? '').toString(),
      round: (j['round'] as num?)?.toInt() ?? 1,
      slot: (j['slot'] as num?)?.toInt() ?? 0,
      status: matchStatusFromWire(j['status'] as String?),
      playerA: playerFromJson(j['player_a']),
      playerB: playerFromJson(j['player_b']),
      winnerId: j['winner_id']?.toString(),
      gameId: j['game_id']?.toString(),
      conductMode: (j['conduct_mode'] as String?) ?? 'APP',
      activated: j['activated'] as bool? ?? false,
      aReady: j['a_ready'] as bool? ?? false,
      bReady: j['b_ready'] as bool? ?? false,
      venue: j['venue'] as String?,
      reportingTime:
          DateTime.tryParse(j['reporting_time'] as String? ?? '')?.toLocal(),
    );

Tournament tournamentFromJson(Map<String, dynamic> j) => Tournament(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] as String?) ?? '',
      description: j['description'] as String?,
      shortCode: j['short_code'] as String?,
      status: statusFromWire(j['status'] as String?),
      registrationDeadline: DateTime.tryParse(
              j['registration_deadline'] as String? ?? '')
          ?.toLocal(),
      entryCount: (j['entry_count'] as num?)?.toInt() ?? 0,
      pendingCount: (j['pending_count'] as num?)?.toInt() ?? 0,
      currentRound: (j['current_round'] as num?)?.toInt() ?? 0,
      isRegistered: j['is_registered'] as bool? ?? false,
      myStatus: j['my_status'] as String?,
      champion: playerFromJson(j['champion']),
      timeControl: (j['time_control'] as String?) ?? 'rapid_10_0',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
    );

TournamentDetail detailFromJson(Map<String, dynamic> j) {
  final t = tournamentFromJson(j);
  return TournamentDetail(
    id: t.id,
    name: t.name,
    description: t.description,
    shortCode: t.shortCode,
    status: t.status,
    registrationDeadline: t.registrationDeadline,
    entryCount: t.entryCount,
    pendingCount: t.pendingCount,
    currentRound: t.currentRound,
    isRegistered: t.isRegistered,
    myStatus: t.myStatus,
    champion: t.champion,
    timeControl: t.timeControl,
    createdAt: t.createdAt,
    entries: [
      for (final e in (j['entries'] as List? ?? []))
        if (e is Map) entryFromJson(e.cast<String, dynamic>())
    ],
    rounds: (j['rounds'] as num?)?.toInt() ?? 0,
    matches: [
      for (final m in (j['matches'] as List? ?? []))
        if (m is Map) matchFromJson(m.cast<String, dynamic>())
    ],
  );
}
