/// One row of an event's participant list, and the rule for what counts as the
/// same child appearing twice.
///
/// Extracted from the sheet because "is this a duplicate?" is a judgement about
/// the club's data, not about a widget — and because a rule nobody can test is
/// a rule nobody can trust. Getting it wrong is expensive in both directions:
/// too loose and the organiser deletes a real child, too tight and the repeats
/// they are hunting stay invisible.
class ParticipantRow {
  const ParticipantRow({
    required this.name,
    this.id,
    this.age,
    this.classGrade,
  });

  /// Present only when an organiser is looking.
  ///
  /// The member-facing list is deliberately names, ages and classes with no
  /// identifiers — a privacy decision. Putting an id on it so the sheet could
  /// offer a delete would have quietly undone that, so organisers load the full
  /// record they already have permission to see, and everybody else does not.
  final String? id;

  final String name;
  final int? age;
  final String? classGrade;

  /// Two rows are the same child when name, age and class all match.
  ///
  /// **Name alone is not enough.** At a village event two children sharing a
  /// name is ordinary, not a mistake, and flagging them red would train the
  /// organiser to ignore the colour — at which point the real repeats hide in
  /// plain sight among the false ones.
  ///
  /// Case and spacing are normalised, because "Anshika R" and "anshika  r" are
  /// the same child typed twice by someone in a hurry, which is exactly how the
  /// duplicates got there.
  String get fingerprint {
    final tidied = name.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');
    return '$tidied|$age|${(classGrade ?? '').toLowerCase().trim()}';
  }

  /// How many times each row's fingerprint occurs in [rows].
  static Map<String, int> countBy(Iterable<ParticipantRow> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.fingerprint] = (counts[row.fingerprint] ?? 0) + 1;
    }
    return counts;
  }
}
