import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/civic_api.dart';
import 'ladder_view.dart';

/// One complaint, the ladder it is on, and the two buttons that move it.
///
/// The reviewer's whole job on one sheet: see where it would go, decide whether
/// it should, and press send. Approving and sending are deliberately two
/// separate actions rather than one — approval opens the door, and the letter is
/// visible before it leaves. The club's name is on it.
class ReviewSheet extends StatefulWidget {
  final String issueId;
  const ReviewSheet({super.key, required this.issueId});

  static Future<void> open(BuildContext context, {required String issueId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSheet(issueId: issueId),
    );
  }

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  Map<String, dynamic>? _route;
  Map<String, dynamic>? _issue;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Both at once: the ladder to show, and the status that decides which
      // button belongs at the bottom of it.
      final results = await Future.wait([
        CivicApi.route(widget.issueId),
        CivicApi.issue(widget.issueId),
      ]);
      if (!mounted) return;
      setState(() {
        _route = results[0];
        _issue = results[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _rungs =>
      ((_route?['rungs'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Map<String, dynamic>? get _nextReachable {
    for (final r in _rungs) {
      if (r['reachable'] == true) return r;
    }
    return null;
  }

  /// How an office is named on the button that sends to it.
  ///
  /// Tamil when the app is in Tamil — the API returns both spellings and using
  /// only the English one put "Send to Sanitary Inspector" in the middle of an
  /// otherwise Tamil screen.
  String _officeOf(Map<String, dynamic> rung) {
    String lang;
    try {
      lang = trLang();
    } catch (_) {
      lang = 'en';
    }
    String? pick(String? ta, String? en) {
      final preferred = lang == 'ta' ? ta : en;
      return (preferred == null || preferred.isEmpty) ? (en ?? ta) : preferred;
    }

    final designation = pick(
      rung['designation_ta'] as String?,
      rung['designation_en'] as String?,
    );
    final department = pick(
          rung['department_name_ta'] as String?,
          rung['department_name_en'] as String?,
        ) ??
        '';
    return designation == null ? department : '$designation, $department';
  }

  Future<void> _act(Future<void> Function() action, {String? toast}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (toast != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trId('action_failed_try_again')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  /// Rejecting asks for a reason and will not proceed without one.
  ///
  /// The backend refuses a blank reason too — this is the same rule said twice,
  /// on purpose, so the person rejecting is asked politely rather than shown an
  /// error after the fact. The reporter reads what is typed here.
  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(trId('review_reject')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: trId('review_reject_why')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(trId('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(trId('review_reject')),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _act(() => CivicApi.review(widget.issueId, approve: false, reason: reason));
  }

  /// Where this complaint thinks it is, said in the reviewer's language.
  ///
  /// The server also sends `jurisdiction_reason`, which is English prose it
  /// assembled — useful in a log, untranslatable on a screen. It sends the
  /// place name and the confidence separately for exactly this reason, and the
  /// sentence is built here.
  String _jurisdictionLine() {
    final place = _route?['jurisdiction_place'] as String?;
    final confidence = _route?['jurisdiction_confidence'] as String? ?? 'GUESSED';
    final body = switch (_route?['local_body_type'] as String?) {
      'CORPORATION' => trId('body_corporation'),
      'MUNICIPALITY' => trId('body_municipality'),
      'TOWN_PANCHAYAT' => trId('body_town_panchayat'),
      'VILLAGE_PANCHAYAT' => trId('body_village_panchayat'),
      _ => '',
    };
    // Confidence is the authority, not whether a name came back. Treating a
    // missing place name as a guess labelled complaints from properly recorded
    // wards as assumptions — the opposite of what this line is for, and it
    // would have sent a reviewer looking for a problem that was not there.
    if (confidence == 'GUESSED') return '${trId('juris_guessed')} · $body';
    if (place == null || place.isEmpty) return body;

    final line = confidence == 'DECLARED'
        ? trId('juris_area_is', {'place': place})
        : trId('juris_inherited', {'place': place});
    return '$line · $body';
  }

  /// The one button that moves this complaint forward from where it is.
  ///
  /// Approving and sending are separate steps on purpose — approval opens the
  /// door, and the letter is read before it leaves. So the sheet offers exactly
  /// one of them at a time rather than a row of buttons, most of which would be
  /// wrong for the complaint in front of you.
  Widget _primaryAction(Map<String, dynamic>? next) {
    final status = _issue?['status'] as String? ?? 'NEW';

    if (status == 'NEW') {
      return FilledButton(
        key: const ValueKey('review-approve'),
        onPressed: _busy
            ? null
            : () => _act(() => CivicApi.review(widget.issueId, approve: true)),
        // FittedBox because "Approve" is one short word in English and
        // considerably longer in every other language this app speaks.
        child: FittedBox(child: Text(trId('review_approve'))),
      );
    }

    // Approved but nowhere to send it: the club has not recorded an address for
    // any office on this route yet. Disabled rather than hidden, so the reason
    // shown above it still makes sense.
    if (next == null) {
      return FilledButton(
        onPressed: null,
        child: FittedBox(child: Text(trId('review_could_not_send'))),
      );
    }

    final office = _officeOf(next);
    // The first letter and an escalation are the same action at different
    // heights — the label is what tells the reviewer which one this is.
    final label = status == 'ASSIGNED'
        ? trId('review_send_to', {'office': office})
        : trId('review_escalate_to', {'office': office});

    return FilledButton(
      key: const ValueKey('review-send'),
      onPressed: _busy
          ? null
          : () => _act(
                () => CivicApi.dispatch(widget.issueId),
                toast: trId('review_sent', {'office': office}),
              ),
      child: FittedBox(child: Text(label)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextReachable;
    final needsCheck = _route?['needs_human_check'] == true;
    final helpline = _route?['fallback_helpline'] as String?;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.cBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                      children: [
                        Text(trId('review_where_it_goes'),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.cText)),
                        const SizedBox(height: 4),
                        // Where the jurisdiction came from, in the reviewer's
                        // own language. A guess is labelled a guess — this is
                        // the moment a human is meant to correct one.
                        Text(_jurisdictionLine(),
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: context.cTextSecondary)),
                        if (needsCheck) ...[
                          const SizedBox(height: 10),
                          _Warning(text: trId('review_check_the_area')),
                        ],
                        if (next == null) ...[
                          const SizedBox(height: 10),
                          _Warning(text: trId('review_no_office_yet')),
                          if (helpline != null && helpline.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(trId('review_ring_instead', {'helpline': helpline}),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ],
                        ],
                        const SizedBox(height: 16),
                        LadderView(rungs: _rungs),
                      ],
                    ),
                  ),
                  SafeArea(
                    minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _reject,
                            child: FittedBox(child: Text(trId('review_reject'))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _primaryAction(next)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String text;
  const _Warning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12.5, height: 1.3, color: context.cText)),
          ),
        ],
      ),
    );
  }
}
