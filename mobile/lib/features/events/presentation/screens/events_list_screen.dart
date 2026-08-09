import 'package:fyc_connect/features/auth/presentation/widgets/sign_in_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/entities/public_registrant.dart';
import '../../domain/repositories/event_repository.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/widgets/share_link_sheet.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/components/ds_tab_bar.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/success_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'event_create_screen.dart';
import 'event_registrations_screen.dart';

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
        title: trId('created'),
        message: trId('event_created'),
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
                label: Text(trId('new')),
              )
            : null,
        appBar: DSScreenHeader(
          title: trId('events'),
          bottom: DSTabBar(tabs: [
            trId('all'),
            trId('upcoming'),
            trId('past'),
            trId('my_events'),
          ]),
        ),
        body: BlocConsumer<EventBloc, EventState>(
          listener: (context, state) {
            if (state is EventCheckinSuccess) {
              SuccessSnackbar.show(
                context,
                title: trId('success'),
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
                      child: Text(trId('retry')),
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
        title: trId('no_events_right_now'),
        message: trId('check_back_later_for_upcoming_community'),
        buttonText: trId('refresh'),
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
                  isAdmin: _canCreate,
                  onDelete: _canCreate
                      ? () => _confirmDelete(context, entry.value.id)
                      : null,
                  onCheckin: entry.value.isOngoing
                      ? () => context
                          .read<EventBloc>()
                          .add(EventCheckinRequested(entry.value.id))
                      : null,
                  onRegister: _canRegister(entry.value)
                      ? () async {
                          // The registration form itself needs a member.
                          if (await SignInSheet.ensure(context) &&
                              context.mounted) {
                            _openRegister(entry.value);
                          }
                        }
                      : null,
                  onViewParticipants: entry.value.registrationEnabled
                      ? () => _openParticipants(entry.value)
                      : null,
                  onViewAdminRegistrations: _canCreate
                      ? () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EventRegistrationsScreen(
                              event: entry.value,
                              lang: _lang,
                              repo: context.read<EventRepository>(),
                            ),
                          ));
                        }
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
      title: trId('your_registrations_appear_here'),
      message: trId('events_you_register_for_or_check_in_to_w'),
    );
  }

  void _openRegister(EventEntity event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventRegisterSheet(
          event: event, lang: _lang, repo: context.read<EventRepository>()),
    );
  }

  /// Register only when the backend will accept it: not yet ended (multi-day
  /// competitions stay open while LIVE), registration enabled, and the
  /// deadline (if any) not yet passed — mirrors the server gates so a tap
  /// can't land on a guaranteed 400.
  bool _canRegister(EventEntity e) {
    final live = e.isUpcoming || e.isOngoing;
    if (!live || !e.registrationEnabled) return false;
    final deadline = e.registrationDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) return false;
    return true;
  }

  void _openParticipants(EventEntity event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventParticipantsSheet(event: event, lang: _lang),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String eventId) async {
    // The bloc outlives the dialog; the context may not.
    final bloc = context.read<EventBloc>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trId('delete_event')),
        content: Text(trId('this_will_hide_the_event_from_all_users')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(trId('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(trId('delete'), style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      bloc.add(EventDeleteRequested(eventId));
    }
  }
}

class _EventCard extends StatelessWidget {
  final EventEntity event;
  final String lang;
  final VoidCallback? onCheckin;
  final VoidCallback? onRegister;
  final VoidCallback? onDelete;
  final VoidCallback? onViewParticipants;
  final VoidCallback? onViewAdminRegistrations;
  final bool isAdmin;

  const _EventCard({
    required this.event,
    required this.lang,
    this.onCheckin,
    this.onRegister,
    this.onDelete,
    this.onViewParticipants,
    this.onViewAdminRegistrations,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('d MMM yyyy · h:mm a');
    final isPast = !event.isUpcoming && !event.isOngoing;
    final ta = lang == 'ta';
    
    final now = DateTime.now();
    String statusText = trId('upcoming_2');
    Color statusColor = AppColors.info;
    
    if (now.isAfter(event.eventEnd)) {
      statusText = trId('completed');
      statusColor = AppColors.textSecondary;
    } else if (now.isAfter(event.eventStart) && now.isBefore(event.eventEnd)) {
      statusText = trId('live');
      statusColor = AppColors.success;
    } else if (event.registrationDeadline != null && now.isAfter(event.registrationDeadline!)) {
      statusText = trId('closed');
      statusColor = AppColors.accent;
    } else if (event.maxParticipants != null && event.registrationCount >= event.maxParticipants!) {
      statusText = trId('closed');
      statusColor = AppColors.accent;
    }

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
                      ? ColorFilter.mode(AppColors.textSecondary, BlendMode.saturation)
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
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: AppColors.background,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.displayTitle(lang),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.cText),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (event.shortCode != null && event.shortCode!.isNotEmpty)
                          GestureDetector(
                            onTap: () => showShareLinkSheet(
                              context,
                              path: '/e/${event.shortCode}',
                              title: event.displayTitle(lang),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.qr_code_2, size: 20, color: Color(0xFF0B6E4F)),
                            ),
                          ),
                        if (isAdmin && onViewAdminRegistrations != null)
                          GestureDetector(
                            onTap: onViewAdminRegistrations,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.people_outline, size: 20, color: AppColors.info),
                            ),
                          ),
                        if (isAdmin && onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                            ),
                          ),
                      ],
                    ),
                  ],
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
                    GestureDetector(
                      onTap: onViewParticipants,
                      behavior: HitTestBehavior.opaque,
                      child:
                          _GoingRow(count: event.registrationCount, lang: lang),
                    ),
                    const Spacer(),
                    if (onRegister == null && onCheckin == null)
                      Text(statusText,
                          style: TextStyle(
                              color: context.cTextSecondary, fontSize: 12)),
                  ],
                ),
                // Register stays available while the event is upcoming OR live
                // (a multi-day competition accepts entries until it ends), so
                // both actions can coexist — a wrapping row keeps long Tamil
                // labels from overflowing.
                if (onRegister != null || onCheckin != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (onCheckin != null)
                          ElevatedButton.icon(
                            onPressed: onCheckin,
                            icon: const Icon(Icons.qr_code_scanner, size: 16),
                            label: Text(trId('check_in')),
                          ),
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
                            child: Text(trId('register_now'),
                                style: TextStyle(
                                    color: AppColors.background,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
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
                style: TextStyle(
                    color: AppColors.background,
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
                      child: Icon(Icons.person,
                          size: 15, color: AppColors.background),
                    ),
                  ),
              ],
            ),
          ),
        if (count > 0) const SizedBox(width: 6),
        Text(
          count > 0
              ? tr(en: '$count Going', ta: '$count பேர் வருகிறார்கள்', hi: '$count लोग आ रहे हैं', ml: '$count പേർ വരുന്നു')
              : trId('be_the_first'),
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
  final EventRepository repo;
  final EventEntity event;
  final String lang;
  const _EventRegisterSheet(
      {required this.event, required this.lang, required this.repo});

  @override
  State<_EventRegisterSheet> createState() => _EventRegisterSheetState();
}

class _EventRegisterSheetState extends State<_EventRegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dob = TextEditingController();
  String _gender = 'Male';
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _school = TextEditingController();
  String? _grade;
  final _memberId = TextEditingController();
  final _topic = TextEditingController();
  final _remarks = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    _mobile.dispose();
    _email.dispose();
    _address.dispose();
    _school.dispose();
    _memberId.dispose();
    _topic.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ta = widget.lang == 'ta';
    try {
      final categories = <String>[];
      if (widget.event.registrationType == 'Submission' && _topic.text.trim().isNotEmpty) {
        categories.add(_topic.text.trim());
      }
      await widget.repo.registerForEvent(
        widget.event.id,
        {
          'name': _name.text.trim(),
          'dob': DateTime.parse(_dob.text.trim()).toIso8601String(),
          'gender': _gender,
          'mobile_number': _mobile.text.trim(),
          'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
          'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
          'school_college': _school.text.trim(),
          'class_grade': _grade,
          'member_id': _memberId.text.trim().isEmpty ? null : _memberId.text.trim(),
          'competition_category': categories,
          'remarks': _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      SuccessSnackbar.show(
        context,
        title: trId('registered'),
        message: trId('you_are_registered_for_this_event'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Surface the server's reason (deadline passed, already registered,
      // full capacity…) instead of a blind generic failure.
      String? detail;
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] is String) {
          detail = data['detail'] as String;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detail ??
              trId('registration_failed_please_try_again')),
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
          child: SingleChildScrollView(
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
                trId('register_for_event'),
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
                  labelText: trId('full_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? trId('enter_your_name')
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dob,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: trId('dob'),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          _dob.text = DateFormat('yyyy-MM-dd').format(date);
                        }
                      },
                      validator: (v) => (v == null || v.trim().isEmpty) ? '*' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: trId('gender'),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'Male',
                            child: Text(trId('male'))),
                        DropdownMenuItem(
                            value: 'Female',
                            child: Text(trId('female'))),
                        DropdownMenuItem(
                            value: 'Other',
                            child: Text(trId('other'))),
                      ],
                      onChanged: (v) =>
                          setState(() => _gender = v ?? 'Male'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: trId('mobile'),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isNotEmpty && s.length < 10) return '*';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: trId('email_optional'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _school,
                decoration: InputDecoration(
                  labelText: trId('school_college'),
                  prefixIcon: const Icon(Icons.school_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '*' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _grade,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: trId('class_grade'),
                  hintText: trId('select'),
                  prefixIcon: const Icon(Icons.grade_outlined),
                ),
                // Full range independent of any category: pre-KG to college & above.
                items: const [
                  'Pre-KG', 'LKG', 'UKG',
                  'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6',
                  'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12',
                  'College', 'Above / Open',
                ].map((val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _grade = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: trId('address_optional'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memberId,
                decoration: InputDecoration(
                  labelText: trId('member_id_optional'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              if (widget.event.registrationType == 'Submission') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _topic,
                  decoration: InputDecoration(
                    labelText: trId('topic'),
                    prefixIcon: const Icon(Icons.subject),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? trId('enter_topic')
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarks,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: trId('remarks_optional'),
                  prefixIcon: const Icon(Icons.notes),
                ),
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
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.background),
                        )
                      : Text(trId('confirm_registration'),
                          style: TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _EventParticipantsSheet extends StatefulWidget {
  final EventEntity event;
  final String lang;

  const _EventParticipantsSheet({required this.event, required this.lang});

  @override
  State<_EventParticipantsSheet> createState() => _EventParticipantsSheetState();
}

class _EventParticipantsSheetState extends State<_EventParticipantsSheet> {
  List<PublicRegistrant>? _names;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final res = await sl<EventRepository>().fetchEventRegistrants(widget.event.id);
    if (!mounted) return;
    res.fold(
      (l) => setState(() => _error = trId('failed_to_load_participants')),
      (names) => setState(() => _names = names),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
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
            trId('registered_participants'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.cText),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Expanded(
                child: Center(
                    child: Text(_error!,
                        style: TextStyle(color: AppColors.accent))))
          else if (_names == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_names!.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  trId('no_participants_yet'),
                  style: TextStyle(color: context.cTextSecondary),
                ),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(
                    en: '${_names!.length} registered',
                    ta: '${_names!.length} பேர் பதிவு செய்துள்ளனர்',
                    hi: '${_names!.length} पंजीकृत',
                    ml: '${_names!.length} രജിസ്റ്റർ ചെയ്തു'),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.cTextSecondary),
              ),
            ),
            const SizedBox(height: 8),
            // Names, Age, Class Grade — the member-facing list never shows phone numbers
            // or other personal details like exact DOB.
            Expanded(
              child: ListView.separated(
                itemCount: _names!.length,
                separatorBuilder: (_, __) => Divider(color: context.cBorder),
                itemBuilder: (ctx, i) {
                  final p = _names![i];
                  final details = [
                    if (p.age != null) '${p.age} years',
                    if (p.classGrade != null && p.classGrade!.isNotEmpty) p.classGrade,
                  ].join(' • ');

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      child: Text(
                        p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                    ),
                    title: Text(p.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: context.cText)),
                    subtitle: details.isNotEmpty
                        ? Text(details,
                            style: TextStyle(fontSize: 11, color: context.cTextSecondary))
                        : null,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
