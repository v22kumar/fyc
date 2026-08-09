import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/team_entity.dart';
import '../screens/team_management_screen.dart';

class EditTeamSheet extends StatefulWidget {
  final String tournamentId;
  final TeamEntity team;
  final VoidCallback onTeamUpdated;

  const EditTeamSheet({
    super.key,
    required this.tournamentId,
    required this.team,
    required this.onTeamUpdated,
  });

  @override
  State<EditTeamSheet> createState() => _EditTeamSheetState();
}

class _EditTeamSheetState extends State<EditTeamSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _captainCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _winsCtrl;
  late final TextEditingController _lossesCtrl;
  late final TextEditingController _drawsCtrl;
  late final TextEditingController _pointsCtrl;
  late bool _isFycTeam;
  late bool _eliminated;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.team.name);
    _captainCtrl = TextEditingController(text: widget.team.captainName ?? '');
    _phoneCtrl = TextEditingController(text: widget.team.contactPhone ?? '');
    _winsCtrl = TextEditingController(text: widget.team.wins.toString());
    _lossesCtrl = TextEditingController(text: widget.team.losses.toString());
    _drawsCtrl = TextEditingController(text: widget.team.draws.toString());
    _pointsCtrl = TextEditingController(text: widget.team.points.toString());
    _isFycTeam = widget.team.isFycTeam;
    _eliminated = widget.team.eliminated;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _captainCtrl.dispose();
    _phoneCtrl.dispose();
    _winsCtrl.dispose();
    _lossesCtrl.dispose();
    _drawsCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sl<ApiClient>().dio.patch(
        '${ApiConstants.sportsTournaments}/${widget.tournamentId}/teams/${widget.team.id}',
        data: {
          'name': _nameCtrl.text.trim(),
          'captain_name': _captainCtrl.text.trim().isEmpty ? null : _captainCtrl.text.trim(),
          'contact_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'is_fyc_team': _isFycTeam,
          'eliminated': _eliminated,
          'wins': int.tryParse(_winsCtrl.text) ?? 0,
          'losses': int.tryParse(_lossesCtrl.text) ?? 0,
          'draws': int.tryParse(_drawsCtrl.text) ?? 0,
          'points': int.tryParse(_pointsCtrl.text) ?? 0,
        },
      );
      if (!mounted) return;
      widget.onTeamUpdated();
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(trId('team_updated_successfully')), backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          SnackBar(content: Text(trId('could_not_update_team')), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Text(trId('edit_team_standings'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: trId('team_name_2'))),
            const SizedBox(height: 12),
            TextField(controller: _captainCtrl, decoration: InputDecoration(labelText: trId('captain_name'))),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: trId('contact_phone'))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _winsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: trId('wins')))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _lossesCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: trId('losses')))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _drawsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: trId('draws')))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _pointsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: trId('points')))),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(trId('fyc_team'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              value: _isFycTeam,
              onChanged: (val) => setState(() => _isFycTeam = val),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(trId('eliminated_knocked_out'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              value: _eliminated,
              onChanged: (val) => setState(() => _eliminated = val),
              activeThumbColor: AppColors.accent,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TeamManagementScreen(
                    teamId: widget.team.id,
                    teamName: widget.team.name,
                  ),
                ));
              },
              icon: const Icon(Icons.groups_outlined, size: 18),
              label: Text(trId('manage_players')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _submitting ? CircularProgressIndicator(color: AppColors.background) : Text(trId('save_changes'), style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
