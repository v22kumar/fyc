import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/services/sos_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../bloc/safety_setup_bloc.dart';
import '../../../../service_locator.dart';
import '../../domain/repositories/safety_repository.dart';
import '../bloc/sos_bloc.dart';
import 'sos_screen.dart';

/// Everything an emergency has no time for, done in advance.
///
/// The screen this replaces had two switches and a text field you typed a raw
/// phone number into from memory. No names, no validation, no way to check the
/// number worked, and the contacts lived only on the device — so a reinstall
/// lost them and a lost phone silenced them.
class SafetySetupScreen extends StatefulWidget {
  const SafetySetupScreen({super.key});

  @override
  State<SafetySetupScreen> createState() => _SafetySetupScreenState();
}

class _SafetySetupScreenState extends State<SafetySetupScreen> {
  bool _shake = false;

  @override
  void initState() {
    super.initState();
    context.read<SafetySetupBloc>().add(const SetupRequested());
    _loadDevicePrefs();
  }

  Future<void> _loadDevicePrefs() async {
    final shake = await SosService.getShakeToTrigger();
    if (!mounted) return;
    setState(() => _shake = shake);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSScreenHeader(
        title: trId('safety_setup'),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: BlocConsumer<SafetySetupBloc, SetupState>(
        listenWhen: (a, b) =>
            (a.failure != b.failure && b.failure != null) ||
            (!a.testSent && b.testSent),
        listener: (context, state) {
          final message = state.testSent ? trId('test_sent') : state.failure!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
                DSSpacing.md, DSSpacing.sm, DSSpacing.md, DSSpacing.xl),
            children: [
              _SectionTitle(trId('who_to_tell')),
              Text(trId('who_to_tell_help'),
                  style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: DSSpacing.sm),
              for (final c in state.contacts)
                _ContactRow(
                  contact: c,
                  busy: state.busy,
                  onTest: () => context
                      .read<SafetySetupBloc>()
                      .add(ContactTested(c.id)),
                  onRemove: () => context
                      .read<SafetySetupBloc>()
                      .add(ContactRemoved(c.id)),
                ),
              SizedBox(height: DSSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: state.busy ? null : _addContact,
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: Text(trId('add_a_contact')),
                ),
              ),

              const Divider(height: 40),

              _SectionTitle(trId('be_a_responder')),
              Text(
                trId('be_a_responder_help', {
                  'n': _distanceLabel(state.settings.maxDistanceM),
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: state.settings.isAvailable,
                onChanged: state.busy
                    ? null
                    : (v) => context.read<SafetySetupBloc>().add(
                          AvailabilityChanged(e.ResponderSettings(
                            isAvailable: v,
                            maxDistanceM: state.settings.maxDistanceM,
                            quietFromHour: state.settings.quietFromHour,
                            quietToHour: state.settings.quietToHour,
                          )),
                        ),
                title: Text(trId('be_a_responder')),
              ),
              if (state.settings.isAvailable) ...[
                _DistancePicker(
                  metres: state.settings.maxDistanceM,
                  onChanged: (m) => context.read<SafetySetupBloc>().add(
                        AvailabilityChanged(e.ResponderSettings(
                          isAvailable: true,
                          maxDistanceM: m,
                          quietFromHour: state.settings.quietFromHour,
                          quietToHour: state.settings.quietToHour,
                        )),
                      ),
                ),
                _QuietHours(
                  from: state.settings.quietFromHour,
                  to: state.settings.quietToHour,
                  onChanged: (from, to) =>
                      context.read<SafetySetupBloc>().add(
                            AvailabilityChanged(e.ResponderSettings(
                              isAvailable: true,
                              maxDistanceM: state.settings.maxDistanceM,
                              quietFromHour: from,
                              quietToHour: to,
                            )),
                          ),
                ),
              ],

              const Divider(height: 40),

              // Off by default now. It used to be on for everybody, and what
              // it did was throw a modal over whatever they were doing.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shake,
                onChanged: (v) async {
                  await SosService.setShakeToTrigger(v);
                  if (mounted) setState(() => _shake = v);
                },
                title: Text(trId('shake_to_send')),
                subtitle: Text(trId('shake_to_send_help'),
                    style: Theme.of(context).textTheme.bodySmall),
              ),

              SizedBox(height: DSSpacing.md),
              // Nobody should press the real one for the first time in an
              // emergency and find out then that they have no contacts.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  // Its own bloc, because the rehearsal is a real run of
                  // the real screen — the only difference is that nothing is
                  // ever sent.
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => BlocProvider(
                      create: (_) => SosBloc(sl<SafetyRepository>()),
                      child: const SosScreen(rehearsal: true),
                    ),
                  )),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: Text(trId('rehearse')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _distanceLabel(int metres) =>
      metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(0)} km';

  Future<void> _addContact() async {
    final bloc = context.read<SafetySetupBloc>();
    final result = await showModalBottomSheet<(String, String, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AddContactSheet(),
    );
    if (result == null) return;
    bloc.add(ContactAdded(
        name: result.$1, phone: result.$2, relationship: result.$3));
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.busy,
    required this.onTest,
    required this.onRemove,
  });

  final e.SafetyContact contact;
  final bool busy;
  final VoidCallback onTest;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: DSSpacing.xs),
      padding: EdgeInsets.all(DSSpacing.sm),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DSRadius.card),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [contact.name, if (contact.relationship != null)
                    contact.relationship!].join(' · '),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(contact.phone,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                // What will actually happen to them. A phone that rings like
                // an alarm and an SMS that lands silently are very different
                // promises, and the member choosing who to list should know
                // which one they are making.
                Row(
                  children: [
                    Icon(
                      contact.isMember
                          ? Icons.notifications_active_rounded
                          : Icons.sms_outlined,
                      size: 13,
                      color: context.cTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        // Only a member's phone can be made to ring. For
                        // everybody else this says SMS, because that is what
                        // they will get.
                        contact.isMember
                            ? trId('rings_like_an_alarm')
                            : trId('sms_only'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Says "not tested yet" rather than showing a tick nobody
                // earned. Nobody should discover a wrong number mid-emergency.
                //
                // Wrapped rather than laid out in a Row: the Tamil for "not
                // tested yet" beside the Tamil for "send a test" overflows a
                // 390px phone, and it did.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Icon(
                      contact.isTested
                          ? Icons.check_circle_rounded
                          : Icons.help_outline_rounded,
                      size: 14,
                      color: contact.isTested
                          ? AppColors.success
                          : context.cTextSecondary,
                    ),
                    Text(
                      contact.isTested ? trId('tested') : trId('not_tested_yet'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: contact.isTested
                                ? AppColors.success
                                : context.cTextSecondary,
                          ),
                    ),
                    TextButton(
                      onPressed: busy ? null : onTest,
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text(trId('send_test_message')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRemove,
            icon: Icon(Icons.close_rounded, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _phone.text.trim().length >= 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: DSSpacing.md,
        right: DSSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + DSSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(trId('add_a_contact'),
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: DSSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: trId('contact_name'),
              hintText: trId('contact_name_hint'),
            ),
          ),
          SizedBox(height: DSSpacing.xs),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: trId('phone')),
          ),
          SizedBox(height: DSSpacing.xs),
          TextField(
            controller: _relationship,
            decoration:
                InputDecoration(labelText: trId('contact_relationship')),
          ),
          SizedBox(height: DSSpacing.md),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(context).pop((
                      _name.text.trim(),
                      _phone.text.trim(),
                      _relationship.text.trim().isEmpty
                          ? null
                          : _relationship.text.trim(),
                    ))
                : null,
            child: Text(trId('add_a_contact')),
          ),
        ],
      ),
    );
  }
}

class _DistancePicker extends StatelessWidget {
  const _DistancePicker({required this.metres, required this.onChanged});

  final int metres;
  final ValueChanged<int> onChanged;

  static const _options = [1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    // Label above rather than beside: the Tamil for "how far" plus three chips
    // does not fit a 390px phone on one line, and pushing the last chip off
    // the edge hides an option rather than crowding it.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DSSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trId('how_far'),
              style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: DSSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _options)
                ChoiceChip(
                  selected: metres == m,
                  onSelected: (_) => onChanged(m),
                  label: Text(m < 1000
                      ? '$m m'
                      : '${(m / 1000).toStringAsFixed(0)} km'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuietHours extends StatelessWidget {
  const _QuietHours(
      {required this.from, required this.to, required this.onChanged});

  final int? from;
  final int? to;
  final void Function(int? from, int? to) onChanged;

  @override
  Widget build(BuildContext context) {
    final on = from != null && to != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: on,
          // A member who works nights should be able to say so without leaving
          // the roster entirely.
          onChanged: (v) => onChanged(v ? 22 : null, v ? 6 : null),
          title: Text(trId('quiet_hours')),
          subtitle: Text(
            on ? '${from!}:00 — ${to!}:00' : trId('quiet_hours_help'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: DSSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
