import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../../domain/entities/weekly_game_entity.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';

class CreateWeeklyGameSheet extends StatefulWidget {
  final WeeklyGameEntity? game;
  const CreateWeeklyGameSheet({super.key, this.game});

  @override
  State<CreateWeeklyGameSheet> createState() => _CreateWeeklyGameSheetState();
}

class _CreateWeeklyGameSheetState extends State<CreateWeeklyGameSheet> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _sport = 'cricket';
  String _venue = '';
  DateTime? _scheduledAt;
  TimeOfDay? _scheduledTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.game != null) {
      final g = widget.game!;
      _title = g.title;
      _sport = g.sport;
      _venue = g.venue ?? '';
      _scheduledAt = g.scheduledAt;
      _scheduledTime = TimeOfDay.fromDateTime(g.scheduledAt.toLocal());
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null || _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }
    _formKey.currentState!.save();
    
    final finalDate = DateTime(
      _scheduledAt!.year,
      _scheduledAt!.month,
      _scheduledAt!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );
    
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = {
        'title': _title,
        'sport': _sport,
        'venue': _venue,
        'scheduled_at': finalDate.toUtc().toIso8601String(),
      };
      
      if (widget.game != null) {
        await sl<ApiClient>().dio.patch(
          '${ApiConstants.weeklyGames}/${widget.game!.id}',
          data: data,
        );
        if (!mounted) return;
        context.read<SportsBloc>().add(const SportsFetchRequested());
        Navigator.pop(context, true);
        messenger.showSnackBar(
          const SnackBar(content: Text('Weekly game updated successfully!'), backgroundColor: AppColors.success),
        );
      } else {
        context.read<SportsBloc>().add(SportsWeeklyGameCreateRequested(data));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save game details'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Schedule a Match',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _title,
              decoration: InputDecoration(
                labelText: 'Match Title',
                hintText: 'e.g. Sunday Morning Bash',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onSaved: (v) => _title = v!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _sport,
              decoration: InputDecoration(
                labelText: 'Sport',
                prefixIcon: const Icon(Icons.sports),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'cricket', child: Text('Cricket 🏏')),
                DropdownMenuItem(value: 'football', child: Text('Football ⚽')),
              ],
              onChanged: (v) => setState(() => _sport = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _venue,
              decoration: InputDecoration(
                labelText: 'Venue',
                hintText: 'e.g. FYC Ground',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSaved: (v) => _venue = v ?? '',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (d != null) setState(() => _scheduledAt = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_scheduledAt != null ? DateFormat('MMM d, yyyy').format(_scheduledAt!) : 'Select Date'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 7, minute: 0),
                      );
                      if (t != null) setState(() => _scheduledTime = t);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Time',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_scheduledTime != null ? _scheduledTime!.format(context) : 'Select Time'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(widget.game != null ? 'Save Changes' : 'Schedule Game', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
