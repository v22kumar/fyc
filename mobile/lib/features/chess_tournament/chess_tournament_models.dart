class PlayerRef {
  final String id;
  final String name;
  const PlayerRef({required this.id, required this.name});

  factory PlayerRef.fromJson(Map<String, dynamic> j) =>
      PlayerRef(id: (j['id'] ?? '').toString(), name: (j['name'] as String?) ?? 'Player');
}

/// A registered player and their approval status.
class TournamentEntry {
  final String id; // the player's user id
  final String name;
  final String status; // PENDING / APPROVED / REJECTED
  const TournamentEntry({required this.id, required this.name, required this.status});

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory TournamentEntry.fromJson(Map<String, dynamic> j) => TournamentEntry(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] as String?) ?? 'Player',
        status: (j['status'] as String?) ?? 'APPROVED',
      );
}

class ChessTournament {
  final String id;
  final String name;
  final String? description;
  // REGISTRATION_OPEN / REGISTRATION_CLOSED / IN_PROGRESS / COMPLETED
  final String status;
  final String? registrationDeadline;
  final int entryCount; // approved players
  final int pendingCount; // registrations awaiting a decision
  final int currentRound;
  final bool isRegistered;
  final String? myStatus; // PENDING / APPROVED / REJECTED for the caller
  final PlayerRef? champion;

  const ChessTournament({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.registrationDeadline,
    required this.entryCount,
    this.pendingCount = 0,
    this.currentRound = 0,
    required this.isRegistered,
    this.myStatus,
    this.champion,
  });

  bool get isOpen => status == 'REGISTRATION_OPEN';
  bool get isClosed => status == 'REGISTRATION_CLOSED';
  bool get inProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';

  factory ChessTournament.fromJson(Map<String, dynamic> j) => ChessTournament(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] as String?) ?? '',
        description: j['description'] as String?,
        status: (j['status'] as String?) ?? 'REGISTRATION_OPEN',
        registrationDeadline: j['registration_deadline'] as String?,
        entryCount: (j['entry_count'] as num?)?.toInt() ?? 0,
        pendingCount: (j['pending_count'] as num?)?.toInt() ?? 0,
        currentRound: (j['current_round'] as num?)?.toInt() ?? 0,
        isRegistered: j['is_registered'] as bool? ?? false,
        myStatus: j['my_status'] as String?,
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
  final String conductMode; // APP (online) or PHYSICAL (in person)
  final bool activated; // the manager has started this match's round
  final bool aReady;
  final bool bReady;
  final String? venue;
  final String? reportingTime;

  const BracketMatch({
    required this.id,
    required this.round,
    required this.slot,
    this.playerA,
    this.playerB,
    this.winnerId,
    this.gameId,
    required this.status,
    this.conductMode = 'APP',
    this.activated = false,
    this.aReady = false,
    this.bReady = false,
    this.venue,
    this.reportingTime,
  });

  bool get isPhysical => conductMode == 'PHYSICAL';
  bool readyFor(String? uid) =>
      uid != null && ((uid == playerA?.id && aReady) || (uid == playerB?.id && bReady));
  bool opponentReadyFor(String? uid) =>
      uid != null && ((uid == playerA?.id && bReady) || (uid == playerB?.id && aReady));

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
        conductMode: (j['conduct_mode'] as String?) ?? 'APP',
        activated: j['activated'] as bool? ?? false,
        aReady: j['a_ready'] as bool? ?? false,
        bReady: j['b_ready'] as bool? ?? false,
        venue: j['venue'] as String?,
        reportingTime: j['reporting_time'] as String?,
      );
}

class ChessTournamentDetail extends ChessTournament {
  final List<TournamentEntry> entries;
  final int rounds;
  final List<BracketMatch> matches;

  const ChessTournamentDetail({
    required super.id,
    required super.name,
    super.description,
    required super.status,
    super.registrationDeadline,
    required super.entryCount,
    super.pendingCount,
    super.currentRound,
    required super.isRegistered,
    super.myStatus,
    super.champion,
    required this.entries,
    required this.rounds,
    required this.matches,
  });

  List<TournamentEntry> get pendingEntries =>
      entries.where((e) => e.isPending).toList();
  List<TournamentEntry> get approvedEntries =>
      entries.where((e) => e.isApproved).toList();

  factory ChessTournamentDetail.fromJson(Map<String, dynamic> j) {
    final t = ChessTournament.fromJson(j);
    return ChessTournamentDetail(
      id: t.id,
      name: t.name,
      description: t.description,
      status: t.status,
      registrationDeadline: t.registrationDeadline,
      entryCount: t.entryCount,
      pendingCount: t.pendingCount,
      currentRound: t.currentRound,
      isRegistered: t.isRegistered,
      myStatus: t.myStatus,
      champion: t.champion,
      entries: ((j['entries'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => TournamentEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      rounds: (j['rounds'] as num?)?.toInt() ?? 0,
      matches: ((j['matches'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BracketMatch.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
