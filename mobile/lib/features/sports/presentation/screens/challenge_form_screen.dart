import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../bloc/sports_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class _SportOption {
  final String value;
  final String emoji;
  final String labelEn;
  final String labelTa;
  const _SportOption(this.value, this.emoji, this.labelEn, this.labelTa);
}

const _sportOptions = <_SportOption>[
  _SportOption('cricket', '🏏', 'Cricket', 'கிரிக்கெட்'),
  _SportOption('kabaddi', '🤼', 'Kabaddi', 'கபடி'),
  _SportOption('volleyball', '🏐', 'Volleyball', 'கைப்பந்து'),
  _SportOption('football', '⚽', 'Football', 'கால்பந்து'),
  _SportOption('other', '🎯', 'Other', 'மற்றவை'),
];

class ChallengeFormScreen extends StatefulWidget {
  const ChallengeFormScreen({super.key});

  @override
  State<ChallengeFormScreen> createState() => _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends State<ChallengeFormScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _captainController = TextEditingController();
  final _phoneController = TextEditingController();
  final _venueController = TextEditingController();
  final _messageController = TextEditingController();
  String _sport = _sportOptions.first.value;

  @override
  void dispose() {
    _teamNameController.dispose();
    _captainController.dispose();
    _phoneController.dispose();
    _venueController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SportsBloc>().add(
          SportsChallengeSubmitted(
            challengerTeamName: _teamNameController.text.trim(),
            challengerCaptain: _captainController.text.trim(),
            challengerPhone: _phoneController.text.trim(),
            sport: _sport,
            venue: _venueController.text.trim().isEmpty
                ? null
                : _venueController.text.trim(),
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          ),
        );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _lang == 'ta' ? 'இது தேவை' : 'Required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'ta' ? 'FYC ஐ சவால் விடுங்கள்' : 'Challenge FYC'),
      ),
      body: BlocConsumer<SportsBloc, SportsState>(
        listener: (context, state) {
          if (state is SportsChallengeSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  lang == 'ta'
                      ? 'சவால் அனுப்பப்பட்டது! நிலை: ${state.message}'
                      : 'Challenge sent! Status: ${state.message}',
                ),
                backgroundColor: AppColors.primary,
              ),
            );
            context.go('/sports');
          }
          if (state is SportsFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSubmitting = state is SportsLoading;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.paddingPage),
              children: [
                Text(
                  lang == 'ta'
                      ? 'உங்கள் அணியின் விவரங்களை பூர்த்தி செய்து FYC உடன் நட்பு போட்டிக்கு சவால் விடுங்கள்.'
                      : 'Fill in your team details to challenge FYC to a friendly match.',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _Label(text: lang == 'ta' ? 'அணியின் பெயர்' : 'Team Name'),
                TextFormField(
                  controller: _teamNameController,
                  validator: _required,
                  decoration: InputDecoration(
                    hintText:
                        lang == 'ta' ? 'உங்கள் அணியின் பெயர்' : 'Your team name',
                  ),
                ),
                const SizedBox(height: 16),
                _Label(text: lang == 'ta' ? 'அணித்தலைவர்' : 'Captain'),
                TextFormField(
                  controller: _captainController,
                  validator: _required,
                  decoration: InputDecoration(
                    hintText:
                        lang == 'ta' ? 'அணித்தலைவர் பெயர்' : 'Captain name',
                  ),
                ),
                const SizedBox(height: 16),
                _Label(text: lang == 'ta' ? 'தொலைபேசி' : 'Phone'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: _required,
                  decoration: InputDecoration(
                    hintText:
                        lang == 'ta' ? 'தொடர்பு எண்' : 'Contact number',
                  ),
                ),
                const SizedBox(height: 16),
                _Label(text: lang == 'ta' ? 'விளையாட்டு' : 'Sport'),
                DropdownButtonFormField<String>(
                  initialValue: _sport,
                  items: _sportOptions
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.value,
                          child: Text(
                              '${o.emoji} ${lang == 'ta' ? o.labelTa : o.labelEn}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _sport = v ?? _sport),
                ),
                const SizedBox(height: 16),
                _Label(
                    text: lang == 'ta'
                        ? 'இடம் (விருப்பத்திற்கு)'
                        : 'Venue (optional)'),
                TextFormField(
                  controller: _venueController,
                  decoration: InputDecoration(
                    hintText:
                        lang == 'ta' ? 'விளையாட்டு இடம்' : 'Match venue',
                  ),
                ),
                const SizedBox(height: 16),
                _Label(
                    text: lang == 'ta'
                        ? 'செய்தி (விருப்பத்திற்கு)'
                        : 'Message (optional)'),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: lang == 'ta'
                        ? 'கூடுதல் விவரங்கள்'
                        : 'Any additional details',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('⚔️', style: TextStyle(fontSize: 18)),
                  label: Text(
                    lang == 'ta' ? 'சவால் அனுப்பு' : 'Send Challenge',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
