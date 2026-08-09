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
          content: Text(trId('could_not_post_please_try_again')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('post_a_job')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(trId('type'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(trId('job')),
                  selected: _type == 'JOB',
                  onSelected: (_) => setState(() => _type = 'JOB'),
                ),
                ChoiceChip(
                  label: Text(trId('volunteer_3')),
                  selected: _type == 'VOLUNTEER',
                  onSelected: (_) => setState(() => _type = 'VOLUNTEER'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field(_titleEn,
                trId('title_english'),
                required: true),
            _field(_titleTa,
                trId('title_tamil_optional')),
            _field(_organizer,
                trId('organizer')),
            _field(_category,
                trId('category')),
            _field(_location,
                trId('location')),
            if (_type == 'JOB')
              _field(_budget,
                  trId('budget_pay_e_g_500_day')),
            _field(_hours,
                trId('hours_commitment')),
            _field(_contact,
                trId('contact_phone_shown_to_applicants'),
                keyboardType: TextInputType.phone),
            _field(_descEn,
                trId('description'),
                maxLines: 4),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(trId('post')),
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
                ? trId('required_2')
                : null
            : null,
      ),
    );
  }
}
