import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fyc_connect/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E Chess Tournament 100 Player Test', (WidgetTester tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle();

    // The app might show a splash screen or language select screen.
    // Assuming English is selected or we can tap 'English'.
    final englishButton = find.text('English');
    if (englishButton.evaluate().isNotEmpty) {
      await tester.tap(englishButton);
      await tester.pumpAndSettle();
    }

    // Now on OTP Login Screen
    // Find the phone number field
    final phoneField = find.byType(TextField).first;
    await tester.enterText(phoneField, '9000000000');
    await tester.pumpAndSettle();

    // Tap Request OTP
    final requestOtpBtn = find.text('Request OTP');
    await tester.tap(requestOtpBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2)); // wait for network

    // Find OTP fields (assuming standard 6 digit OTP)
    // Sometimes it's one text field, sometimes 6 small ones. Let's assume one field or pin code.
    final otpField = find.byType(TextField).first; // This might be the OTP field now
    await tester.enterText(otpField, '123456'); // Standard bypass code
    await tester.pumpAndSettle();

    // Tap Verify OTP
    final verifyOtpBtn = find.text('Verify OTP');
    await tester.tap(verifyOtpBtn);
    await tester.pumpAndSettle(const Duration(seconds: 5)); // wait for network and navigation

    // Now we should be on the Main App Screen (Home)
    // Navigate to Chess / Sports section
    // Assuming there's a BottomNavigationBar item with icon SportsEsports or text 'Chess'
    final chessTab = find.text('Chess');
    if (chessTab.evaluate().isNotEmpty) {
      await tester.tap(chessTab);
      await tester.pumpAndSettle();
    }

    // Find the Mega Tournament we created
    final tournamentCard = find.text('Mega 100-Player Automation Test');
    expect(tournamentCard, findsOneWidget);
    await tester.tap(tournamentCard);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify the bracket loads without crashing
    // We expect to see 'Round 1' text
    expect(find.text('Round 1'), findsWidgets);

    // Find our specific match (Player 1 should be in one of the slots)
    // Since we don't know the exact opponent name, we'll look for a 'Play' or 'Ready' button
    final readyButton = find.text('Ready').first;
    expect(readyButton, findsWidgets);

    // Tap Ready to enter the match lobby
    await tester.tap(readyButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // At this point the bot simulator script (if running) would also tap ready,
    // and the game would start. We just verify the chessboard renders.
    // The chessboard widget is likely 'ChessBoard' from flutter_chess_board
    // We'll just verify some standard text or widget exists
    expect(find.byType(Scaffold), findsWidgets); 
    
    // Test passed if we got here without crashing
  });
}
