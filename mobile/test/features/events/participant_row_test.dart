import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/features/events/domain/entities/participant_row.dart';

/// What counts as the same child appearing twice.
///
/// The participant list showed "Anshika R · 12 years · Class 8" six times, and
/// the organiser had no way to spot repeats except by reading the whole list.
/// Now they are tinted red — which makes this rule worth being careful about in
/// both directions. Too loose and an organiser deletes a real child; too tight
/// and the repeats they are hunting stay invisible among the rest.
void main() {
  ParticipantRow anshika({String name = 'Anshika R', int? age = 12,
      String? grade = 'Class 8', String? id}) =>
      ParticipantRow(name: name, age: age, classGrade: grade, id: id);

  test('the same child entered twice is one fingerprint', () {
    expect(anshika().fingerprint, anshika().fingerprint);
  });

  test('a hurried second entry still matches', () {
    // How the duplicates actually got there: the same form filled again by
    // somebody typing quickly.
    expect(anshika(name: '  anshika   r ').fingerprint, anshika().fingerprint);
  });

  test('two children sharing a name are not duplicates', () {
    // At a village event this is ordinary, not a mistake. Flagging them red
    // would train the organiser to ignore the colour — and then the real
    // repeats hide in plain sight among the false ones.
    expect(anshika(age: 10, grade: 'Class 6').fingerprint,
        isNot(anshika().fingerprint));
  });

  test('same name and age, different class, is a different child', () {
    expect(anshika(grade: 'Class 7').fingerprint, isNot(anshika().fingerprint));
  });

  test('counting marks every copy, not just the later ones', () {
    // The organiser decides which to keep, so all of them are pointed at.
    final rows = [anshika(), anshika(), anshika(), anshika(age: 10, grade: 'Class 6')];
    final counts = ParticipantRow.countBy(rows);
    expect(counts[anshika().fingerprint], 3);
    expect(counts[anshika(age: 10, grade: 'Class 6').fingerprint], 1);
  });

  test('a single entry is never flagged', () {
    final counts = ParticipantRow.countBy([anshika()]);
    expect(counts[anshika().fingerprint], 1);
  });

  test('an id is present only when an organiser loaded the row', () {
    // The member-facing list carries no identifiers, deliberately — adding one
    // so the sheet could offer a delete would have undone that quietly.
    expect(anshika().id, isNull);
    expect(anshika(id: 'reg-1').id, 'reg-1');
  });

  test('a missing age does not collapse everybody into one duplicate', () {
    final a = ParticipantRow(name: 'Ravi', age: null, classGrade: null);
    final b = ParticipantRow(name: 'Meena', age: null, classGrade: null);
    expect(a.fingerprint, isNot(b.fingerprint));
  });
}
