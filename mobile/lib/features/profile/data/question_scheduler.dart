import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Decides, on the phone, whether to ask a question — and which.
///
/// The server used to decide, which meant a round trip on every app open to be
/// told "nothing today", because "nothing today" is the right answer almost
/// every time. That is a request per launch per member for no result.
///
/// It is also unnecessary. Whether to ask depends only on what this member has
/// answered, what they pushed away, and when they were last asked anything —
/// all of which the phone can hold. So the server publishes the catalogue and
/// the cadence, and this decides.
///
/// The rules, in the order they are applied:
/// 1. Responded to anything recently → silence, across every question. One
///    answer buys peace from all of them, not just the one answered.
/// 2. Shown anything recently → silence. Ignoring a card must not produce a
///    different card; two questions in one sitting is still two questions.
/// 3. Already answered, or already known → skip that question forever.
/// 4. Dismissed → skip for a fortnight; dismissed enough times → skip for good.
class QuestionScheduler {
  QuestionScheduler(this._prefs);

  final SharedPreferences _prefs;

  static const _kShown = 'qq_last_shown_at';
  static const _kResponded = 'qq_last_responded_at';
  static const _kDismissals = 'qq_dismissals';
  static const _kDismissedAt = 'qq_dismissed_at';
  static const _kAnswered = 'qq_answered';

  DateTime? _time(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Map<String, int> get _dismissals =>
      (jsonDecode(_prefs.getString(_kDismissals) ?? '{}') as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));

  Map<String, String> get _dismissedAt =>
      (jsonDecode(_prefs.getString(_kDismissedAt) ?? '{}') as Map)
          .map((k, v) => MapEntry(k as String, v as String));

  Set<String> get _answeredLocally =>
      (_prefs.getStringList(_kAnswered) ?? const <String>[]).toSet();

  /// The question to ask now, or null — which is the usual and correct answer.
  ///
  /// [questions] and [answered] come from the catalogue, already in priority
  /// order. [answered] is the server's view, which is what survives a reinstall.
  Map<String, dynamic>? pick({
    required List<Map<String, dynamic>> questions,
    required Set<String> answered,
    required int quietDaysAfterResponse,
    required int quietDaysAfterDismiss,
    required int quietDaysAfterShown,
    required int maxDismissals,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();

    bool within(DateTime? then, int days) =>
        then != null && at.difference(then) < Duration(days: days);

    if (within(_time(_kResponded), quietDaysAfterResponse)) return null;
    if (within(_time(_kShown), quietDaysAfterShown)) return null;

    // The server's list plus anything answered on this device since the last
    // catalogue fetch, so an answer given a moment ago is not re-asked.
    final done = {...answered, ..._answeredLocally};
    final dismissals = _dismissals;
    final dismissedAt = _dismissedAt;

    for (final q in questions) {
      final id = q['id'] as String?;
      if (id == null || done.contains(id)) continue;
      if ((dismissals[id] ?? 0) >= maxDismissals) continue;
      if (within(DateTime.tryParse(dismissedAt[id] ?? ''), quietDaysAfterDismiss)) {
        continue;
      }
      return q;
    }
    return null;
  }

  /// Call when a question is actually put in front of someone.
  Future<void> markShown() =>
      _prefs.setString(_kShown, DateTime.now().toIso8601String());

  Future<void> markAnswered(String id) async {
    await _prefs.setString(_kResponded, DateTime.now().toIso8601String());
    final answered = _answeredLocally..add(id);
    await _prefs.setStringList(_kAnswered, answered.toList());
  }

  Future<void> markDismissed(String id) async {
    final now = DateTime.now().toIso8601String();
    await _prefs.setString(_kResponded, now);
    await _prefs.setString(
        _kDismissedAt, jsonEncode({..._dismissedAt, id: now}));
    final counts = _dismissals;
    await _prefs.setString(
        _kDismissals, jsonEncode({...counts, id: (counts[id] ?? 0) + 1}));
  }
}
