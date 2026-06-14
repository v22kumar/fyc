import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/blood_donor_bloc.dart';
import '../bloc/blood_donor_event.dart';
import '../bloc/blood_donor_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class DonorRegistrationScreen extends StatefulWidget {
  const DonorRegistrationScreen({super.key});

  @override
  State<DonorRegistrationScreen> createState() =>
      _DonorRegistrationScreenState();
}

class _DonorRegistrationScreenState extends State<DonorRegistrationScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  String? _selectedGroup;
  bool _isAvailable = true;
  DateTime? _lastDonationDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _lastDonationDate = picked);
  }

  void _submit() {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _lang == 'ta'
                ? 'இரத்த வகை தேர்ந்தெடுக்கவும்'
                : 'Please select your blood group',
          ),
        ),
      );
      return;
    }
    context.read<BloodDonorBloc>().add(
          BloodDonorRegisterRequested(
            bloodGroup: _selectedGroup!,
            isAvailable: _isAvailable,
            lastDonationDate: _lastDonationDate,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'ta' ? 'தானியாக பதிவு' : 'Register as Donor'),
      ),
      body: BlocListener<BloodDonorBloc, BloodDonorState>(
        listener: (context, state) {
          if (state is BloodDonorRegistered) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  lang == 'ta'
                      ? 'வெற்றிகரமாக பதிவு செய்யப்பட்டீர்கள்!'
                      : 'Registered successfully! Thank you.',
                ),
                backgroundColor: AppColors.primary,
              ),
            );
            context.pop();
          }
          if (state is BloodDonorFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(lang: lang),
              const SizedBox(height: 24),
              Text(
                lang == 'ta' ? 'இரத்த வகை தேர்ந்தெடுக்கவும்' : 'Select Blood Group',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _BloodGroupGrid(
                groups: _groups,
                selected: _selectedGroup,
                onSelect: (g) => setState(() => _selectedGroup = g),
              ),
              const SizedBox(height: 24),
              Text(
                lang == 'ta' ? 'கிடைக்கும் நிலை' : 'Availability',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _AvailabilityToggle(
                value: _isAvailable,
                lang: lang,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              const SizedBox(height: 24),
              Text(
                lang == 'ta'
                    ? 'கடைசி தான தேதி (விரும்பினால்)'
                    : 'Last Donation Date (optional)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _DatePickerField(
                date: _lastDonationDate,
                lang: lang,
                onTap: _pickDate,
              ),
              const SizedBox(height: 36),
              BlocBuilder<BloodDonorBloc, BloodDonorState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          state is BloodDonorLoading ? null : _submit,
                      child: state is BloodDonorLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              lang == 'ta'
                                  ? 'தானியாக பதிவு செய்க'
                                  : 'Register as Donor',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String lang;

  const _InfoBanner({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lang == 'ta'
                  ? 'உங்கள் தொலைபேசி எண் யாரேனும் கோரும்போது மட்டுமே பகிரப்படும். அனைத்து கோரிக்கைகளும் பதிவு செய்யப்படும்.'
                  : 'Your phone number will only be shared when someone explicitly requests your contact. All requests are logged.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BloodGroupGrid extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final void Function(String) onSelect;

  const _BloodGroupGrid({
    required this.groups,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: groups.map((g) {
        final isSelected = g == selected;
        return GestureDetector(
          onTap: () => onSelect(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AvailabilityToggle extends StatelessWidget {
  final bool value;
  final String lang;
  final void Function(bool) onChanged;

  const _AvailabilityToggle({
    required this.value,
    required this.lang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value
                  ? (lang == 'ta' ? 'தான செய்ய கிடைக்கிறேன்' : 'I am available to donate')
                  : (lang == 'ta' ? 'தற்போது கிடைக்கவில்லை' : 'Not available right now'),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime? date;
  final String lang;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.date,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.grey),
            const SizedBox(width: 12),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : (lang == 'ta' ? 'தேதி தேர்வு (விரும்பினால்)' : 'Select date (optional)'),
              style: TextStyle(
                fontSize: 15,
                color: date != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
