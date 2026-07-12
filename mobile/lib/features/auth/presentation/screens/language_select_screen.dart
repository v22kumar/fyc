import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/patterns/kolam_background.dart';
import '../../../../service_locator.dart';
import '../../../../main.dart';

// (code, letter, bgColor, letterColor, title, subtitle)
const _kLangs = [
  ('ta', 'அ', Color(0xFFDCFCE7), Color(0xFF0F5132), 'தமிழ்', 'Tamil'),
  ('en', 'A',  Color(0xFFDBEAFE), Color(0xFF2563EB), 'English', 'English'),
  ('hi', 'अ',  Color(0xFFFEE2E2), Color(0xFFDC2626), 'हिन्दी', 'Hindi'),
  ('ml', 'അ',  Color(0xFFEDE9FE), Color(0xFF7C3AED), 'മലയാളം', 'Malayalam'),
];

// Keyed on _selectedLang (the language being previewed, not yet saved) so the
// identity copy live-updates as the user taps each language card — tr() would
// read the last-saved language from storage instead, not this screen's local
// selection, so it can't be used here.
const _kAppSubtitle = {
  'ta': 'நாகர்கோவில் Friends Youth Club-இன் அதிகாரப்பூர்வ செயலி — நிகழ்வுகள், விளையாட்டு, தன்னார்வலர் பணி, இரத்த தானம் & பாதுகாப்பு',
  'en': 'The official app for Friends Youth Club Nagercoil — events, sports, volunteering, blood donation & safety, all in one place',
  'hi': 'नागरकोइल Friends Youth Club की आधिकारिक ऐप — कार्यक्रम, खेल, स्वयंसेवा, रक्तदान और सुरक्षा',
  'ml': 'നാഗർകോവിൽ Friends Youth Club-ന്റെ ഔദ്യോഗിക ആപ്പ് — പരിപാടികൾ, കായികം, വൊളന്റിയർ, രക്തദാനം മാത്രമല്ല സുരക്ഷ',
};

const _kWhatIsThis = {
  'ta': 'இது என்ன செயலி?',
  'en': 'What is this app?',
  'hi': 'यह ऐप किस लिए है?',
  'ml': 'ഇതെന്ത് ആപ്പാണ്?',
};

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen>
    with TickerProviderStateMixin {
  String _selectedLang = 'ta';
  late AnimationController _aurora;
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _aurora.dispose();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    await sl<LocalStorage>().saveLang(_selectedLang);
    localeNotifier.value = Locale(_selectedLang);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _selectedLang == 'ta';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Aurora blobs
          AnimatedBuilder(
            animation: _aurora,
            builder: (_, __) {
              final t = _aurora.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    left: -80.0 + 70 * math.sin(t * 0.52),
                    top: -80.0 + 60 * math.cos(t * 0.38),
                    child: _LangBlob(
                        size: 320,
                        color: const Color(0xFF0F5132).withOpacity(0.50)),
                  ),
                  Positioned(
                    right: -60.0 + 80 * math.sin(t * 0.30 + 1.3),
                    bottom: 80.0 + 70 * math.cos(t * 0.44 + 0.7),
                    child: _LangBlob(
                        size: 260,
                        color: const Color(0xFF16A34A).withOpacity(0.28)),
                  ),
                  Positioned(
                    left: 50.0 + 50 * math.sin(t * 0.65 + 2.1),
                    bottom: -40.0 + 80 * math.cos(t * 0.42 + 1.6),
                    child: _LangBlob(
                        size: 200,
                        color: const Color(0xFFD4AF37).withOpacity(0.07)),
                  ),
                ],
              );
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(color: Colors.transparent),
          ),
          // Kolam texture over the aurora, under the content (MD3 redesign §3.4).
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: KolamPattern(color: Colors.white.withOpacity(0.04)),
              ),
            ),
          ),

          // Content
          FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.40),
                            blurRadius: 28,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/fyc_mark.png',
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) =>
                            const Text('🌱', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'FYC Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kAppSubtitle[_selectedLang] ?? _kAppSubtitle['en']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => context.push('/about'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _kWhatIsThis[_selectedLang] ?? _kWhatIsThis['en']!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isTa ? 'மொழியை தேர்ந்தெடுக்கவும்' : 'Select your language',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Language cards
                    for (final lang in _kLangs) ...[
                      _LangCard(
                        letter: lang.$2,
                        bgColor: lang.$3,
                        letterColor: lang.$4,
                        title: lang.$5,
                        subtitle: lang.$6,
                        isSelected: _selectedLang == lang.$1,
                        onTap: () => setState(() => _selectedLang = lang.$1),
                      ),
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 28),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _proceed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusBtn),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _selectedLang == 'ta'
                              ? 'தொடரவும்'
                              : _selectedLang == 'ml'
                                  ? 'തുടരുക'
                                  : _selectedLang == 'hi'
                                      ? 'जारी रखें'
                                      : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String letter;
  final Color bgColor;
  final Color letterColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangCard({
    required this.letter,
    required this.bgColor,
    required this.letterColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.92)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withOpacity(0.20),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: letterColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.primary : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.textSecondary
                        : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _LangBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _LangBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
