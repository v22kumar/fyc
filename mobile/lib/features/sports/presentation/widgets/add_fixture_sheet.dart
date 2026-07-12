import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/team_entity.dart';

class AddFixtureSheet extends StatefulWidget {
  final String tournamentId;
  final List<TeamEntity> teams;
  const AddFixtureSheet({super.key, required this.tournamentId, required this.teams});

  @override
  State<AddFixtureSheet> createState() => _AddFixtureSheetState();
}

class _AddFixtureSheetState extends State<AddFixtureSheet> {
  String? _teamAId;
  String? _teamBId;
  final _matchNumCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  DateTime? _scheduledAt;
  bool _submitting = false;

  @override
  void dispose() {
    _matchNumCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_teamAId == null || _teamBId == null) return;
    if (_teamAId == _teamBId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team A and Team B cannot be the same'), backgroundColor: AppColors.accent),
      );
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sl<ApiClient>().dio.post(
        ApiConstants.sportsTournamentFixtures(widget.tournamentId),
        data: {
          'team_a_id': _teamAId,
          'team_b_id': _teamBId,
          'match_number': _matchNumCtrl.text.isNotEmpty ? int.tryParse(_matchNumCtrl.text) : null,
          'scheduled_at': _scheduledAt?.toUtc().toIso8601String(),
          'venue': _venueCtrl.text.trim().isNotEmpty ? _venueCtrl.text.trim() : null,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Fixture Scheduled successfully!'), backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not schedule fixture'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          const Text('Schedule Fixture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _teamAId,
            hint: const Text('Select Team A'),
            items: widget.teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (val) => setState(() => _teamAId = val),
            decoration: const InputDecoration(labelText: 'Team A *'),
          ),
          const SizedBox(height: 12),
          
          DropdownButtonFormField<String>(
            value: _teamBId,
            hint: const Text('Select Team B'),
            items: widget.teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (val) => setState(() => _teamBId = val),
            decoration: const InputDecoration(labelText: 'Team B *'),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _matchNumCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Match Number'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _selectDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Scheduled At'),
                    child: Text(
                      _scheduledAt == null
                          ? 'Select Date/Time'
                          : '${_scheduledAt!.day}/${_scheduledAt!.month} ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 14, color: _scheduledAt == null ? Colors.grey : context.cText),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _venueCtrl,
            decoration: const InputDecoration(labelText: 'Venue'),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Schedule Fixture', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
