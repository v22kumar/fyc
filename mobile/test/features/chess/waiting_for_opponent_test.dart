import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/l10n/tr.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/service_locator.dart';
import 'package:fyc_connect/features/chess/presentation/bloc/online_game_state.dart';

/// "You're ready — waiting for {name}".
///
/// The string takes a name and the waiting screen passed none, so a member sat
/// in front of the placeholder itself while the app waited for their opponent
/// to arrive. The server never sent a name either — the 'waiting' message
/// carried only a colour — so there was nothing to pass.
///
/// These hold both halves down: the state carries the name, and neither branch
/// of the text can leave a hole in the sentence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
  });

  test('the waiting state carries who we are waiting for', () {
    const state = OnlineGameWaiting(myColor: 'black', opponentName: 'Arun');
    expect(state.opponentName, 'Arun');
  });

  test('no name is not the same as an empty name', () {
    // Older payloads, and the moment before the server knows, both arrive
    // without one. That has to be a different sentence, not a truncated one.
    const state = OnlineGameWaiting(myColor: 'white');
    expect(state.opponentName, isEmpty);
  });

  testWidgets('neither sentence ever shows a placeholder or trails off',
      (tester) async {
    for (final name in ['Arun', '']) {
      final text = name.isEmpty
          ? trId('you_re_ready_waiting_for_your_opponent')
          : trId('waiting_for_opponent', {'name': name});

      expect(text.contains('{'), isFalse,
          reason: 'a member was shown the placeholder itself: $text');
      expect(text.trim().endsWith('for'), isFalse,
          reason: 'an empty name left the sentence hanging: $text');
      if (name.isNotEmpty) {
        expect(text.contains(name), isTrue,
            reason: 'the opponent is named, so name them: $text');
      }
    }

    // And the widget the page builds from it renders without overflowing.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(trId('waiting_for_opponent', {'name': 'Sushmita Telasang'})),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
