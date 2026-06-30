import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key});

  String get _lang => sl<LocalStorage>().getLang();

  // Primary path: open the certificate URL in the system browser/downloader.
  // NOTE: this loses the auth header (see NOTES). When path_provider is added,
  // switch to VolunteerCertBloc -> fetchCertificateBytes() + save to disk.
  Future<void> _download(BuildContext context, String lang) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myCertificate}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
              en: 'Could not open certificate',
              ta: 'சான்றிதழைத் திறக்க முடியவில்லை',
              hi: 'प्रमाणपत्र खोला नहीं जा सका',
              ml: 'സർട്ടിഫിക്കറ്റ് തുറക്കാനായില്ല')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'My Certificate', ta: 'என் சான்றிதழ்', hi: 'मेरा प्रमाणपत्र', ml: 'എന്റെ സർട്ടിഫിക്കറ്റ്')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingPage),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.accentSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text('🪪', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr(en: 'Volunteer Certificate', ta: 'தன்னார்வலர் சான்றிதழ்', hi: 'स्वयंसेवक प्रमाणपत्र', ml: 'വൊളന്റിയർ സർട്ടിഫിക്കറ്റ്'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                  en: 'Your official certificate recognising your volunteer service '
                      'with Friends Youth Club. Tap the button below to download '
                      'your certificate as a PDF.',
                  ta: 'Friends Youth Club-இல் உங்கள் தன்னார்வ சேவையை அங்கீகரிக்கும் '
                      'அதிகாரப்பூர்வ சான்றிதழ். கீழே உள்ள பொத்தானைத் தட்டி உங்கள் '
                      'PDF சான்றிதழைப் பதிவிறக்கம் செய்யவும்.',
                  hi: 'फ्रेंड्स यूथ क्लब के साथ आपकी स्वयंसेवी सेवा को मान्यता देने वाला '
                      'आधिकारिक प्रमाणपत्र। अपना प्रमाणपत्र PDF के रूप में डाउनलोड करने के लिए '
                      'नीचे दिए गए बटन पर टैप करें।',
                  ml: 'ഫ്രണ്ട്സ് യൂത്ത് ക്ലബ്ബിലെ നിങ്ങളുടെ വൊളന്റിയർ സേവനത്തെ '
                      'അംഗീകരിക്കുന്ന ഔദ്യോഗിക സർട്ടിഫിക്കറ്റ്. നിങ്ങളുടെ സർട്ടിഫിക്കറ്റ് '
                      'PDF ആയി ഡൗൺലോഡ് ചെയ്യാൻ താഴെയുള്ള ബട്ടൺ അമർത്തുക.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _download(context, lang),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                  tr(en: 'Download Certificate', ta: 'சான்றிதழைப் பதிவிறக்கு', hi: 'प्रमाणपत्र डाउनलोड करें', ml: 'സർട്ടിഫിക്കറ്റ് ഡൗൺലോഡ് ചെയ്യുക')),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(
                          en: 'The certificate opens in your device browser for '
                              'download.',
                          ta: 'சான்றிதழ் உங்கள் சாதனத்தின் உலாவியில் திறக்கப்படும்.',
                          hi: 'प्रमाणपत्र डाउनलोड के लिए आपके डिवाइस के ब्राउज़र में खुलता है।',
                          ml: 'സർട്ടിഫിക്കറ്റ് ഡൗൺലോഡിനായി നിങ്ങളുടെ ഡിവൈസിന്റെ ബ്രൗസറിൽ തുറക്കും.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
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
