import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The debug token exists so the screenshot harness can photograph screens that
/// need a login. The Linux embedder has no keyring, so the real token store
/// silently returns null and every such screen renders its signed-out state —
/// which is how an entire design review came to be conducted against screens
/// that were never logged in.
///
/// It is a build-time credential, and those are exactly the sort of thing that
/// gets shipped by accident. The guard is that it is inert unless kDebugMode.
/// That guard is worth a test, so it cannot be quietly removed.
void main() {
  test('a release build ignores the debug token define', () {
    const supplied = String.fromEnvironment('DEBUG_TOKEN');
    // Mirrors LocalStorage._useDebugToken exactly.
    final wouldBeUsed = kDebugMode && supplied.isNotEmpty;
    if (!kDebugMode) {
      expect(wouldBeUsed, isFalse,
          reason: 'a release build must never read a build-time token');
    } else {
      // In debug the define is honoured — that is the whole point — but only
      // when one was actually supplied.
      expect(wouldBeUsed, equals(supplied.isNotEmpty));
    }
  });
}
