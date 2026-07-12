import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/event_entity.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/success_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'event_create_screen.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<EventBloc>().add(const EventFetchRequested());
  }

  void _refresh() => context.read<EventBloc>().add(const EventFetchRequested());

  bool get _canCreate {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EventCreateScreen()),
    );
    if (created == true && mounted) {
      _refresh();
      SuccessSnackbar.show(
        context,
        title: tr(en: 'Created', ta: 'உருவாக்கப்பட்டது', hi: 'बन गया', ml: 'സൃഷ്ടിച്ചു'),
        message: tr(en: 'Event created', ta: 'நிகழ்வு உருவாக்கப்பட்டது',
            hi: 'कार्यक्रम बन गया', ml: 'പരിപാടി സൃഷ്ടിച്ചു'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = _lang == 'ta';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        floatingActionButton: _canCreate
            ? FloatingActionButton.extended(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: Text(tr(en: 'New', ta: 'புதிது', hi: 'नया', ml: 'പുതിയത്')),
              )
            : null,
        appBar: AppBar(
          title: Text(tr(en: 'Events', ta: 'நிகழ்வுகள்', hi: 'कार्यक्रम', ml: 'പരിപാടികൾ')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr(en: 'All', ta: 'அனைத்தும்', hi: 'सभी', ml: 'എല്ലാം')),
              Tab(text: tr(en: 'Upcoming', ta: 'வரவிருக்கும்', hi: 'आगामी', ml: 'വരാനിരിക്കുന്നവ')),
              Tab(text: tr(en: 'Past', ta: 'கடந்தவை', hi: 'पिछले', ml: 'കഴിഞ്ഞവ')),
              Tab(text: tr(en: 'My Events', ta: 'என் நிகழ்வுகள்', hi: 'मेरे कार्यक्रम', ml: 'എന്റെ പരിപാടികൾ')),
            ],
          ),
        ),
        body: BlocConsumer<EventBloc, EventState>(
          listener: (context, state) {
            if (state is EventCheckinSuccess) {
              SuccessSnackbar.show(
                context,
                title: tr(en: 'Success', ta: 'வெற்றி', hi: 'सफलता', ml: 'വിജയം'),
                message: state.message,
              );
              _refresh();
            }
            if (state is EventFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.accent,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is EventLoading || state is EventInitial) {
              return const ShimmerCardList();
            }
            if (state is EventFailure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: context.cTextSecondary),
                    const SizedBox(height: 12),
                    Text(state.message),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சிக்கவும்', hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
                    ),
                  ],
                ),
              );
            }
            if (state is EventLoaded) {
              final all = state.events;
              final upcoming = all.where((e) => e.isUpcoming || e.isOngoing).toList();
              final past = all.where((e) => !e.isUpcoming && !e.isOngoing).toList();
              return TabBarView(
                children: [
                  _list(all),
                  _list(upcoming),
                  _list(past),
                  _myEvents(),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _list(List<EventEntity> events) {
    final ta = _lang == 'ta';
    if (events.isEmpty) {
      return EmptyState(
        icon: Icons.event_rounded,
        imageAsset: 'assets/illustrations/empty_events.png',
        title: tr(en: 'No Events Right Now', ta: 'தற்போது நிகழ்வுகள் இல்லை', hi: 'अभी कोई कार्यक्रम नहीं', ml: 'ഇപ്പോൾ പരിപാടികളൊന്നുമില്ല'),
        message: tr(
            en: 'Check back later for upcoming community events and initiatives.',
            ta: 'சமூக நிகழ்வுகளுக்குப் பிறகு மீண்டும் பார்க்கவும்.',
            hi: 'आगामी सामुदायिक कार्यक्रमों और पहलों के लिए बाद में फिर देखें।',
            ml: 'വരാനിരിക്കുന്ന കമ്മ്യൂണിറ്റി പരിപാടികൾക്കും സംരംഭങ്ങൾക്കും പിന്നീട് വീണ്ടും പരിശോധിക്കുക.'),
        buttonText: tr(en: 'Refresh', ta: 'புதுப்பிக்கவும்', hi: 'ताज़ा करें', ml: 'പുതുക്കുക'),
        onAction: _refresh,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...events.asMap().entries.map((entry) => FadeSlideIn(
                delay: Duration(milliseconds: (entry.key * 45).clamp(0, 400)),
                child: _EventCard(
                  event: entry.value,
                  lang: _lang,
                  onCheckin: entry.value.isOngoing
                      ? () => context
                          .read<EventBloc>()
                          .add(EventCheckinRequested(entry.value.id))
                      : null,
                  onRegister: entry.value.isUpcoming
                      ? () => _openRegister(entry.value)
                      : null,
                ),
              )),
        ],
      ),
    );
  }

  Widget _myEvents() {
    final ta = _lang == 'ta';
    return EmptyState(
      icon: Icons.confirmation_number_rounded,
      title: tr(en: 'Your registrations appear here', ta: 'பதிவுகள் இங்கே தோன்றும்', hi: 'आपके पंजीकरण यहाँ दिखेंगे', ml: 'നിങ്ങളുടെ രജിസ്ട്രേഷനുകൾ ഇവിടെ കാണാം'),
      message: tr(
          en: 'Events you register for or check in to will show up here.',
          ta: 'நீங்கள் பதிவு செய்யும் நிகழ்வுகள் இங்கே காண்பிக்கப்படும்.',
          hi: 'आप जिन कार्यक्रमों के लिए पंजीकरण या चेक-इन करेंगे, वे यहाँ दिखेंगे।',
          ml: 'നിങ്ങൾ രജിസ്റ്റർ ചെയ്യുകയോ ചെക്ക്-ഇൻ ചെയ്യുകയോ ചെയ്യുന്ന പരിപാടികൾ ഇവിടെ കാണാം.'),
    );
  }

  void _openRegister(EventEntity event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventRegisterSheet(event: event, lang: _lang),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventEntity event;
  final String lang;
  final VoidCallback? onCheckin;
  final VoidCallback? onRegister;

  const _EventCard({
    required this.event,
    required this.lang,
    this.onCheckin,
    this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('d MMM yyyy · h:mm a');
    final isPast = !event.isUpcoming && !event.isOngoing;
    final ta = lang == 'ta';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
        border: Border.all(color: context.cBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with date badge overlay
          Stack(
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: ColorFiltered(
                  colorFilter: isPast
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
                      ? Image.network(
                          event.bannerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/event_placeholder.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/event_placeholder.png',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Positioned(left: 12, top: 12, child: _DateBadge(date: event.eventStart)),
              if (event.isOngoing)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayTitle(lang),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.cText),
                ),
                const SizedBox(height: 6),
                Text(
                  event.displayDescription(lang),
                  style: TextStyle(color: context.cTextSecondary, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: context.cTextSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        timeFmt.format(event.eventStart.toLocal()),
                        style: TextStyle(
                            fontSize: 12, color: context.cTextSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _GoingRow(count: event.registrationCount, lang: lang),
                    const Spacer(),
                    if (onRegister != null)
                      ElevatedButton(
                        onPressed: onRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(tr(en: 'Register Now', ta: 'பதிவு செய்க', hi: 'अभी पंजीकरण करें', ml: 'ഇപ്പോൾ രജിസ്റ്റർ ചെയ്യുക'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      )
                    else if (onCheckin != null)
                      ElevatedButton.icon(
                        onPressed: onCheckin,
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: Text(tr(en: 'Check In', ta: 'செக்-இன்', hi: 'चेक इन', ml: 'ചെക്ക് ഇൻ')),
                      )
                    else
                      Text(tr(en: 'Event ended', ta: 'நிகழ்வு முடிந்தது', hi: 'कार्यक्रम समाप्त', ml: 'പരിപാടി അവസാനിച്ചു'),
                          style: TextStyle(
                              color: context.cTextSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Date badge: month abbreviation over day number.
class _DateBadge extends StatelessWidget {
  final DateTime date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final d = date.toLocal();
    final month = DateFormat('MMM').format(d).toUpperCase();
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(month,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${d.day}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.cText)),
          ),
        ],
      ),
    );
  }
}

/// Decorative stacked avatars + "N Going" label.
class _GoingRow extends StatelessWidget {
  final int count;
  final String lang;
  const _GoingRow({required this.count, required this.lang});

  @override
  Widget build(BuildContext context) {
    final ta = lang == 'ta';
    final shown = count.clamp(0, 3);
    const colors = [
      Color(0xFF8B5CF6),
      Color(0xFF2563EB),
      Color(0xFF16A34A),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0)
          SizedBox(
            width: shown == 0 ? 0 : (18.0 * shown + 8),
            height: 28,
            child: Stack(
              children: [
                for (int i = 0; i < shown; i++)
                  Positioned(
                    left: i * 18.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cSurface, width: 2),
                      ),
                      child: const Icon(Icons.person,
                          size: 15, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        if (count > 0) const SizedBox(width: 6),
        Text(
          count > 0
              ? tr(en: '$count Going', ta: '$count பேர் வருகிறார்கள்', hi: '$count लोग आ रहे हैं', ml: '$count പേർ വരുന്നു')
              : tr(en: 'Be the first', ta: 'முதலில் பதிவு செய்க', hi: 'पहले बनें', ml: 'ആദ്യത്തെയാളാകൂ'),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.cTextSecondary),
        ),
      ],
    );
  }
}

/// Bottom sheet to register (RSVP) for an event.
class _EventRegisterSheet extends StatefulWidget {
  final EventEntity event;
  final String lang;
  const _EventRegisterSheet({required this.event, required this.lang});

  @override
  State<_EventRegisterSheet> createState() => _EventRegisterSheetState();
}

class _EventRegisterSheetState extends State<_EventRegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _mobile = TextEditingController();
  String _gender = 'Male';
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ta = widget.lang == 'ta';
    try {
      await sl<ApiClient>().dio.post(
        '${ApiConstants.events}/${widget.event.id}/register',
        data: {
          'name': _name.text.trim(),
          'age': int.tryParse(_age.text.trim()) ?? 0,
          'gender': _gender,
          'mobile_number': _mobile.text.trim(),
          'competition_category': <String>[],
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      SuccessSnackbar.show(
        context,
        title: tr(en: 'Registered', ta: 'பதிவு வெற்றி', hi: 'पंजीकृत', ml: 'രജിസ്റ്റർ ചെയ്തു'),
        message: tr(
            en: 'You are registered for this event.',
            ta: 'நிகழ்வுக்கு வெற்றிகரமாக பதிவு செய்யப்பட்டது.',
            hi: 'आप इस कार्यक्रम के लिए पंजीकृत हैं।',
            ml: 'നിങ്ങൾ ഈ പരിപാടിക്ക് രജിസ്റ്റർ ചെയ്തിട്ടുണ്ട്.'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
              en: 'Registration failed. Please try again.',
              ta: 'பதிவு தோல்வி. மீண்டும் முயற்சிக்கவும்.',
              hi: 'पंजीकरण विफल। कृपया पुनः प्रयास करें।',
              ml: 'രജിസ്ട്രേഷൻ പരാജയപ്പെട്ടു. വീണ്ടും ശ്രമിക്കുക.')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = widget.lang == 'ta';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.cBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                tr(en: 'Register for Event', ta: 'நிகழ்வுக்கு பதிவு', hi: 'कार्यक्रम के लिए पंजीकरण', ml: 'പരിപാടിക്ക് രജിസ്റ്റർ ചെയ്യുക'),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.cText),
              ),
              const SizedBox(height: 2),
              Text(
                widget.event.displayTitle(widget.lang),
                style: TextStyle(fontSize: 13, color: context.cTextSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: tr(en: 'Full Name', ta: 'பெயர்', hi: 'पूरा नाम', ml: 'പൂർണ്ണ നാമം'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? tr(en: 'Enter your name', ta: 'பெயரை உள்ளிடவும்', hi: 'अपना नाम दर्ज करें', ml: 'നിങ്ങളുടെ പേര് നൽകുക')
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr(en: 'Age', ta: 'வயது', hi: 'आयु', ml: 'വയസ്സ്'),
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) {
                          return tr(en: 'Valid age', ta: 'சரியான வயது', hi: 'मान्य आयु', ml: 'സാധുവായ വയസ്സ്');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: tr(en: 'Gender', ta: 'பாலினம்', hi: 'लिंग', ml: 'ലിംഗം'),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'Male',
                            child: Text(tr(en: 'Male', ta: 'ஆண்', hi: 'पुरुष', ml: 'പുരുഷൻ'))),
                        DropdownMenuItem(
                            value: 'Female',
                            child: Text(tr(en: 'Female', ta: 'பெண்', hi: 'महिला', ml: 'സ്ത്രീ'))),
                        DropdownMenuItem(
                            value: 'Other',
                            child: Text(tr(en: 'Other', ta: 'பிற', hi: 'अन्य', ml: 'മറ്റുള്ളവ'))),
                      ],
                      onChanged: (v) =>
                          setState(() => _gender = v ?? 'Male'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: tr(en: 'Mobile Number', ta: 'கைபேசி எண்', hi: 'मोबाइल नंबर', ml: 'മൊബൈൽ നമ്പർ'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length < 10) {
                    return tr(en: 'Valid mobile number', ta: 'சரியான எண்', hi: 'मान्य मोबाइल नंबर', ml: 'സാധുവായ മൊബൈൽ നമ്പർ');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(tr(en: 'Confirm Registration', ta: 'பதிவை உறுதிசெய்', hi: 'पंजीकरण की पुष्टि करें', ml: 'രജിസ്ട്രേഷൻ സ്ഥിരീകരിക്കുക'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
