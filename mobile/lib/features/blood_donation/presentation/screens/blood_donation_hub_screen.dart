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
import '../../../../core/widgets/scale_on_tap.dart';
import '../../../../core/widgets/shimmer_loader.dart';

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
          _EmergencyBanner(onTap: () {
            context.read<BloodDonorBloc>().add(const BloodDonorSearchRequested());
          }),
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
                  return const ShimmerCardList();
                }
                if (state is BloodDonorSearchSuccess) {
                  if (state.donors.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => context.read<BloodDonorBloc>().add(BloodDonorSearchRequested(bloodGroup: _selectedGroup)),
                      child: ListView(children: [_EmptyDonors(group: _selectedGroup)]),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => context.read<BloodDonorBloc>().add(BloodDonorSearchRequested(bloodGroup: _selectedGroup)),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.donors.length,
                      itemBuilder: (context, i) => _DonorCard(
                        donor: state.donors[i],
                        onContact: () =>
                            _requestContact(context, state.donors[i]),
                      ),
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
  final VoidCallback onTap;
  const _EmergencyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = sl<LocalStorage>().getLang();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'ta' ? 'அவசர இரத்தம் தேவையா?' : 'Emergency Blood Needed?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    lang == 'ta'
                        ? 'உங்கள் பகுதியில் உள்ள தகுதியான கொடையாளர்களை எச்சரிக்க தட்டவும்'
                        : 'Tap to alert all eligible donors in your area',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
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
    final lang = sl<LocalStorage>().getLang();
    Widget chip(String text, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(text),
            selected: sel,
            onSelected: (_) => onTap(),
            labelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.accent,
            ),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.accent.withOpacity(0.10),
            shape: StadiumBorder(side: BorderSide(color: AppColors.accent.withOpacity(0.35))),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            showCheckmark: false,
          ),
        );
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          chip(lang == 'ta' ? 'அனைத்தும்' : 'All', selected == null, () => onSelect(null)),
          ...groups.map((g) => chip(g, selected == g, () => onSelect(selected == g ? null : g))),
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
    final lang = sl<LocalStorage>().getLang();
    final isVerified = donor.phoneNumber != null && donor.phoneNumber!.isNotEmpty;

    return ScaleOnTap(
      onTap: onContact,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
          border: Border.all(color: context.cBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent.withOpacity(0.12),
                radius: 28,
                child: Text(
                  donor.bloodGroup,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            donor.displayName(lang),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              height: 1.2,
                              color: context.cText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: lang == 'ta' ? 'சரிபார்க்கப்பட்ட உறுப்பினர்' : 'Verified Member',
                            child: const Icon(Icons.verified, size: 18, color: Color(0xFF10B981)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 15, color: context.cTextSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            donor.displayLocation(lang),
                            style: TextStyle(
                              color: context.cTextSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call, size: 15, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      lang == 'ta' ? 'தொடர்பு' : 'Contact',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final lang = sl<LocalStorage>().getLang();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            group != null
                ? (lang == 'ta' ? 'இப்போது $group கொடையாளர்கள் இல்லை' : 'No donors found')
                : (lang == 'ta' ? 'கொடையாளர்கள் இல்லை' : 'No donors found'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.cText),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              lang == 'ta'
                  ? 'வேறு இரத்த வகையை முயற்சிக்கவும் அல்லது உங்கள் பகுதியில் முதல் கொடையாளராக பதிவு செய்யுங்கள்'
                  : 'Try a different blood group or be the first to register as a donor in your area',
              style: TextStyle(color: context.cTextSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/blood-donation/register'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                lang == 'ta' ? 'கொடையாளராக பதிவு செய்யுங்கள்' : 'Register as Donor',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
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
