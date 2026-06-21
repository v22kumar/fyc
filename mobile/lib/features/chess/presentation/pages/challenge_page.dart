import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/chess_remote_datasource.dart';
import '../../data/models/chess_game_model.dart';

class ChallengePage extends StatefulWidget {
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _ds = sl<ChessRemoteDataSource>();

  late Future<List<ChessMemberModel>> _membersFuture;
  late Future<List<ChessChallengeModel>> _incomingFuture;
  late Future<List<ChessChallengeModel>> _outgoingFuture;

  String _selectedTime = 'untimed';
  bool _sending = false;

  static const _timeControls = [
    ('untimed', 'Casual'),
    ('blitz_5_0', 'Blitz 5+0'),
    ('rapid_10_0', 'Rapid 10+0'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _membersFuture = _ds.members();
      _incomingFuture = _ds.incomingChallenges();
      _outgoingFuture = _ds.outgoingChallenges();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Online Match',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '⚔️  Challenge'),
            Tab(text: '📬  Inbox'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ChallengeTab(
            membersFuture: _membersFuture,
            outgoingFuture: _outgoingFuture,
            selectedTime: _selectedTime,
            timeControls: _timeControls,
            onTimeChanged: (t) => setState(() => _selectedTime = t),
            onChallenge: _sendChallenge,
            sending: _sending,
          ),
          _InboxTab(
            incomingFuture: _incomingFuture,
            onAccept: _acceptChallenge,
            onDecline: _declineChallenge,
            onRefresh: _reload,
          ),
        ],
      ),
    );
  }

  Future<void> _sendChallenge(String userId, String name) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _ds.sendChallenge(
          challengedId: userId, timeControl: _selectedTime);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge sent to $name!'),
          backgroundColor: AppColors.primaryLight,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _acceptChallenge(ChessChallengeModel c) async {
    try {
      final storage = sl<LocalStorage>();
      final token = await storage.getToken() ?? '';
      final result = await _ds.acceptChallenge(c.id);
      if (!mounted) return;
      context.push(
        '/chess/online/${result.gameId}',
        extra: {
          'token': token,
          'color': result.color,
          'opponent': c.challengerName ?? 'Opponent',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _declineChallenge(ChessChallengeModel c) async {
    try {
      await _ds.declineChallenge(c.id);
      _reload();
    } catch (_) {}
  }
}

// ── Challenge tab ─────────────────────────────────────────────────────────────

class _ChallengeTab extends StatelessWidget {
  final Future<List<ChessMemberModel>> membersFuture;
  final Future<List<ChessChallengeModel>> outgoingFuture;
  final String selectedTime;
  final List<(String, String)> timeControls;
  final void Function(String) onTimeChanged;
  final void Function(String userId, String name) onChallenge;
  final bool sending;

  const _ChallengeTab({
    required this.membersFuture,
    required this.outgoingFuture,
    required this.selectedTime,
    required this.timeControls,
    required this.onTimeChanged,
    required this.onChallenge,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Time control selector
        Container(
          color: AppColors.darkBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: timeControls
                .map((tc) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _TimeChip(
                          label: tc.$2,
                          selected: selectedTime == tc.$1,
                          onTap: () => onTimeChanged(tc.$1),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        Expanded(
          child: FutureBuilder<List<ChessMemberModel>>(
            future: membersFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight));
              }
              if (snap.hasError) {
                return const Center(
                    child: Text('Could not load members',
                        style: TextStyle(color: AppColors.textSecondary)));
              }
              final members = snap.data ?? [];
              if (members.isEmpty) {
                return const Center(
                    child: Text('No other members found',
                        style: TextStyle(color: AppColors.textSecondary)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                itemBuilder: (context, i) => _MemberTile(
                  member: members[i],
                  onChallenge: () => onChallenge(members[i].userId, members[i].name),
                  sending: sending,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ChessMemberModel member;
  final VoidCallback onChallenge;
  final bool sending;

  const _MemberTile(
      {required this.member,
      required this.onChallenge,
      required this.sending});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                Text(
                  '${member.ratingDisplay} rating · ${member.gamesPlayed} games',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: sending ? null : onChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('⚔️', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ── Inbox tab ─────────────────────────────────────────────────────────────────

class _InboxTab extends StatelessWidget {
  final Future<List<ChessChallengeModel>> incomingFuture;
  final void Function(ChessChallengeModel) onAccept;
  final void Function(ChessChallengeModel) onDecline;
  final VoidCallback onRefresh;

  const _InboxTab({
    required this.incomingFuture,
    required this.onAccept,
    required this.onDecline,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChessChallengeModel>>(
      future: incomingFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight));
        }
        final challenges = snap.data ?? [];
        if (challenges.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📬', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('No pending challenges',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, i) => _ChallengeTile(
            challenge: challenges[i],
            onAccept: () => onAccept(challenges[i]),
            onDecline: () => onDecline(challenges[i]),
          ),
        );
      },
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final ChessChallengeModel challenge;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ChallengeTile(
      {required this.challenge,
      required this.onAccept,
      required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final from = challenge.challengerName ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('⚔️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$from challenges you!',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    Text(
                      _timeLabel(challenge.timeControl),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (challenge.message != null && challenge.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${challenge.message}"',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeLabel(String tc) => switch (tc) {
    'blitz_5_0' => '⚡ Blitz 5+0',
    'rapid_10_0' => '🕐 Rapid 10+0',
    'bullet_1_0' => '🔫 Bullet 1+0',
    _ => '♟ Casual (untimed)',
  };
}
