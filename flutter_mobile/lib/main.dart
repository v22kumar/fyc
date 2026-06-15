import 'package:flutter/material';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const FYCConnectApp());
}

class FYCConnectApp extends StatelessWidget {
  const FYCConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FYC Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF064E3B), // Forest Green
          primary: const Color(0xFF064E3B),
          secondary: const Color(0xFF991B1B), // Crimson Red
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
        cardTheme: CardTheme(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
