import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class _Value {
  final String emoji;
  final String ta;
  final String en;
  const _Value(this.emoji, this.ta, this.en);
}

class _Milestone {
  final String year;
  final String ta;
  final String en;
  const _Milestone(this.year, this.ta, this.en);
}

const List<_Value> _values = [
  _Value('🤝', 'சமூக ஒற்றுமை', 'Community Unity'),
  _Value('🔍', 'வெளிப்படையான நிர்வாகம்', 'Transparent Administration'),
  _Value('🌿', 'சுற்றுச்சூழல் அக்கறை', 'Environmental Responsibility'),
  _Value('💪', 'இளைஞர் சக்தி', 'Youth Empowerment'),
  _Value('❤️', 'மனித அன்பு', 'Human Compassion'),
  _Value('📚', 'கல்வி உதவி', 'Educational Support'),
];

const List<_Milestone> _milestones = [
  _Milestone('1998', 'நாகர்கோவிலில் FYC இயக்கம் தொடங்கியது',
      'FYC movement started in Nagercoil'),
  _Milestone('2000', 'அதிகாரப்பூர்வ பதிவு பெறப்பட்டது',
      'Officially registered as Friends Youth Club'),
  _Milestone('2005', '100வது சமூக நிகழ்வு கொண்டாடப்பட்டது',
      'Celebrated 100th community event'),
  _Milestone('2010', '500+ இரத்த தான முகாம்கள்',
      '500+ blood donation camps organized'),
  _Milestone('2015', '1000+ மரங்கள் நடப்பட்டன', '1000+ trees planted'),
  _Milestone('2020', 'COVID நேர அவசர உதவி', 'Emergency relief during COVID-19'),
  _Milestone('2026', 'FYC Connect டிஜிட்டல் தளம்',
      'FYC Connect digital platform launched'),
];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  String get _lang => sl<LocalStorage>().getLang();

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'ta' ? 'எங்களை பற்றி' : 'About FYC'),
      ),
      body: ListView(
        children: [
          _Hero(lang: lang),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingPage),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(lang == 'ta' ? 'எங்கள் நோக்கம்' : 'Our Mission'),
                const SizedBox(height: 10),
                Text(
                  lang == 'ta'
                      ? 'நாகர்கோவிலை மையமாகக் கொண்ட Friends Youth Club, இளைஞர்களின் '
                          'சக்தியால் சமூகத்தை வலுப்படுத்தி, இரத்த தானம், சுற்றுச்சூழல் '
                          'பாதுகாப்பு, கல்வி உதவி மற்றும் அவசர நேர சேவைகள் மூலம் '
                          'அனைவருக்கும் கண்ணியமான வாழ்வை உருவாக்க உழைக்கிறது.'
                      : 'Based in Nagercoil, Friends Youth Club harnesses the energy '
                          'of young people to strengthen our community. Through blood '
                          'donation, environmental care, educational support and '
                          'emergency relief, we work to build a dignified life for all.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle(lang == 'ta' ? 'எங்கள் மதிப்புகள்' : 'Our Values'),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: _values
                      .map((v) => _ValueCard(value: v, lang: lang))
                      .toList(),
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                    lang == 'ta' ? 'எங்கள் பயணம்' : 'Our Journey'),
                const SizedBox(height: 14),
                ..._milestones.asMap().entries.map(
                      (e) => _TimelineTile(
                        milestone: e.value,
                        lang: lang,
                        isLast: e.key == _milestones.length - 1,
                      ),
                    ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String lang;
  const _Hero({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text('🎗️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            lang == 'ta' ? 'எங்களை பற்றி' : 'About FYC',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lang == 'ta'
                ? 'Friends Youth Club · நாகர்கோவில்'
                : 'Friends Youth Club · Nagercoil',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final _Value value;
  final String lang;
  const _ValueCard({required this.value, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(
            lang == 'ta' ? value.ta : value.en,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _Milestone milestone;
  final String lang;
  final bool isLast;

  const _TimelineTile({
    required this.milestone,
    required this.lang,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  milestone.year,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 2),
              child: Text(
                lang == 'ta' ? milestone.ta : milestone.en,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
