import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/blood_donor_entity.dart';
import '../bloc/blood_donor_bloc.dart';
import '../bloc/blood_donor_event.dart';
import '../bloc/blood_donor_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class BloodDonationHubScreen extends StatefulWidget {
  const BloodDonationHubScreen({super.key});

  @override
  State<BloodDonationHubScreen> createState() => _BloodDonationHubScreenState();
}

class _BloodDonationHubScreenState extends State<BloodDonationHubScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    context.read<BloodDonorBloc>().add(const BloodDonorSearchRequested());
  }

  void _search(String? group) {
    setState(() => _selectedGroup = group);
    context.read<BloodDonorBloc>().add(
          BloodDonorSearchRequested(bloodGroup: group),
        );
  }

  Future<void> _launchWhatsApp(String link) async {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _requestContact(BuildContext context, BloodDonorEntity donor) {
    showDialog(
      context: context,
      builder: (_) => _ContactDialog(
        donor: donor,
        onConfirm: () {
          context
              .read<BloodDonorBloc>()
              .add(BloodDonorContactRequested(donor.id));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == 'ta' ? 'இரத்த தான மையம்' : 'Blood Donation Hub'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/blood-donation/register'),
            icon: const Icon(Icons.volunteer_activism, color: Colors.white),
            label: Text(
              _lang == 'ta' ? 'பதிவு' : 'Register',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _EmergencyBanner(),
          _FilterRow(
            groups: _groups,
            selected: _selectedGroup,
            onSelect: _search,
          ),
          Expanded(
            child: BlocConsumer<BloodDonorBloc, BloodDonorState>(
              listener: (context, state) {
                if (state is BloodDonorContactRevealed) {
                  Navigator.of(context).pop();
                  _showContactSheet(context, state);
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
              builder: (context, state) {
                if (state is BloodDonorLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is BloodDonorSearchSuccess) {
                  if (state.donors.isEmpty) {
                    return _EmptyDonors(group: _selectedGroup);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.donors.length,
                    itemBuilder: (context, i) => _DonorCard(
                      donor: state.donors[i],
                      onContact: () =>
                          _requestContact(context, state.donors[i]),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSheet(BuildContext context, BloodDonorContactRevealed state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Contact Donor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(state.phoneNumber, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPhone(state.phoneNumber),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchWhatsApp(state.whatsappLink),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: const [
          Icon(Icons.bloodtype, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Emergency? All donors below are currently available.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final void Function(String?) onSelect;

  const _FilterRow({
    required this.groups,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...groups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(g),
                selected: selected == g,
                selectedColor: AppColors.accent.withOpacity(0.2),
                onSelected: (_) => onSelect(selected == g ? null : g),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  final BloodDonorEntity donor;
  final VoidCallback onContact;

  const _DonorCard({required this.donor, required this.onContact});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.accent,
              radius: 24,
              child: Text(
                donor.bloodGroup,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (donor.fullNameTa?.isNotEmpty == true
                            ? donor.fullNameTa!
                            : donor.fullNameEn) ??
                        '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (donor.geographyId != null)
                    Text(
                      donor.geographyId!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final lang = sl<LocalStorage>().getLang();
                return ElevatedButton(
                  onPressed: onContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    lang == 'ta' ? 'தொடர்பு' : 'Contact',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDonors extends StatelessWidget {
  final String? group;
  const _EmptyDonors({this.group});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bloodtype_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            group != null
                ? 'No $group donors available right now'
                : 'No donors available right now',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to register as a donor!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ContactDialog extends StatelessWidget {
  final BloodDonorEntity donor;
  final VoidCallback onConfirm;

  const _ContactDialog({required this.donor, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final lang = sl<LocalStorage>().getLang();
    return AlertDialog(
      title: Text(lang == 'ta' ? 'தொடர்பு கோரிக்கை' : 'Request Contact'),
      content: Text(
        'Your contact request for this ${donor.bloodGroup} donor will be logged. '
        'Their phone number will be revealed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lang == 'ta' ? 'ரத்து' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
          },
          child: Text(lang == 'ta' ? 'தொடர்பு காட்டு' : 'Reveal Contact'),
        ),
      ],
    );
  }
}
