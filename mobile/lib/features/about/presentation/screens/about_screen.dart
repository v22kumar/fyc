import 'package:flutter/material.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class _Value {
  final String emoji;
  final String ta;
  final String en;
  final String hi;
  final String ml;
  const _Value(this.emoji, this.ta, this.en, this.hi, this.ml);
}

class _Milestone {
  final String year;
  final String ta;
  final String en;
  final String hi;
  final String ml;
  const _Milestone(this.year, this.ta, this.en, this.hi, this.ml);
}

const List<_Value> _values = [
  _Value('🤝', 'சமூக ஒற்றுமை', 'Community Unity', 'सामुदायिक एकता',
      'സാമൂഹിക ഐക്യം'),
  _Value('🔍', 'வெளிப்படையான நிர்வாகம்', 'Transparent Administration',
      'पारदर्शी प्रशासन', 'സുതാര്യമായ ഭരണം'),
  _Value('🌿', 'சுற்றுச்சூழல் அக்கறை', 'Environmental Responsibility',
      'पर्यावरण उत्तरदायित्व', 'പരിസ്ഥിതി ഉത്തരവാദിത്തം'),
  _Value('💪', 'இளைஞர் சக்தி', 'Youth Empowerment', 'युवा सशक्तिकरण',
      'യുവജന ശാക്തീകരണം'),
  _Value('❤️', 'மனித அன்பு', 'Human Compassion', 'मानवीय करुणा',
      'മനുഷ്യ കാരുണ്യം'),
  _Value('📚', 'கல்வி உதவி', 'Educational Support', 'शैक्षिक सहायता',
      'വിദ്യാഭ്യാസ സഹായം'),
];

const List<_Milestone> _milestones = [
  _Milestone('1998', 'நாகர்கோவிலில் FYC இயக்கம் தொடங்கியது',
      'FYC movement started in Nagercoil', 'नागरकोइल में FYC आंदोलन शुरू हुआ',
      'നാഗർകോവിലിൽ FYC പ്രസ്ഥാനം ആരംഭിച്ചു'),
  _Milestone('2000', 'அதிகாரப்பூர்வ பதிவு பெறப்பட்டது',
      'Officially registered as Friends Youth Club',
      'फ्रेंड्स यूथ क्लब के रूप में आधिकारिक पंजीकरण',
      'ഫ്രണ്ട്സ് യൂത്ത് ക്ലബ്ബായി ഔദ്യോഗികമായി രജിസ്റ്റർ ചെയ്തു'),
  _Milestone('2005', '100வது சமூக நிகழ்வு கொண்டாடப்பட்டது',
      'Celebrated 100th community event', '100वां सामुदायिक कार्यक्रम मनाया',
      '100-ാമത് സാമൂഹിക പരിപാടി ആഘോഷിച്ചു'),
  _Milestone('2010', '500+ இரத்த தான முகாம்கள்',
      '500+ blood donation camps organized', '500+ रक्तदान शिविर आयोजित',
      '500+ രക്തദാന ക്യാമ്പുകൾ സംഘടിപ്പിച്ചു'),
  _Milestone('2015', '1000+ மரங்கள் நடப்பட்டன', '1000+ trees planted',
      '1000+ पेड़ लगाए गए', '1000+ മരങ്ങൾ നട്ടു'),
  _Milestone('2020', 'COVID நேர அவசர உதவி', 'Emergency relief during COVID-19',
      'COVID-19 के दौरान आपातकालीन राहत',
      'COVID-19 കാലത്തെ അടിയന്തര സഹായം'),
  _Milestone('2026', 'FYC Connect டிஜிட்டல் தளம்',
      'FYC Connect digital platform launched',
      'FYC Connect डिजिटल प्लेटफॉर्म लॉन्च हुआ',
      'FYC Connect ഡിജിറ്റൽ പ്ലാറ്റ്ഫോം ആരംഭിച്ചു'),
];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  String get _lang => sl<LocalStorage>().getLang();

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(
            en: 'About FYC',
            ta: 'எங்களை பற்றி',
            hi: 'FYC के बारे में',
            ml: 'FYC-നെ കുറിച്ച്')),
      ),
      body: ListView(
        children: [
          _Hero(lang: lang),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingPage),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(tr(
                    en: 'Our Mission',
                    ta: 'எங்கள் நோக்கம்',
                    hi: 'हमारा उद्देश्य',
                    ml: 'ഞങ്ങളുടെ ലക്ഷ്യം')),
                const SizedBox(height: 10),
                Text(
                  tr(
                    en: 'Based in Nagercoil, Friends Youth Club harnesses the energy '
                        'of young people to strengthen our community. Through blood '
                        'donation, environmental care, educational support and '
                        'emergency relief, we work to build a dignified life for all.',
                    ta: 'நாகர்கோவிலை மையமாகக் கொண்ட Friends Youth Club, இளைஞர்களின் '
                        'சக்தியால் சமூகத்தை வலுப்படுத்தி, இரத்த தானம், சுற்றுச்சூழல் '
                        'பாதுகாப்பு, கல்வி உதவி மற்றும் அவசர நேர சேவைகள் மூலம் '
                        'அனைவருக்கும் கண்ணியமான வாழ்வை உருவாக்க உழைக்கிறது.',
                    hi: 'नागरकोइल में स्थित Friends Youth Club युवाओं की ऊर्जा से '
                        'हमारे समुदाय को मजबूत बनाता है। रक्तदान, पर्यावरण देखभाल, '
                        'शैक्षिक सहायता और आपातकालीन राहत के माध्यम से हम सभी के लिए '
                        'एक सम्मानजनक जीवन बनाने का प्रयास करते हैं।',
                    ml: 'നാഗർകോവിൽ ആസ്ഥാനമായ Friends Youth Club യുവജനങ്ങളുടെ '
                        'ഊർജ്ജത്താൽ നമ്മുടെ സമൂഹത്തെ ശക്തിപ്പെടുത്തുന്നു. രക്തദാനം, '
                        'പരിസ്ഥിതി സംരക്ഷണം, വിദ്യാഭ്യാസ സഹായം, അടിയന്തര സഹായം '
                        'എന്നിവയിലൂടെ എല്ലാവർക്കും അന്തസ്സുള്ള ജീവിതം '
                        'കെട്ടിപ്പടുക്കാൻ ഞങ്ങൾ പ്രവർത്തിക്കുന്നു.',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 28),
                _SectionTitle(tr(
                    en: 'Our Values',
                    ta: 'எங்கள் மதிப்புகள்',
                    hi: 'हमारे मूल्य',
                    ml: 'ഞങ്ങളുടെ മൂല്യങ്ങൾ')),
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
                _SectionTitle(tr(
                    en: 'Our Journey',
                    ta: 'எங்கள் பயணம்',
                    hi: 'हमारी यात्रा',
                    ml: 'ഞങ്ങളുടെ യാത്ര')),
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
            tr(
                en: 'About FYC',
                ta: 'எங்களை பற்றி',
                hi: 'FYC के बारे में',
                ml: 'FYC-നെ കുറിച്ച്'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
                en: 'Friends Youth Club · Nagercoil',
                ta: 'Friends Youth Club · நாகர்கோவில்',
                hi: 'Friends Youth Club · नागरकोइल',
                ml: 'Friends Youth Club · നാഗർകോവിൽ'),
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
            tr(en: value.en, ta: value.ta, hi: value.hi, ml: value.ml),
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
                tr(
                    en: milestone.en,
                    ta: milestone.ta,
                    hi: milestone.hi,
                    ml: milestone.ml),
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
