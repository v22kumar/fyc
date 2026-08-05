import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/blood_donor_entity.dart';
import '../../domain/repositories/blood_donor_repository.dart';

/// The Friends2Support directory — kept apart, on purpose.
///
/// These are not members. They are phone numbers from a public directory: no
/// account, no location, no notification, no way of knowing whether the number
/// still belongs to the person or whether they still donate. Calling one is a
/// cold call to a stranger, and it should feel like one.
///
/// They used to sit in the same list as club members with a small badge to tell
/// them apart, which quietly promised the same thing for both. The club list
/// answers "who near me has agreed to be asked"; this screen answers "I have
/// tried everyone and I need more numbers". Different questions, different
/// screens — and this one is the second stop, never the first.
///
/// Nothing is dressed up here. No distance, because there is none. No presence
/// dot, because nobody is being tracked. Just a group, a name, and a number.
class ImportedDirectoryScreen extends StatefulWidget {
  const ImportedDirectoryScreen({super.key});

  @override
  State<ImportedDirectoryScreen> createState() =>
      _ImportedDirectoryScreenState();
}

class _ImportedDirectoryScreenState extends State<ImportedDirectoryScreen> {
  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  String get _lang => sl<LocalStorage>().getLang();

  String? _group;
  List<BloodDonorEntity> _contacts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await sl<BloodDonorRepository>().searchDonors(
      bloodGroup: _group,
      source: 'imported',
    );
    if (!mounted) return;
    setState(() {
      _contacts = result.getOrElse(() => const []);
      _loading = false;
    });
  }

  Future<void> _reveal(BloodDonorEntity contact) async {
    final result = await sl<BloodDonorRepository>().requestContact(contact.id);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (info) => showModalBottomSheet(
        context: context,
        builder: (_) => _NumberSheet(
          name: contact.displayName(_lang),
          phone: info['phone_number'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(trId('wider_directory'))),
      body: Column(
        children: [
          // Said once, at the top, where it sets expectations for everything
          // below it — rather than as a badge repeated on every row.
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(DSSpacing.md),
            color: AppColors.warning.withOpacity(0.10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.warning),
                SizedBox(width: DSSpacing.sm),
                Expanded(
                  child: Text(
                    trId('wider_directory_note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
              children: [
                for (final g in [null, ..._groups])
                  Padding(
                    padding: EdgeInsets.only(right: DSSpacing.xs, top: 8),
                    child: ChoiceChip(
                      label: Text(g ?? trId('all')),
                      selected: _group == g,
                      // Spelled out rather than inherited: the ambient chip
                      // theme rendered unselected labels the same colour as
                      // the chip, so the row read as eight blank outlines.
                      labelStyle: TextStyle(
                        color: _group == g
                            ? AppColors.background
                            : context.cText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      selectedColor: DSColors.danger,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _group = g);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(DSSpacing.xl),
                          child: Text(
                            trId('no_contacts_in_directory'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: context.cTextSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(DSSpacing.md),
                        itemCount: _contacts.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: context.cBorder,
                        ),
                        itemBuilder: (_, i) {
                          final c = _contacts[i];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: DSSpacing.xs),
                            leading: CircleAvatar(
                              backgroundColor:
                                  DSColors.danger.withOpacity(0.10),
                              child: Text(
                                c.bloodGroup,
                                style: TextStyle(
                                  color: DSColors.danger,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            title: Text(c.displayName(_lang)),
                            trailing: TextButton.icon(
                              onPressed: () => _reveal(c),
                              icon: const Icon(Icons.call_rounded, size: 16),
                              label: Text(trId('get_number')),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NumberSheet extends StatelessWidget {
  const _NumberSheet({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(DSSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: DSSpacing.xs),
            SelectableText(
              phone,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: DSSpacing.sm),
            // The one thing worth saying before someone dials a stranger.
            Text(
              trId('cold_call_note'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.cTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
