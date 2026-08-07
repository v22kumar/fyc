import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/civic_api.dart';
import '../../domain/civic_categories.dart';
import '../widgets/review_sheet.dart';

/// The club's side of the workflow — and, until now, the missing half of it.
///
/// A citizen could report something and the report would sit there, because
/// nothing reaches a government office without a member of the club reading it
/// first and there was no screen on which to read it. The complaint stopped at
/// the club rather than passing through it.
///
/// A queue, not a list. The old issues screen showed every report in one stream
/// ordered by date, which answers no question a reviewer actually has. The three
/// buckets here answer the only one that matters: **whose move is it?**
///
/// * waiting on us — nobody has approved or rejected it yet
/// * waiting on them — a letter is out and an officer owes an answer
/// * overdue — that officer's time has run out, and the club is being asked
///   whether to climb a rung. Asked, not told: the clock never sends anything.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  Map<String, dynamic>? _queue;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await CivicApi.queue();
      if (!mounted) return;
      setState(() {
        _queue = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = trId('action_failed_try_again');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _bucket(String key) =>
      ((_queue?[key] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  Widget build(BuildContext context) {
    // Overdue first. It is the bucket with a deadline attached, and burying it
    // under two others is how a complaint quietly ages out.
    final sections = [
      ('overdue', trId('queue_overdue'), AppColors.accent),
      ('waiting_on_us', trId('queue_waiting_on_us'), AppColors.primary),
      ('waiting_on_them', trId('queue_waiting_on_them'), context.cTextSecondary),
    ];

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: Text(trId('queue_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(color: context.cTextSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      for (final (key, label, colour) in sections) ...[
                        _Heading(label: label, count: _bucket(key).length, colour: colour),
                        const SizedBox(height: 8),
                        if (_bucket(key).isEmpty)
                          _Empty()
                        else
                          for (final item in _bucket(key))
                            _QueueCard(
                              item: item,
                              accent: colour,
                              onDone: _load,
                            ),
                        const SizedBox(height: 22),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String label;
  final int count;
  final Color colour;
  const _Heading({required this.label, required this.count, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle)),
        const SizedBox(width: 9),
        // Flexible so a long bucket name in Malayalam does not push the count
        // off the row.
        Flexible(
          child: Text(label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: context.cText)),
        ),
        const SizedBox(width: 8),
        Text('$count',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: colour)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(trId('queue_nothing_here'),
          style: TextStyle(fontSize: 13, color: context.cTextSecondary)),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color accent;
  final VoidCallback onDone;
  const _QueueCard({required this.item, required this.accent, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final overdueDays = item['days_overdue'] as int?;
    final position = item['current_position'] as int?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('queue-${item['id']}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await ReviewSheet.open(context, issueId: item['id'] as String);
            onDone();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.cBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['description'] as String?)?.trim().isNotEmpty == true
                      ? item['description'] as String
                      : CivicCategory.label(item['category'] as String?),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600, color: context.cText),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Chip(
                      text: CivicCategory.label(item['category'] as String?),
                      colour: context.cTextSecondary,
                    ),
                    if (position != null && position > 0)
                      _Chip(text: trId('queue_rung', {'n': position}), colour: context.cTextSecondary),
                    if (overdueDays != null)
                      _Chip(
                        text: trId('queue_days_overdue', {'n': overdueDays}),
                        colour: AppColors.accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color colour;
  const _Chip({required this.text, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colour)),
    );
  }
}
