import 'package:flutter/material.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/opportunity_datasource.dart';

/// Post-a-job form, open to any signed-in member. Pops with `true` on success
/// so the list can refresh. A Job carries a budget; a Volunteer drive does not.
class OpportunityCreateScreen extends StatefulWidget {
  const OpportunityCreateScreen({super.key});

  @override
  State<OpportunityCreateScreen> createState() => _OpportunityCreateScreenState();
}

class _OpportunityCreateScreenState extends State<OpportunityCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'JOB';
  final _titleEn = TextEditingController();
  final _titleTa = TextEditingController();
  final _organizer = TextEditingController();
  final _category = TextEditingController();
  final _location = TextEditingController();
  final _hours = TextEditingController();
  final _budget = TextEditingController();
  final _contact = TextEditingController();
  final _descEn = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleEn.dispose();
    _titleTa.dispose();
    _organizer.dispose();
    _category.dispose();
    _location.dispose();
    _hours.dispose();
    _budget.dispose();
    _contact.dispose();
    _descEn.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    // title_ta is required by the backend — fall back to the English title.
    final titleTa = _titleTa.text.trim().isEmpty ? _titleEn.text.trim() : _titleTa.text.trim();
    final body = <String, dynamic>{
      'type': _type,
      'title_en': _titleEn.text.trim(),
      'title_ta': titleTa,
      if (_organizer.text.trim().isNotEmpty) 'organizer_en': _organizer.text.trim(),
      if (_category.text.trim().isNotEmpty) 'category_en': _category.text.trim(),
      if (_location.text.trim().isNotEmpty) 'location_en': _location.text.trim(),
      if (_hours.text.trim().isNotEmpty) 'hours': _hours.text.trim(),
      if (_type == 'JOB' && _budget.text.trim().isNotEmpty) 'budget': _budget.text.trim(),
      if (_contact.text.trim().isNotEmpty) 'contact_phone': _contact.text.trim(),
      if (_descEn.text.trim().isNotEmpty) 'description_en': _descEn.text.trim(),
      'is_active': true,
    };
    try {
      await sl<OpportunityDataSource>().createOpportunity(body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: AppColors.accent),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(en: 'Could not post. Please try again.',
              ta: 'பதிவிட முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
              hi: 'पोस्ट नहीं हो सका। पुनः प्रयास करें।',
              ml: 'പോസ്റ്റ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Post a Job', ta: 'வேலையை பதிவிடு',
            hi: 'नौकरी पोस्ट करें', ml: 'ജോലി പോസ്റ്റ് ചെയ്യൂ')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(en: 'Type', ta: 'வகை', hi: 'प्रकार', ml: 'തരം'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(tr(en: 'Job', ta: 'வேலை', hi: 'नौकरी', ml: 'ജോലി')),
                  selected: _type == 'JOB',
                  onSelected: (_) => setState(() => _type = 'JOB'),
                ),
                ChoiceChip(
                  label: Text(tr(en: 'Volunteer', ta: 'தன்னார்வ', hi: 'स्वयंसेवक', ml: 'വളണ്ടിയർ')),
                  selected: _type == 'VOLUNTEER',
                  onSelected: (_) => setState(() => _type = 'VOLUNTEER'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field(_titleEn,
                tr(en: 'Title (English)', ta: 'தலைப்பு (ஆங்கிலம்)', hi: 'शीर्षक (अंग्रेज़ी)', ml: 'തലക്കെട്ട് (ഇംഗ്ലീഷ്)'),
                required: true),
            _field(_titleTa,
                tr(en: 'Title (Tamil, optional)', ta: 'தலைப்பு (தமிழ்)', hi: 'शीर्षक (तमिल)', ml: 'തലക്കെട്ട് (തമിഴ്)')),
            _field(_organizer,
                tr(en: 'Organizer', ta: 'ஏற்பாட்டாளர்', hi: 'आयोजक', ml: 'സംഘാടകൻ')),
            _field(_category,
                tr(en: 'Category', ta: 'வகை', hi: 'श्रेणी', ml: 'വിഭാഗം')),
            _field(_location,
                tr(en: 'Location', ta: 'இடம்', hi: 'स्थान', ml: 'സ്ഥലം')),
            if (_type == 'JOB')
              _field(_budget,
                  tr(en: 'Budget / pay (e.g. ₹500/day)', ta: 'ஊதியம் (எ.கா. ₹500/நாள்)',
                      hi: 'बजट / वेतन (जैसे ₹500/दिन)', ml: 'ബജറ്റ് / വേതനം (ഉദാ. ₹500/ദിവസം)')),
            _field(_hours,
                tr(en: 'Hours / commitment', ta: 'நேரம்', hi: 'समय', ml: 'സമയം')),
            _field(_contact,
                tr(en: 'Contact phone (shown to applicants)', ta: 'தொடர்பு எண்',
                    hi: 'संपर्क फ़ोन', ml: 'ബന്ധപ്പെടാനുള്ള ഫോൺ'),
                keyboardType: TextInputType.phone),
            _field(_descEn,
                tr(en: 'Description', ta: 'விவரம்', hi: 'विवरण', ml: 'വിവരണം'),
                maxLines: 4),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(en: 'Post', ta: 'பதிவிடு', hi: 'पोस्ट करें', ml: 'പോസ്റ്റ്')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? tr(en: 'Required', ta: 'தேவை', hi: 'आवश्यक', ml: 'ആവശ്യമാണ്')
                : null
            : null,
      ),
    );
  }
}
