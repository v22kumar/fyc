import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/event_datasource.dart';

/// Create-event form for managers/admins. Pops with `true` on success.
class EventCreateScreen extends StatefulWidget {
  const EventCreateScreen({super.key});

  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleEn = TextEditingController();
  final _titleTa = TextEditingController();
  final _descEn = TextEditingController();
  final _descTa = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _requiresRegistration = true;
  bool _publishNow = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleEn.dispose();
    _titleTa.dispose();
    _descEn.dispose();
    _descTa.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isStart}) async {
    final now = DateTime.now();
    final base = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        if (_end != null && _end!.isBefore(dt)) _end = null;
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(en: 'Pick a start and end time',
              ta: 'தொடக்க & முடிவு நேரத்தைத் தேர்வுசெய்க',
              hi: 'शुरू और समाप्ति समय चुनें',
              ml: 'ആരംഭ, അവസാന സമയം തിരഞ്ഞെടുക്കുക')),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }
    if (!_end!.isAfter(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(en: 'End time must be after start',
              ta: 'முடிவு நேரம் தொடக்கத்திற்குப் பின் இருக்க வேண்டும்',
              hi: 'समाप्ति समय शुरू के बाद होना चाहिए',
              ml: 'അവസാന സമയം ആരംഭത്തിന് ശേഷമായിരിക്കണം')),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final titleTa = _titleTa.text.trim().isEmpty ? _titleEn.text.trim() : _titleTa.text.trim();
    final descTa = _descTa.text.trim().isEmpty ? _descEn.text.trim() : _descTa.text.trim();
    final body = <String, dynamic>{
      'title_en': _titleEn.text.trim(),
      'title_ta': titleTa,
      'description_en': _descEn.text.trim(),
      'description_ta': descTa,
      'event_start': _start!.toUtc().toIso8601String(),
      'event_end': _end!.toUtc().toIso8601String(),
      'is_published': _publishNow,
      'requires_registration': _requiresRegistration,
    };
    try {
      await sl<EventDataSource>().createEvent(body);
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
          content: Text(tr(en: 'Could not create event. Please try again.',
              ta: 'நிகழ்வை உருவாக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
              hi: 'कार्यक्रम नहीं बना। पुनः प्रयास करें।',
              ml: 'പരിപാടി സൃഷ്ടിക്കാനായില്ല. വീണ്ടും ശ്രമിക്കുക.')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM · h:mm a');
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Create Event', ta: 'நிகழ்வை உருவாக்கு',
            hi: 'कार्यक्रम बनाएं', ml: 'പരിപാടി സൃഷ്ടിക്കുക')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_titleEn,
                tr(en: 'Title (English)', ta: 'தலைப்பு (ஆங்கிலம்)', hi: 'शीर्षक (अंग्रेज़ी)', ml: 'തലക്കെട്ട് (ഇംഗ്ലീഷ്)'),
                required: true),
            _field(_titleTa,
                tr(en: 'Title (Tamil, optional)', ta: 'தலைப்பு (தமிழ்)', hi: 'शीर्षक (तमिल)', ml: 'തലക്കെട്ട് (തമിഴ്)')),
            _field(_descEn,
                tr(en: 'Description (English)', ta: 'விவரம் (ஆங்கிலம்)', hi: 'विवरण (अंग्रेज़ी)', ml: 'വിവരണം (ഇംഗ്ലീഷ്)'),
                required: true, maxLines: 4),
            _field(_descTa,
                tr(en: 'Description (Tamil, optional)', ta: 'விவரம் (தமிழ்)', hi: 'विवरण (तमिल)', ml: 'വിവരണം (തമിഴ്)'),
                maxLines: 4),
            _dateTile(
              label: tr(en: 'Starts', ta: 'தொடக்கம்', hi: 'शुरू', ml: 'ആരംഭം'),
              value: _start == null ? null : fmt.format(_start!),
              onTap: () => _pick(isStart: true),
            ),
            _dateTile(
              label: tr(en: 'Ends', ta: 'முடிவு', hi: 'समाप्ति', ml: 'അവസാനം'),
              value: _end == null ? null : fmt.format(_end!),
              onTap: () => _pick(isStart: false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(en: 'Requires registration', ta: 'பதிவு தேவை',
                  hi: 'पंजीकरण आवश्यक', ml: 'രജിസ്ട്രേഷൻ ആവശ്യമാണ്')),
              value: _requiresRegistration,
              onChanged: (v) => setState(() => _requiresRegistration = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(en: 'Publish now', ta: 'இப்போது வெளியிடு',
                  hi: 'अभी प्रकाशित करें', ml: 'ഇപ്പോൾ പ്രസിദ്ധീകരിക്കുക')),
              subtitle: Text(tr(en: 'Off = saved as draft', ta: 'ஆஃப் = வரைவாக சேமிக்கும்',
                  hi: 'बंद = ड्राफ्ट', ml: 'ഓഫ് = ഡ്രാഫ്റ്റ്')),
              value: _publishNow,
              onChanged: (v) => setState(() => _publishNow = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr(en: 'Create', ta: 'உருவாக்கு', hi: 'बनाएं', ml: 'സൃഷ്ടിക്കുക')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile({required String label, String? value, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(label),
        subtitle: Text(value ??
            tr(en: 'Tap to choose', ta: 'தேர்வுசெய்ய தட்டவும்', hi: 'चुनने के लिए टैप करें', ml: 'തിരഞ്ഞെടുക്കാൻ ടാപ്പ് ചെയ്യുക')),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
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
