import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/thirukkural_datasource.dart';
import '../../data/models/thirukkural_model.dart';

// Seed kurals shown instantly while the API loads (offline-first).
// Picked by day-of-year so the same kural shows all day.
const _seedKurals = [
  (
    number: 1,
    line1: 'அகர முதல எழுத்தெல்லாம் ஆதி',
    line2: 'பகவன் முதற்றே உலகு.',
    tamilMeaning:
        'அகரம் எழுத்துக்களுக்கு முதலாக உள்ளது போல ஆதிபகவன் உலகிற்கு முதலாக உள்ளான்.',
    englishCouplet:
        'A, as its first of letters, every speech maintains;\nThe "Primal Deity" is first through all the world\'s domains.',
    englishMeaning:
        'As the letter A is the first of all letters, so the eternal God is first in the world.',
    paalTa: 'அறத்துப்பால்',
    paalEn: 'Virtue',
  ),
  (
    number: 2,
    line1: 'கற்றதனால் ஆய பயனென்கொல் வாலறிவன்',
    line2: 'நற்றாள் தொழாஅர் எனின்.',
    tamilMeaning:
        'தூய அறிவுடையவனின் திருவடிகளை வணங்காதவர்கள் கற்றதனால் என்ன பயன் அடைவார்கள்?',
    englishCouplet:
        'What profit have those reaped from learning\'s lore,\nWho worship not the good God\'s foot, adored for evermore?',
    englishMeaning:
        'What benefit have those who learn derived from learning, if they worship not the good feet of the pure in knowledge?',
    paalTa: 'அறத்துப்பால்',
    paalEn: 'Virtue',
  ),
  (
    number: 391,
    line1: 'அன்பிலார் எல்லாம் தமக்குரியர் அன்புடையார்',
    line2: 'என்பும் உரியர் பிறர்க்கு.',
    tamilMeaning:
        'அன்பில்லாதவர்கள் எல்லாவற்றையும் தமக்காக வைத்திருப்பர்; அன்புள்ளவர்கள் தம் எலும்பும் பிறருக்கு உரியது என்பர்.',
    englishCouplet:
        'Men without love claim all things for their own;\nThe loving give their very bones for others\' good alone.',
    englishMeaning:
        'Those without love claim everything for themselves; those with love consider even their bones to belong to others.',
    paalTa: 'அறத்துப்பால்',
    paalEn: 'Virtue',
  ),
  (
    number: 423,
    line1: 'அழுக்காறு அவாவெகுளி இன்னாச்சொல் நான்கும்',
    line2: 'இழுக்கா இயன்றது அறம்.',
    tamilMeaning:
        'பொறாமை, ஆசை, சினம், கடுஞ்சொல் ஆகிய நான்கையும் விட்டு ஒழுகுவதே அறம்.',
    englishCouplet:
        'Virtue is free from envy, avarice, wrath, and bitter speech;\nConduct that avoids these four, true virtue\'s heights can reach.',
    englishMeaning:
        'That conduct is virtue which is free from envy, covetousness, anger, and bitter speech.',
    paalTa: 'அறத்துப்பால்',
    paalEn: 'Virtue',
  ),
  (
    number: 595,
    line1: 'இடிப்பாரை இல்லாத ஏமரா மன்னன்',
    line2: 'கெடுப்பார் இலானும் கெடும்.',
    tamilMeaning:
        'கண்டிப்பவர்கள் இல்லாத பாதுகாப்பற்ற மன்னன், அழிக்க எதிரிகள் இல்லாமலேயே தானாகவே அழிவான்.',
    englishCouplet:
        'The king who lacks men bold enough to chide his faults aright\nPerishes, though no enemy appears to blight.',
    englishMeaning:
        'A king without counselors who reprove him will perish even without enemies to destroy him.',
    paalTa: 'பொருட்பால்',
    paalEn: 'Wealth',
  ),
  (
    number: 11,
    line1: 'துப்பார்க்குத் துப்பாய துப்பாக்கித் துப்பார்க்குத்',
    line2: 'துப்பாய தூஉம் மழை.',
    tamilMeaning:
        'தின்பவர்க்கு உணவாகி, தின்னும் உணவை விளைவித்துத் தின்பவர்க்கே மழையும் தூவும்.',
    englishCouplet:
        'Rain makes the food that all who eat require;\nAnd rain itself is food, all creatures\' life-desire.',
    englishMeaning:
        'Rain creates the food that those who eat desire, and is itself the food that satisfies the eater.',
    paalTa: 'அறத்துப்பால்',
    paalEn: 'Virtue',
  ),
  (
    number: 702,
    line1: 'அறிவுடையார் ஆவதறிவார் அறிவிலார்',
    line2: 'அஃகும் சிறுமை நகும்.',
    tamilMeaning:
        'அறிவுடையவர்கள் நிகழப்போவதை அறிவார்கள்; அறிவில்லாதவர்கள் தங்கள் சிறுமையில் சிரிப்பார்கள்.',
    englishCouplet:
        'The wise foresee what is to come; the foolish laugh\nAt their own littleness — not knowing what they lack.',
    englishMeaning:
        'The wise know what is coming; the ignorant laugh at their own smallness without knowing it.',
    paalTa: 'பொருட்பால்',
    paalEn: 'Wealth',
  ),
];

ThirukkuralModel _seedForToday() {
  final idx = DateTime.now().dayOfYear % _seedKurals.length;
  final s = _seedKurals[idx];
  return ThirukkuralModel(
    number: s.number,
    line1: s.line1,
    line2: s.line2,
    tamilMeaning: s.tamilMeaning,
    englishCouplet: s.englishCouplet,
    englishMeaning: s.englishMeaning,
    adhikaram: 0,
    paalTa: s.paalTa,
    paalEn: s.paalEn,
  );
}

extension on DateTime {
  int get dayOfYear {
    return difference(DateTime(year)).inDays;
  }
}

class DailyThirukkuralCard extends StatefulWidget {
  const DailyThirukkuralCard({super.key});

  @override
  State<DailyThirukkuralCard> createState() => _DailyThirukkuralCardState();
}

class _DailyThirukkuralCardState extends State<DailyThirukkuralCard> {
  // Start with seed data immediately so there's no blank state.
  ThirukkuralModel _kural = _seedForToday();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchLive();
  }

  Future<void> _fetchLive() async {
    try {
      final live = await sl<ThirukkuralDataSource>()
          .fetchDaily()
          .timeout(const Duration(seconds: 12));
      if (mounted) setState(() { _kural = live; _loaded = true; });
    } catch (_) {
      // Keep showing the seed kural — no visible error needed.
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ThirukkuralContent(kural: _kural, isLive: _loaded);
  }
}

class _ThirukkuralContent extends StatelessWidget {
  final ThirukkuralModel kural;
  final bool isLive;
  const _ThirukkuralContent({required this.kural, this.isLive = true});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D3D26), Color(0xFF145C36), Color(0xFF1A7A47)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative background pattern
            Positioned(
              right: -20,
              top: -20,
              child: CustomPaint(
                size: const Size(160, 160),
                painter: _KuralBgPainter(),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: CustomPaint(
                size: const Size(120, 120),
                painter: _KuralBgPainter(opacity: 0.06),
              ),
            ),
            // Large decorative quote mark
            Positioned(
              left: 12,
              top: 12,
              child: Text('"',
                  style: TextStyle(
                    fontSize: 90,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.07),
                    fontFamily: 'serif',
                  )),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('📜', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'இன்றைய திருக்குறள்',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              'Thirukkural of the Day',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.30)),
                        ),
                        child: Text(
                          'குறள் #${kural.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Tamil couplet
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kural.line1,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.6,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          kural.line2,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.6,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tamil meaning
                  Text(
                    kural.tamilMeaning,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: Colors.white.withOpacity(0.80),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Divider(height: 1, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 14),

                  // English couplet
                  Text(
                    '"${kural.englishCouplet}"',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.90),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kural.englishMeaning,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Footer
                  Row(
                    children: [
                      Icon(Icons.menu_book_outlined, size: 13, color: Colors.white.withOpacity(0.55)),
                      const SizedBox(width: 6),
                      Text(
                        '${kural.paalTa}  •  ${kural.paalEn}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                      if (!isLive) ...[
                        const Spacer(),
                        Icon(Icons.cloud_off_rounded, size: 12, color: Colors.white.withOpacity(0.35)),
                        const SizedBox(width: 4),
                        Text(
                          'offline',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.35)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KuralBgPainter extends CustomPainter {
  final double opacity;
  const _KuralBgPainter({this.opacity = 0.09});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final cx = size.width / 2, cy = size.height / 2;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(cx, cy), (i + 1) * size.width / 6, paint);
    }
    final dotPaint = Paint()..color = Colors.white.withOpacity(opacity * 1.5);
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * size.width * 0.42,
               cy + math.sin(angle) * size.height * 0.42),
        2.5, dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
