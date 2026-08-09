import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/blood_donor_entity.dart';
import '../widgets/need_blood_panel.dart';
import '../widgets/donor_card.dart';
import '../../../auth/presentation/widgets/sign_in_sheet.dart';
import '../widgets/ask_donor_sheet.dart';
import '../widgets/donors_around_map.dart';
import '../../../../core/design_system/tokens.dart';
import '../bloc/blood_donor_bloc.dart';
import '../bloc/blood_donor_event.dart';
import '../bloc/blood_donor_state.dart';
import 'blood_request_flow.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/location/member_location.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class BloodDonationHubScreen extends StatefulWidget {
  const BloodDonationHubScreen({super.key});

  @override
  State<BloodDonationHubScreen> createState() => _BloodDonationHubScreenState();
}

class _BloodDonationHubScreenState extends State<BloodDonationHubScreen> {
  String get _lang => trLang();

  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedGroup;

  // Location filter (taluk dropdown + nearby toggle)
  List<_Taluk> _taluks = [];
  String? _selectedGeographyId;
  bool _nearby = false;

  /// True once the list is ordered by real distance rather than by taluk.
  bool _rankedByDistance = false;

  /// Where we found the member, kept so a filter tap does not throw away the
  /// ranking. Choosing "O+" is narrowing the question, not abandoning "near me".
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    // Show something immediately, then improve it. Asking for location first
    // would leave the screen empty behind a permission dialog — at exactly the
    // moment the member is least willing to wait.
    context.read<BloodDonorBloc>().add(
        const BloodDonorSearchRequested(source: 'club'));
    _loadTaluks();
    // After the first frame, so the disclosure sheet slides up over a screen
    // that is already there. Explaining why we want a location on top of a
    // blank page is not an explanation, it is an interruption.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rankByDistance();
    });
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
    // Distance ranking survives a blood-group filter. Only picking a taluk
    // means "show me that area instead of around me", so only that drops it.
    if (_rankedByDistance && _selectedGeographyId == null) {
      context.read<BloodDonorBloc>().add(BloodDonorNearbyRequested(
            lat: _myLat!,
            lng: _myLng!,
            bloodGroup: _selectedGroup == 'All' ? null : _selectedGroup,
          ));
      return;
    }
    context.read<BloodDonorBloc>().add(
          BloodDonorSearchRequested(
            bloodGroup: _selectedGroup,
            geographyId: _selectedGeographyId,
            nearby: _nearby && _selectedGeographyId != null,
            source: 'club',
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

  /// Ask the phone where it is, once, and rank by that.
  ///
  /// Best-effort by design. Location can be off, refused, or slow, and none of
  /// those should leave a member staring at nothing — the taluk search is still
  /// there and still works, it just cannot answer "who is nearest".
  ///
  /// The same fix does double duty: it ranks this member's screen, and it is
  /// reported back as their own last-seen position. This is the only moment the
  /// app collects one, which is exactly the bargain the disclosure describes —
  /// looking for a donor is what puts you on the map for the next person.
  Future<void> _rankByDistance() async {
    final pos = await MemberLocation.forRanking(context);
    if (pos == null || !mounted) return;
    unawaited(MemberLocation.report(pos));
    setState(() {
      _rankedByDistance = true;
      _myLat = pos.latitude;
      _myLng = pos.longitude;
    });
    _runSearch();
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

  /// Everyone standing on one pin, as cards.
  ///
  /// One donor still gets a sheet rather than jumping straight to the contact
  /// dialog: tapping a dot on a map should show you who it is before it asks
  /// you to commit to anything.
  void _showCluster(BuildContext context, List<BloodDonorEntity> cell) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(DSSpacing.md),
          children: [
            Text(
              trId('donors_here_n', {'n': cell.length}),
              style: Theme.of(sheetContext).textTheme.titleSmall,
            ),
            SizedBox(height: DSSpacing.sm),
            for (final d in cell)
              DonorCard(
                donor: d,
                lang: _lang,
                onContact: () {
                  Navigator.of(sheetContext).pop();
                  _requestContact(context, d);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Ask this donor, rather than being handed their number.
  ///
  /// The old flow was a confirmation dialog and then a phone number, and from
  /// there it was the requester's problem — dialling strangers one after
  /// another to discover what the app already knew. Now the donor is asked, and
  /// their number arrives with the yes. See [showAskDonorSheet].
  Future<void> _requestContact(
      BuildContext context, BloodDonorEntity donor) async {
    // Asking somebody for blood is an act with a name on it.
    if (!await SignInSheet.ensure(context) || !context.mounted) return;
    showAskDonorSheet(
      context,
      donor: donor,
      lang: _lang,
      // The escape hatch, kept because an unanswered notification cannot be the
      // only road out of an emergency.
      onShowNumberInstead: () => showDialog(
        context: context,
        builder: (_) => _ContactDialog(
          donor: donor,
          onConfirm: () {
            context
                .read<BloodDonorBloc>()
                .add(BloodDonorContactRequested(donor.id));
          },
        ),
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
            key: const ValueKey('donor-register'),
            onPressed: () async {
              // Offering to donate puts a member's name and number in front of
              // strangers — that is the moment identity is needed, not before.
              if (await SignInSheet.ensure(context) && context.mounted) {
                context.push('/blood-donation/register');
              }
            },
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
          // The map leads, because "is anybody near me?" is the first question
          // and a count of dots answers it before a single name is read. It was
          // a route behind an icon, which meant it answered nothing.
          BlocBuilder<BloodDonorBloc, BloodDonorState>(
            builder: (context, state) {
              final donors = state is BloodDonorSearchSuccess
                  ? state.donors
                  : const <BloodDonorEntity>[];
              return DonorsAroundMap(
                donors: donors,
                me: _myLat == null ? null : LatLng(_myLat!, _myLng!),
                onTapCluster: (cell) => _showCluster(context, cell),
              );
            },
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
                final donors = state is BloodDonorSearchSuccess
                    ? state.donors
                    : const <BloodDonorEntity>[];
                return RefreshIndicator(
                  onRefresh: () async => _runSearch(),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        DSSpacing.md, DSSpacing.sm, DSSpacing.md, DSSpacing.xl),
                    children: [
                      // The request is the screen's purpose, so it sits
                      // directly under the map — the two together say "these
                      // people are here, and here is how to reach them".
                      NeedBloodPanel(
                        onRaiseRequest: () async {
                          if (!await SignInSheet.ensure(context)) return;
                          if (!context.mounted) return;
                          showRaiseRequestSheet(
                            context,
                            initialGroup:
                                _selectedGroup == 'All' ? null : _selectedGroup,
                          );
                        },
                      ),
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
                      if (state is BloodDonorLoading)
                        const ShimmerCardList()
                      else if (donors.isEmpty)
                        _EmptyDonors(group: _selectedGroup)
                      else ...[
                        _DonorSectionHeading(
                          imported: false,
                          ranked: _rankedByDistance,
                        ),
                        for (final (i, d) in donors.indexed)
                          DonorCard(
                            // Stable handles so the screenshot harness can open
                            // the sheets behind these rows.
                            key: ValueKey('donor-card-$i'),
                            donor: d,
                            lang: _lang,
                            onContact: () => _requestContact(context, d),
                          ),
                      ],
                      // The wider directory is a door, not a section. Mixing
                      // strangers' phone numbers into the list above promised
                      // the same thing for both.
                      SizedBox(height: DSSpacing.md),
                      _WiderDirectoryCard(
                        onOpen: () =>
                            context.push('/blood-donation/directory'),
                      ),
                    ],
                  ),
                );
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
            Text(
              trId('contact_donor'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(state.phoneNumber, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchSms(state.phoneNumber),
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(trId('message')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
    final lang = trLang();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Rose is the app's single blood/urgency (danger) role — the banner
          // used off-palette #DC2626/#EF4444 while the chips used the rose
          // accent, so this life-critical screen showed two different reds.
          gradient: LinearGradient(
            colors: [AppColors.accent, const Color(0xFFFB7185)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.emergency, color: AppColors.background, size: 28),
            const SizedBox(width: 12),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    final lang = trLang();
    Widget chip(String text, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
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
            backgroundColor: AppColors.accent.withValues(alpha: 0.10),
            shape: StadiumBorder(side: BorderSide(color: AppColors.accent.withValues(alpha: 0.35))),
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              style: const TextStyle(fontSize: 14)),
                        ),
                        ...taluks.map((t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(ta ? (t.nameTa.isNotEmpty ? t.nameTa : t.nameEn) : t.nameEn,
                                  style: const TextStyle(fontSize: 14)),
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
              padding: const EdgeInsets.only(top: 2),
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

class _EmptyDonors extends StatelessWidget {
  final String? group;
  const _EmptyDonors({this.group});

  @override
  Widget build(BuildContext context) {
    final lang = trLang();
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
          const SizedBox(height: 16),
          Text(
            group != null
                ? tr(en: 'No donors found', ta: 'இப்போது $group கொடையாளர்கள் இல்லை', hi: 'अभी $group दाता नहीं मिले', ml: 'ഇപ്പോൾ $group ദാതാക്കളെ കണ്ടെത്തിയില്ല')
                : trId('no_donors_found'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.cText),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              trId('try_a_different_blood_group_or_be_the_fi'),
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
    final lang = trLang();
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


/// Which pile these donors are in, said once above the run rather than
/// repeated as a badge on every row.
class _DonorSectionHeading extends StatelessWidget {
  const _DonorSectionHeading({required this.imported, this.ranked = false});

  final bool imported;

  /// Whether this run of cards is ordered by distance from the member.
  ///
  /// A sorted list that does not say it is sorted reads as an arbitrary one:
  /// the first name looks like the first name, not the nearest person.
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DSSpacing.sm, bottom: DSSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            imported
                ? trId('wider_directory')
                : (ranked ? trId('nearest_to_you') : trId('club_donors')),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (imported)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                trId('wider_directory_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// The way into the Friends2Support directory.
///
/// A door rather than a section. Those contacts have no location, no account
/// and no way of being asked — putting them under a heading in the list above
/// made a stranger's phone number look like a neighbour who had volunteered.
/// Here they are one deliberate tap away, described honestly.
class _WiderDirectoryCard extends StatelessWidget {
  const _WiderDirectoryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DSRadius.card),
        side: BorderSide(color: context.cBorder),
      ),
      child: ListTile(
        onTap: onOpen,
        contentPadding: EdgeInsets.all(DSSpacing.md),
        leading: Icon(Icons.contact_phone_outlined,
            color: context.cTextSecondary),
        title: Text(trId('wider_directory'),
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            trId('wider_directory_note'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.cTextSecondary),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: context.cTextSecondary),
      ),
    );
  }
}
