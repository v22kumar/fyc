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
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/scale_on_tap.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class BloodDonationHubScreen extends StatefulWidget {
  const BloodDonationHubScreen({super.key});

  @override
  State<BloodDonationHubScreen> createState() => _BloodDonationHubScreenState();
}

class _BloodDonationHubScreenState extends State<BloodDonationHubScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedGroup;

  // Location filter (taluk dropdown + nearby toggle)
  List<_Taluk> _taluks = [];
  String? _selectedGeographyId;
  bool _nearby = false;

  @override
  void initState() {
    super.initState();
    context.read<BloodDonorBloc>().add(const BloodDonorSearchRequested());
    _loadTaluks();
  }

  Future<void> _loadTaluks() async {
    try {
      final res = await sl<ApiClient>()
          .dio
          .get(ApiConstants.geography, queryParameters: {'level': 'TALUK'});
      final list = (res.data as List<dynamic>)
          .map((e) => _Taluk(
                id: e['id'] as String,
                nameEn: (e['name_en'] as String?) ?? '',
                nameTa: (e['name_ta'] as String?) ?? '',
              ))
          .toList()
        ..sort((a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()));
      if (mounted) setState(() => _taluks = list);
    } catch (_) {/* keep dropdown empty on failure */}
  }

  void _runSearch() {
    context.read<BloodDonorBloc>().add(
          BloodDonorSearchRequested(
            bloodGroup: _selectedGroup,
            geographyId: _selectedGeographyId,
            nearby: _nearby && _selectedGeographyId != null,
          ),
        );
  }

  void _search(String? group) {
    setState(() => _selectedGroup = group);
    _runSearch();
  }

  void _selectLocation(String? geographyId) {
    setState(() {
      _selectedGeographyId = geographyId;
      if (geographyId == null) _nearby = false;
    });
    _runSearch();
  }

  void _toggleNearby(bool value) {
    setState(() => _nearby = value);
    _runSearch();
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

  Future<void> _launchSms(String phone) async {
    final uri = Uri.parse('sms:$phone');
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
        title: Text(trId('blood_donation_hub')),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/blood-donation/register'),
            icon: Icon(Icons.volunteer_activism, color: AppColors.background),
            label: Text(
              trId('register'),
              style: TextStyle(color: AppColors.background),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero photo banner (FYC blood drive)
          SizedBox(
            height: 132,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/blood_drive.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.primary.withOpacity(0.15)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.textPrimary.withOpacity(0.05),
                        AppColors.textPrimary.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Text(
                    trId('your_one_donation_can_save_up_to_3_lives'),
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _EmergencyBanner(onTap: () {
            context.read<BloodDonorBloc>().add(const BloodDonorSearchRequested());
          }),
          _FilterRow(
            groups: _groups,
            selected: _selectedGroup,
            onSelect: _search,
          ),
          _LocationFilter(
            taluks: _taluks,
            selectedId: _selectedGeographyId,
            nearby: _nearby,
            lang: _lang,
            onSelect: _selectLocation,
            onToggleNearby: _toggleNearby,
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
                      onRefresh: () async => context.read<BloodDonorBloc>().add(BloodDonorSearchRequested(bloodGroup: _selectedGroup, geographyId: _selectedGeographyId, nearby: _nearby && _selectedGeographyId != null)),
                      child: ListView(children: [_EmptyDonors(group: _selectedGroup)]),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => context.read<BloodDonorBloc>().add(BloodDonorSearchRequested(bloodGroup: _selectedGroup, geographyId: _selectedGeographyId, nearby: _nearby && _selectedGeographyId != null)),
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: state.donors.length,
                      itemBuilder: (context, i) => _DonorCard(
                        donor: state.donors[i],
                        onContact: () =>
                            _requestContact(context, state.donors[i]),
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
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
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trId('contact_donor'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(state.phoneNumber, style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchPhone(state.phoneNumber),
                    icon: Icon(Icons.call, color: AppColors.background),
                    label: Text(trId('call_2'), style: TextStyle(color: AppColors.background)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchSms(state.phoneNumber),
                    icon: Icon(Icons.sms_outlined),
                    label: Text(trId('message')),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchWhatsApp(state.whatsappLink),
                icon: Icon(Icons.chat, color: AppColors.background),
                label: Text(trId('whatsapp'), style: TextStyle(color: AppColors.background)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
              ),
            ),
            SizedBox(height: 8),
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
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Rose is the app's single blood/urgency (danger) role — the banner
          // used off-palette #DC2626/#EF4444 while the chips used the rose
          // accent, so this life-critical screen showed two different reds.
          gradient: LinearGradient(
            colors: [AppColors.accent, Color(0xFFFB7185)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.emergency, color: AppColors.background, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trId('emergency_blood_needed'),
                    style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    trId('tap_to_alert_all_eligible_donors_in_your'),
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.background),
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
          padding: EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(text),
            selected: sel,
            onSelected: (_) => onTap(),
            labelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: sel ? AppColors.background : AppColors.accent,
            ),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.accent.withOpacity(0.10),
            shape: StadiumBorder(side: BorderSide(color: AppColors.accent.withOpacity(0.35))),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            showCheckmark: false,
          ),
        );
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          chip(trId('all'), selected == null, () => onSelect(null)),
          ...groups.map((g) => chip(g, selected == g, () => onSelect(selected == g ? null : g))),
        ],
      ),
    );
  }
}

class _Taluk {
  final String id;
  final String nameEn;
  final String nameTa;
  const _Taluk({required this.id, required this.nameEn, required this.nameTa});
}

class _LocationFilter extends StatelessWidget {
  final List<_Taluk> taluks;
  final String? selectedId;
  final bool nearby;
  final String lang;
  final void Function(String?) onSelect;
  final void Function(bool) onToggleNearby;

  const _LocationFilter({
    required this.taluks,
    required this.selectedId,
    required this.nearby,
    required this.lang,
    required this.onSelect,
    required this.onToggleNearby,
  });

  @override
  Widget build(BuildContext context) {
    final ta = lang == 'ta';
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: selectedId,
                      hint: Text(trId('all_locations'),
                          style: TextStyle(fontSize: 14, color: context.cTextSecondary)),
                      icon: Icon(Icons.expand_more, color: context.cTextSecondary),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(trId('all_locations'),
                              style: TextStyle(fontSize: 14)),
                        ),
                        ...taluks.map((t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(ta ? (t.nameTa.isNotEmpty ? t.nameTa : t.nameEn) : t.nameEn,
                                  style: TextStyle(fontSize: 14)),
                            )),
                      ],
                      onChanged: onSelect,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (selectedId != null)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: nearby,
                    onChanged: (v) => onToggleNearby(v ?? false),
                    visualDensity: VisualDensity.compact,
                    activeColor: AppColors.primary,
                  ),
                  Text(trId('include_nearby_areas'),
                      style: TextStyle(fontSize: 13, color: context.cText)),
                ],
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
    final lang = sl<LocalStorage>().getLang();
    final isVerified = donor.phoneNumber != null && donor.phoneNumber!.isNotEmpty;

    return ScaleOnTap(
      onTap: onContact,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
          border: Border.all(color: context.cBorder, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent.withOpacity(0.12),
                radius: 28,
                child: Text(
                  donor.bloodGroup,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              SizedBox(width: 14),
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
                          SizedBox(width: 6),
                          Tooltip(
                            message: trId('verified_member'),
                            child: Icon(Icons.verified, size: 18, color: Color(0xFF10B981)),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 15, color: context.cTextSecondary),
                        SizedBox(width: 4),
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
                    // Directory contacts imported from Friends2Support are
                    // labelled so they read as a donor listing, not an app member.
                    if (donor.isImported) ...[
                      SizedBox(height: 7),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF0B44A)),
                        ),
                        child: Text(
                          trId('friends2support'),
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  // Contact is the one action on a donor card — it reads as
                  // the CTA in mint (the system's single call-to-action colour),
                  // not navy structure.
                  color: AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call, size: 15, color: AppColors.primaryLight),
                    SizedBox(width: 5),
                    Text(
                      trId('contact'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
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
          Image.asset(
            'assets/illustrations/empty_donors.png',
            width: 150,
            height: 150,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.favorite_border, size: 64, color: AppColors.textSecondary),
          ),
          SizedBox(height: 16),
          Text(
            group != null
                ? tr(en: 'No donors found', ta: 'இப்போது $group கொடையாளர்கள் இல்லை', hi: 'अभी $group दाता नहीं मिले', ml: 'ഇപ്പോൾ $group ദാതാക്കളെ കണ്ടെത്തിയില്ല')
                : trId('no_donors_found'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.cText),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              trId('try_a_different_blood_group_or_be_the_fi'),
              style: TextStyle(color: context.cTextSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/blood-donation/register'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                trId('register_as_donor'),
                style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w600, fontSize: 14),
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
      title: Text(trId('request_contact')),
      content: Text(
        tr(
          en: 'Your contact request for this ${donor.bloodGroup} donor will be logged. Their phone number will be revealed.',
          ta: 'இந்த ${donor.bloodGroup} கொடையாளருக்கான உங்கள் தொடர்பு கோரிக்கை பதிவு செய்யப்படும். அவர்களின் தொலைபேசி எண் வெளிப்படுத்தப்படும்.',
          hi: 'इस ${donor.bloodGroup} दाता के लिए आपका संपर्क अनुरोध दर्ज किया जाएगा। उनका फ़ोन नंबर प्रकट किया जाएगा।',
          ml: 'ഈ ${donor.bloodGroup} ദാതാവിനായുള്ള നിങ്ങളുടെ ബന്ധപ്പെടൽ അഭ്യർത്ഥന രേഖപ്പെടുത്തും. അവരുടെ ഫോൺ നമ്പർ വെളിപ്പെടുത്തും.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(trId('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
          },
          child: Text(trId('reveal_contact')),
        ),
      ],
    );
  }
}
