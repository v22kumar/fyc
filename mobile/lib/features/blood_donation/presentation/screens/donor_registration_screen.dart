import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/location/member_location.dart';
import '../bloc/blood_donor_bloc.dart';
import '../bloc/blood_donor_event.dart';
import '../bloc/blood_donor_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

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
  /// On by default, because registering as a donor already means "find me".
  ///
  /// Two different things used to live in this one switch, and conflating them
  /// is what made it dangerous to default on:
  ///
  /// * **Willingness to be located** — an intent, and one this member has
  ///   effectively already stated by opening a screen called "Register as
  ///   donor". Defaulting that to off meant people lost the feature by not
  ///   noticing a toggle, which in an emergency is the expensive kind of quiet.
  /// * **Permission to read the GPS** — which Android owns, which the DPDP Act
  ///   wants given by a clear affirmative act, and which a pre-ticked box
  ///   cannot supply. That is asked at submit, through the same disclosure
  ///   sheet as everywhere else, never on screen open.
  ///
  /// So the switch expresses the intent and starts on; the permission is still
  /// asked, once, at the moment they commit.
  bool _shareLocation = true;
  bool _capturing = false;
  double? _lat;
  double? _lng;

  /// Flipping the switch records intent. Nothing is read from the phone here —
  /// the position is fetched once, at submit.
  void _toggleLocation(bool on) => setState(() {
        _shareLocation = on;
        if (!on) {
          _lat = null;
          _lng = null;
        }
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _lastDonationDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trId('please_select_your_blood_group'),
          ),
        ),
      );
      return;
    }

    // The one moment the phone is asked where it is: they have chosen a blood
    // group, left the switch on, and pressed the button. A home area is stored
    // and searched against for months, so this insists on a real fix.
    if (_shareLocation && _lat == null) {
      setState(() => _capturing = true);
      final pos = await MemberLocation.precise(context);
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _lat = pos?.latitude;
        _lng = pos?.longitude;
      });
    }

    context.read<BloodDonorBloc>().add(
          BloodDonorRegisterRequested(
            bloodGroup: _selectedGroup!,
            isAvailable: _isAvailable,
            lastDonationDate: _lastDonationDate,
            latitude: _lat,
            longitude: _lng,
            // Their answer, not the outcome of a permission dialog. Somebody
            // who left this on and then hit a denied prompt is still willing —
            // and the app collects a position opportunistically the next time
            // they open the blood screen, at which point the consent is already
            // on record and it simply starts working. Recording false here
            // would have silently thrown that away.
            locationConsent: _shareLocation,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('register_as_donor_2')),
      ),
      body: BlocListener<BloodDonorBloc, BloodDonorState>(
        listener: (context, state) {
          if (state is BloodDonorRegistered) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  trId('registered_successfully_thank_you'),
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
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(lang: lang),
              SizedBox(height: 24),
              Text(
                trId('select_blood_group'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _BloodGroupGrid(
                groups: _groups,
                selected: _selectedGroup,
                onSelect: (g) => setState(() => _selectedGroup = g),
              ),
              SizedBox(height: 24),
              Text(
                trId('availability'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              _AvailabilityToggle(
                value: _isAvailable,
                lang: lang,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              SizedBox(height: 24),
              Text(
                trId('last_donation_date_optional'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              _DatePickerField(
                date: _lastDonationDate,
                lang: lang,
                onTap: _pickDate,
              ),
              SizedBox(height: 24),
              // How an emergency finds you by real distance rather than by the
              // name of a taluk. On by default because that is what registering
              // as a donor means; a single base point, never continuous
              // tracking; and the phone is not asked anything until submit.
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _shareLocation
                        ? AppColors.primary
                        : AppColors.textSecondary.withOpacity(0.3),
                  ),
                  color: _shareLocation ? AppColors.primary.withOpacity(0.06) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location_rounded,
                            color: _shareLocation ? AppColors.primary : AppColors.textSecondary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(trId('share_location_for_emergencies'),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        if (_capturing)
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Switch(
                            value: _shareLocation,
                            activeColor: AppColors.primary,
                            onChanged: (v) => _toggleLocation(v),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Says what each position actually costs the member.
                    // Turning it off is a real choice, so it is worth stating
                    // the consequence rather than leaving it to be discovered:
                    // they stay in the directory, they just stop being
                    // findable by distance.
                    Text(
                      _shareLocation
                          ? trId('location_on_explainer')
                          : trId('location_off_explainer'),
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 36),
              BlocBuilder<BloodDonorBloc, BloodDonorState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          state is BloodDonorLoading ? null : _submit,
                      child: state is BloodDonorLoading
                          ? CircularProgressIndicator(
                              color: AppColors.background,
                            )
                          : Text(
                              trId('register_as_donor_3'),
                              style: TextStyle(fontSize: 16),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              trId('your_phone_number_will_only_be_shared_wh'),
              style: TextStyle(fontSize: 13),
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
              color: isSelected ? AppColors.accent : AppColors.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.textSecondary.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.background : AppColors.textSecondary.withOpacity(0.7),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? AppColors.success : AppColors.textSecondary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value
                  ? trId('i_am_available_to_donate')
                  : trId('not_available_right_now'),
              style: TextStyle(fontSize: 15),
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : trId('select_date_optional'),
              style: TextStyle(
                fontSize: 15,
                color: date != null ? Colors.black87 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
