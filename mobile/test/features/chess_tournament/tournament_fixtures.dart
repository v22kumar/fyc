/// Canned server responses for the chess tournament lifecycle.
///
/// Written against `app/schemas/chess_tournament.py` rather than invented, so
/// what these screens are photographed rendering is the shape the backend
/// actually sends. If the schema moves, these should fail to look right.
String uid(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

const kOrganiserId = '00000000-0000-4000-8000-000000000001';

/// Eight players, because a knockout is only honest at a power of two.
const _names = [
  'Arun Kumar', 'Suresh K.', 'Meena R.', 'Vijay S.',
  'Latha M.', 'Prakash N.', 'Devi A.', 'Karthik P.',
];

Map<String, dynamic> _player(int n) => {'id': uid(n + 10), 'name': _names[n]};

Map<String, dynamic> _entry(int n, String status) =>
    {'id': uid(n + 10), 'name': _names[n], 'status': status};

Map<String, dynamic> _match({
  required int round,
  required int slot,
  int? a,
  int? b,
  int? winner,
  required String status,
  String conduct = 'APP',
  bool activated = false,
  bool aReady = false,
  bool bReady = false,
  String? venue,
  String? reportingTime,
  bool live = false,
}) =>
    {
      'id': uid(round * 100 + slot),
      'round': round,
      'slot': slot,
      'player_a': a == null ? null : _player(a),
      'player_b': b == null ? null : _player(b),
      'winner_id': winner == null ? null : uid(winner + 10),
      'game_id': live ? uid(900 + slot) : null,
      'status': status,
      'conduct_mode': conduct,
      'activated': activated,
      'a_ready': aReady,
      'b_ready': bReady,
      'venue': venue,
      'reporting_time': reportingTime,
    };

Map<String, dynamic> _base({
  required String status,
  required int currentRound,
  required int entryCount,
  int pendingCount = 0,
  bool isRegistered = false,
  String? myStatus,
  Map<String, dynamic>? champion,
}) =>
    {
      'id': uid(1000),
      'short_code': 'K7P2',
      'name': 'FYC Chess Championship 2026',
      'description': 'Single elimination · Nagercoil club hall',
      'status': status,
      'registration_deadline': '2026-08-14T12:00:00Z',
      'time_control': 'rapid_10_0',
      'entry_count': entryCount,
      'pending_count': pendingCount,
      'current_round': currentRound,
      'is_registered': isRegistered,
      'my_status': myStatus,
      'champion': champion,
      'created_at': '2026-08-01T09:00:00Z',
    };

// ── The stages ───────────────────────────────────────────────────────────────

/// 1. Just created. Nobody has joined.
Map<String, dynamic> get stageOpenEmpty => {
      ..._base(status: 'REGISTRATION_OPEN', currentRound: 0, entryCount: 0),
      'entries': <Map<String, dynamic>>[],
      'rounds': 0,
      'matches': <Map<String, dynamic>>[],
    };

/// 2. Players joining. Three are waiting on the manager's decision.
Map<String, dynamic> get stageOpenWithPending => {
      ..._base(
        status: 'REGISTRATION_OPEN',
        currentRound: 0,
        entryCount: 5,
        pendingCount: 3,
      ),
      'entries': [
        for (var i = 0; i < 5; i++) _entry(i, 'APPROVED'),
        for (var i = 5; i < 8; i++) _entry(i, 'PENDING'),
      ],
      'rounds': 0,
      'matches': <Map<String, dynamic>>[],
    };

/// 3. A player's own view while their registration is pending.
Map<String, dynamic> get stagePlayerPending => {
      ..._base(
        status: 'REGISTRATION_OPEN',
        currentRound: 0,
        entryCount: 5,
        isRegistered: true,
        myStatus: 'PENDING',
      ),
      'entries': [for (var i = 0; i < 5; i++) _entry(i, 'APPROVED')],
      'rounds': 0,
      'matches': <Map<String, dynamic>>[],
    };

/// 4. Registration closed, eight approved, waiting for the organiser to start.
Map<String, dynamic> get stageClosedReadyToStart => {
      ..._base(status: 'REGISTRATION_CLOSED', currentRound: 0, entryCount: 8),
      'entries': [for (var i = 0; i < 8; i++) _entry(i, 'APPROVED')],
      'rounds': 0,
      'matches': <Map<String, dynamic>>[],
    };

/// 5. Round 1 live: one finished, one in play, one waiting on a ready ack,
///    one where neither player has acknowledged.
Map<String, dynamic> get stageRoundOneLive => {
      ..._base(status: 'IN_PROGRESS', currentRound: 1, entryCount: 8),
      'entries': [for (var i = 0; i < 8; i++) _entry(i, 'APPROVED')],
      'rounds': 3,
      'matches': [
        _match(round: 1, slot: 0, a: 0, b: 1, winner: 0, status: 'DONE',
            activated: true),
        _match(round: 1, slot: 1, a: 2, b: 3, status: 'LIVE',
            activated: true, aReady: true, bReady: true, live: true),
        _match(round: 1, slot: 2, a: 4, b: 5, status: 'READY',
            activated: true, aReady: true),
        _match(round: 1, slot: 3, a: 6, b: 7, status: 'READY', activated: true),
        for (var s = 0; s < 2; s++)
          _match(round: 2, slot: s, status: 'PENDING'),
        _match(round: 3, slot: 0, status: 'PENDING'),
      ],
    };

/// 6. Round 1 finished. The manager has not started round 2 yet — the gap
///    between one batch of games and the next.
Map<String, dynamic> get stageBetweenRounds => {
      ..._base(status: 'IN_PROGRESS', currentRound: 1, entryCount: 8),
      'entries': [for (var i = 0; i < 8; i++) _entry(i, 'APPROVED')],
      'rounds': 3,
      'matches': [
        _match(round: 1, slot: 0, a: 0, b: 1, winner: 0, status: 'DONE', activated: true),
        _match(round: 1, slot: 1, a: 2, b: 3, winner: 2, status: 'DONE', activated: true),
        _match(round: 1, slot: 2, a: 4, b: 5, winner: 5, status: 'DONE', activated: true),
        _match(round: 1, slot: 3, a: 6, b: 7, winner: 6, status: 'DONE', activated: true),
        _match(round: 2, slot: 0, a: 0, b: 2, status: 'PENDING'),
        _match(round: 2, slot: 1, a: 5, b: 6, status: 'PENDING'),
        _match(round: 3, slot: 0, status: 'PENDING'),
      ],
    };

/// 7. Semi-finals, one of them played in person at the club hall.
Map<String, dynamic> get stageSemisPhysical => {
      ..._base(status: 'IN_PROGRESS', currentRound: 2, entryCount: 8),
      'entries': [for (var i = 0; i < 8; i++) _entry(i, 'APPROVED')],
      'rounds': 3,
      'matches': [
        _match(round: 1, slot: 0, a: 0, b: 1, winner: 0, status: 'DONE', activated: true),
        _match(round: 1, slot: 1, a: 2, b: 3, winner: 2, status: 'DONE', activated: true),
        _match(round: 1, slot: 2, a: 4, b: 5, winner: 5, status: 'DONE', activated: true),
        _match(round: 1, slot: 3, a: 6, b: 7, winner: 6, status: 'DONE', activated: true),
        _match(round: 2, slot: 0, a: 0, b: 2, status: 'READY', activated: true,
            conduct: 'PHYSICAL', venue: 'FYC club hall, Vadasery',
            reportingTime: '2026-08-16T10:00:00Z'),
        _match(round: 2, slot: 1, a: 5, b: 6, status: 'LIVE', activated: true,
            aReady: true, bReady: true, live: true),
        _match(round: 3, slot: 0, status: 'PENDING'),
      ],
    };

/// 8. Done. There is a champion.
Map<String, dynamic> get stageCompleted => {
      ..._base(
        status: 'COMPLETED',
        currentRound: 3,
        entryCount: 8,
        champion: _player(0),
      ),
      'entries': [for (var i = 0; i < 8; i++) _entry(i, 'APPROVED')],
      'rounds': 3,
      'matches': [
        _match(round: 1, slot: 0, a: 0, b: 1, winner: 0, status: 'DONE', activated: true),
        _match(round: 1, slot: 1, a: 2, b: 3, winner: 2, status: 'DONE', activated: true),
        _match(round: 1, slot: 2, a: 4, b: 5, winner: 5, status: 'DONE', activated: true),
        _match(round: 1, slot: 3, a: 6, b: 7, winner: 6, status: 'DONE', activated: true),
        _match(round: 2, slot: 0, a: 0, b: 2, winner: 0, status: 'DONE', activated: true),
        _match(round: 2, slot: 1, a: 5, b: 6, winner: 6, status: 'DONE', activated: true),
        _match(round: 3, slot: 0, a: 0, b: 6, winner: 0, status: 'DONE', activated: true),
      ],
    };

/// The list screen: one of each state, as a member would find them.
List<Map<String, dynamic>> get stageList => [
      _base(status: 'IN_PROGRESS', currentRound: 2, entryCount: 8),
      {
        ..._base(status: 'REGISTRATION_OPEN', currentRound: 0, entryCount: 5,
            pendingCount: 3),
        'name': 'Independence Day Blitz',
      },
      {
        ..._base(status: 'COMPLETED', currentRound: 3, entryCount: 8,
            champion: _player(0)),
        'name': 'FYC Summer Open 2026',
      },
    ];

/// A player's own view of round one: Prakash (uid 15) has a READY match.
Map<String, dynamic> get stageMyTurn => {
      ..._base(status: 'IN_PROGRESS', currentRound: 1, entryCount: 8,
          isRegistered: true, myStatus: 'APPROVED'),
      'entries': [for (var i = 0; i < 8; i++) _entry(i, 'APPROVED')],
      'rounds': 3,
      'matches': [
        _match(round: 1, slot: 0, a: 0, b: 1, winner: 0, status: 'DONE',
            activated: true),
        _match(round: 1, slot: 1, a: 2, b: 3, status: 'LIVE',
            activated: true, aReady: true, bReady: true, live: true),
        // Prakash (index 5) vs Latha (index 4) — Latha is already ready.
        _match(round: 1, slot: 2, a: 4, b: 5, status: 'READY',
            activated: true, aReady: true),
        _match(round: 1, slot: 3, a: 6, b: 7, status: 'READY',
            activated: true),
        for (var s = 0; s < 2; s++)
          _match(round: 2, slot: s, status: 'PENDING'),
        _match(round: 3, slot: 0, status: 'PENDING'),
      ],
    };
