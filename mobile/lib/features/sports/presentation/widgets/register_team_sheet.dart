import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';

class RegisterTeamSheet extends StatefulWidget {
  final String tournamentId;
  const RegisterTeamSheet({super.key, required this.tournamentId});

  @override
  State<RegisterTeamSheet> createState() => _RegisterTeamSheetState();
}

class _RegisterTeamSheetState extends State<RegisterTeamSheet> {
  final _nameCtrl = TextEditingController();
  final _captainCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _captainCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _captainCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sl<ApiClient>().dio.post(
        ApiConstants.sportsTournamentTeams(widget.tournamentId),
        data: {
          'name': _nameCtrl.text.trim(),
          'captain_name': _captainCtrl.text.trim(),
          'contact_phone': _phoneCtrl.text.trim(),
          'is_fyc_team': false,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Team Registration Submitted!'), backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not register team'), backgroundColor: AppColors.accent),
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
          const Text('Register Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Team Name')),
          const SizedBox(height: 12),
          TextField(controller: _captainCtrl, decoration: const InputDecoration(labelText: 'Captain Name')),
          const SizedBox(height: 12),
          TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact Phone')),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
