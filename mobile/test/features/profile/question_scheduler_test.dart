import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/features/profile/data/question_scheduler.dart';

/// The scheduling moved off the server and onto the phone, so the restraint
/// that made this feature bearable now lives here. These are mostly tests of
/// when NOT to ask: a version that asks too often is worse than not asking,
/// because it becomes the signup form we deliberately kept short.
void main() {
  const questions = [
    {'id': 'blood_group', 'prompt_id': 'q_blood_group', 'options': ['O+']},
    {'id': 'education', 'prompt_id': 'q_education', 'options': ['school']},
  ];

  late QuestionScheduler s;

  Future<QuestionScheduler> build() async {
    SharedPreferences.setMockInitialValues({});
    return QuestionScheduler(await SharedPreferences.getInstance());
  }

  Map<String, dynamic>? pick(QuestionScheduler s,
      {Set<String> answered = const {}, DateTime? now}) {
    return s.pick(
      questions: List<Map<String, dynamic>>.from(questions),
      answered: answered,
      quietDaysAfterResponse: 2,
      quietDaysAfterDismiss: 14,
      quietDaysAfterShown: 1,
      maxDismissals: 3,
      now: now,
    );
  }

  setUp(() async => s = await build());

  test('the highest-priority unanswered question is chosen', () async {
    expect(pick(s)?['id'], 'blood_group');
  });

  test('what the server says is answered is never asked', () async {
    expect(pick(s, answered: {'blood_group'})?['id'], 'education');
  });

  test('answering buys silence across every question, not just that one',
      () async {
    await s.markAnswered('blood_group');
    expect(pick(s), isNull);
  });

  test('being shown a card buys silence too', () async {
    // Otherwise ignoring the blood-group card simply produces the next
    // question, and two questions in one sitting is still two questions.
    await s.markShown();
    expect(pick(s), isNull);
  });

  test('the quiet period ends', () async {
    await s.markAnswered('blood_group');
    expect(pick(s, now: DateTime.now().add(const Duration(days: 3)))?['id'],
        'education');
  });

  test('a dismissed question goes to the back, not away', () async {
    await s.markDismissed('blood_group');
    final later = DateTime.now().add(const Duration(days: 3));
    expect(pick(s, now: later)?['id'], 'education');
    final muchLater = DateTime.now().add(const Duration(days: 20));
    expect(pick(s, now: muchLater)?['id'], 'blood_group');
  });

  test('three dismissals and we take the hint', () async {
    for (var i = 0; i < 3; i++) {
      await s.markDismissed('blood_group');
    }
    final muchLater = DateTime.now().add(const Duration(days: 60));
    expect(pick(s, now: muchLater)?['id'], 'education');
  });

  test('an answer given offline still silences the question', () async {
    // The upload can fail; the cadence must hold regardless, or a member with
    // no signal gets asked the same thing every time they open the app.
    await s.markAnswered('blood_group');
    final later = DateTime.now().add(const Duration(days: 5));
    expect(pick(s, now: later)?['id'], 'education');
  });

  test('nothing left to ask returns nothing', () async {
    expect(pick(s, answered: {'blood_group', 'education'}), isNull);
  });
}
