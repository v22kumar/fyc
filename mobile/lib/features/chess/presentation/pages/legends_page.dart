import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LegendEntry {
  final String emoji;
  final String name;
  final String nameTa;
  final String title;
  final String years;
  final String factEn;
  final String factTa;
  final Color accent;

  const LegendEntry({
    required this.emoji,
    required this.name,
    required this.nameTa,
    required this.title,
    required this.years,
    required this.factEn,
    required this.factTa,
    required this.accent,
  });
}

const _legends = [
  LegendEntry(
    emoji: '♛',
    name: 'Viswanathan Anand',
    nameTa: 'விஸ்வநாதன் ஆனந்த்',
    title: 'World Champion 2000–2016',
    years: 'b. 1969, Tamil Nadu',
    factEn:
        '"Vishy" dominated world chess for two decades, becoming the first Asian World Chess Champion. Known for his lightning-fast intuition, he won the championship 5 times.',
    factTa:
        'இருபது ஆண்டுகள் உலக சதுரங்கத்தை வென்ற ஆசியாவின் முதல் உலக சாம்பியன். ஐந்து முறை உலக சாம்பியன் பட்டம் பெற்றார்.',
    accent: Color(0xFFFFD700),
  ),
  LegendEntry(
    emoji: '♟',
    name: 'Magnus Carlsen',
    nameTa: 'மேக்னஸ் கார்ல்சன்',
    title: 'World Champion 2013–2023',
    years: 'b. 1990, Norway',
    factEn:
        'The highest-rated player in history (ELO 2882), Magnus became a Grandmaster at age 13. Known for endgame precision and near-perfect play.',
    factTa:
        'வரலாற்றிலேயே அதிக ELO மதிப்பீடு பெற்ற வீரர். 13 வயதில் கிராண்ட்மாஸ்டர் பட்டம் பெற்றார்.',
    accent: Color(0xFF60A5FA),
  ),
  LegendEntry(
    emoji: '♜',
    name: 'Garry Kasparov',
    nameTa: 'கேரி கஸ்பரோவ்',
    title: 'World Champion 1985–2000',
    years: 'b. 1963, Azerbaijan',
    factEn:
        'Widely considered the greatest player of all time. Kasparov held the world #1 ranking for 225 months and famously battled IBM\'s Deep Blue computer.',
    factTa:
        'சர்வகால சிறந்த வீரர் என்று போற்றப்படுபவர். IBM-இன் டீப் புளூவுடன் நடந்த போட்டி உலகின் கவனத்தை ஈர்த்தது.',
    accent: Color(0xFFEF4444),
  ),
  LegendEntry(
    emoji: '♝',
    name: 'Bobby Fischer',
    nameTa: 'பாபி பிஷர்',
    title: 'World Champion 1972–1975',
    years: 'b. 1943, USA',
    factEn:
        'An American prodigy who revolutionised chess preparation. His 1972 match against Boris Spassky during the Cold War was a cultural phenomenon watched by millions.',
    factTa:
        'சதுரங்க தயாரிப்பை மாற்றிய அமெரிக்க மேதை. 1972-இல் நடந்த போட்டி கோடிக்கணக்கான பார்வையாளர்களை ஈர்த்தது.',
    accent: Color(0xFF10B981),
  ),
  LegendEntry(
    emoji: '♞',
    name: 'Mikhail Tal',
    nameTa: 'மிகைல் தால்',
    title: 'World Champion 1960–1961',
    years: 'b. 1936, Latvia',
    factEn:
        '"The Magician from Riga" — famous for wild, sacrificial attacks that left opponents stunned. His tactical brilliance created some of the most beautiful games in history.',
    factTa:
        '"ரீகாவின் மந்திரவாதி" — அவரது ஆக்கிரமிப்பு நடை சதுரங்க உலகை மலைக்கச் செய்தது.',
    accent: Color(0xFFA855F7),
  ),
  LegendEntry(
    emoji: '♕',
    name: 'Judit Polgár',
    nameTa: 'ஜூடிட் பொல்கார்',
    title: 'Strongest Woman Player Ever',
    years: 'b. 1976, Hungary',
    factEn:
        'The only woman to break into the top 10 in world rankings. Became a Grandmaster at 15 — beating Fischer\'s record — and defeated every world champion of her era.',
    factTa:
        'உலக முதல் 10-இல் இடம் பிடித்த ஒரே பெண் வீரர். 15 வயதில் கிராண்ட்மாஸ்டர் பட்டம் பெற்று பிஷரின் சாதனையை முறியடித்தார்.',
    accent: Color(0xFFF59E0B),
  ),
];

class LegendsPage extends StatelessWidget {
  const LegendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chess Legends',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              'சதுரங்க மேதைகள்',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _legends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) => _LegendCard(legend: _legends[i]),
      ),
    );
  }
}

class _LegendCard extends StatefulWidget {
  final LegendEntry legend;
  const _LegendCard({required this.legend});

  @override
  State<_LegendCard> createState() => _LegendCardState();
}

class _LegendCardState extends State<_LegendCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.legend;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: l.accent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: l.accent.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: l.accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: l.accent.withOpacity(0.4), width: 1.5),
                      ),
                      child: Center(
                        child: Text(l.emoji,
                            style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            l.nameTa,
                            style: TextStyle(
                                color: l.accent.withOpacity(0.8),
                                fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.years,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),

              // Title badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: l.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.title,
                    style: TextStyle(
                      color: l.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Expandable facts
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 1,
                        color: l.accent.withOpacity(0.15),
                        margin: const EdgeInsets.only(bottom: 12),
                      ),
                      Text(
                        l.factEn,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l.factTa,
                        style: TextStyle(
                          color: l.accent.withOpacity(0.7),
                          fontSize: 12,
                          height: 1.55,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
