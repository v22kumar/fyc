import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';

/// Admin/executive queue to approve or reject club-member live-score entries.
class LiveEntriesApprovalScreen extends StatefulWidget {
  const LiveEntriesApprovalScreen({super.key});

  @override
  State<LiveEntriesApprovalScreen> createState() => _LiveEntriesApprovalScreenState();
}

class _LiveEntriesApprovalScreenState extends State<LiveEntriesApprovalScreen> {
  List<dynamic> _entries = [];
  bool _loading = true;
  String _filter = 'PENDING';
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await sl<ApiClient>().dio.get(
        ApiConstants.sportsLiveEntries,
        queryParameters: {'entry_status': _filter},
      );
      if (mounted) setState(() { _entries = res.data as List<dynamic>; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _entries = []; _loading = false; });
    }
  }

  Future<void> _review(String id, String status) async {
    setState(() => _busy.add(id));
    try {
      await sl<ApiClient>().dio.patch(
        '${ApiConstants.sportsLiveEntries}/$id',
        data: {'status': status},
      );
      if (!mounted) return;
      setState(() => _entries.removeWhere((e) => e['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'APPROVED' ? 'Approved — standings updated' : 'Entry rejected'),
          backgroundColor: status == 'APPROVED' ? AppColors.primary : AppColors.accent,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed'), backgroundColor: AppColors.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        title: Text('Score Approvals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText)),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: context.cSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: ['PENDING', 'APPROVED', 'REJECTED'].map((s) {
                final sel = _filter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: sel,
                    onSelected: (_) { setState(() => _filter = s); _load(); },
                    label: Text(s[0] + s.substring(1).toLowerCase()),
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : context.cText, fontWeight: FontWeight.w600, fontSize: 12),
                    selectedColor: AppColors.primary,
                    backgroundColor: context.cBackground,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _Empty(filter: _filter)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _entries.length,
                          itemBuilder: (_, i) => _EntryCard(
                            entry: _entries[i],
                            busy: _busy.contains(_entries[i]['id']),
                            showActions: _filter == 'PENDING',
                            onApprove: () => _review(_entries[i]['id'], 'APPROVED'),
                            onReject: () => _review(_entries[i]['id'], 'REJECTED'),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool busy, showActions;
  final VoidCallback onApprove, onReject;
  const _EntryCard({
    required this.entry,
    required this.busy,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final teamA = entry['team_a_name'] ?? 'Team A';
    final teamB = entry['team_b_name'] ?? 'Team B';
    final scoreA = entry['team_a_score'] ?? '-';
    final scoreB = entry['team_b_score'] ?? '-';
    final by = entry['submitted_by_name'] ?? 'Club member';
    final notes = entry['notes'] as String?;
    final status = (entry['status'] ?? 'PENDING') as String;
    DateTime? created;
    try { created = DateTime.parse(entry['created_at']).toLocal(); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$teamA  vs  $teamB',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.cText)),
              ),
              if (!showActions) _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$scoreA',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(':', style: TextStyle(fontSize: 20, color: Colors.grey)),
              ),
              Text('$scoreB',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: context.cTextSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 13, color: context.cTextSecondary),
              const SizedBox(width: 4),
              Text(by, style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
              const Spacer(),
              if (created != null)
                Text(DateFormat('d MMM, h:mm a').format(created),
                    style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = status == 'APPROVED' ? AppColors.success : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _Empty extends StatelessWidget {
  final String filter;
  const _Empty({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(filter == 'PENDING' ? '✅' : '📭', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          Text(
            filter == 'PENDING' ? 'No pending approvals' : 'Nothing here',
            style: TextStyle(fontSize: 15, color: context.cTextSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
