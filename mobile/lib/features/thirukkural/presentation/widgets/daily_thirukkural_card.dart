import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/thirukkural_datasource.dart';
import '../../data/models/thirukkural_model.dart';

class DailyThirukkuralCard extends StatefulWidget {
  const DailyThirukkuralCard({super.key});

  @override
  State<DailyThirukkuralCard> createState() => _DailyThirukkuralCardState();
}

class _DailyThirukkuralCardState extends State<DailyThirukkuralCard> {
  late Future<ThirukkuralModel> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ThirukkuralDataSource>().fetchDaily();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThirukkuralModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ThirukkuralSkeleton();
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        return _ThirukkuralContent(kural: snapshot.data!);
      },
    );
  }
}

class _ThirukkuralContent extends StatelessWidget {
  final ThirukkuralModel kural;
  const _ThirukkuralContent({required this.kural});

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

                  // Tamil couplet — the star of the show
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
    // Decorative dots
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

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;
  const _SkeletonBox({this.width, required this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: radius ?? BorderRadius.circular(8),
      ),
    );
  }
}

class _ThirukkuralSkeleton extends StatelessWidget {
  const _ThirukkuralSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D3D26), Color(0xFF145C36)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SkeletonBox(width: 36, height: 36, radius: BorderRadius.circular(10)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(height: 13, width: 160),
                      SizedBox(height: 6),
                      _SkeletonBox(height: 10, width: 120),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SkeletonBox(height: 60, radius: BorderRadius.circular(12)),
            const SizedBox(height: 12),
            const _SkeletonBox(height: 12),
            const SizedBox(height: 6),
            const _SkeletonBox(height: 12, width: 240),
          ],
        ),
      ),
    );
  }
}
