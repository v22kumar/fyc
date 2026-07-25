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
          content: Text(trId('pick_a_start_and_end_time')),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }
    if (!_end!.isAfter(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trId('end_time_must_be_after_start')),
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
      'registration_enabled': _requiresRegistration,
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
          content: Text(trId('could_not_create_event_please_try_again')),
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
        title: Text(trId('create_event')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_titleEn,
                trId('title_english'),
                required: true),
            _field(_titleTa,
                trId('title_tamil_optional')),
            _field(_descEn,
                trId('description_english'),
                required: true, maxLines: 4),
            _field(_descTa,
                trId('description_tamil_optional'),
                maxLines: 4),
            _dateTile(
              label: trId('starts'),
              value: _start == null ? null : fmt.format(_start!),
              onTap: () => _pick(isStart: true),
            ),
            _dateTile(
              label: trId('ends'),
              value: _end == null ? null : fmt.format(_end!),
              onTap: () => _pick(isStart: false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(trId('requires_registration')),
              value: _requiresRegistration,
              onChanged: (v) => setState(() => _requiresRegistration = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(trId('publish_now')),
              subtitle: Text(trId('off_saved_as_draft')),
              value: _publishNow,
              onChanged: (v) => setState(() => _publishNow = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(trId('create')),
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
            trId('tap_to_choose')),
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
                ? trId('required_2')
                : null
            : null,
      ),
    );
  }
}
