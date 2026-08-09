import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/blood_donor_entity.dart';
import '../../domain/repositories/blood_donor_repository.dart';

/// The Friends2Support directory — kept apart, and organised by taluk.
///
/// These are not members. They are phone numbers the club collected from a
/// public source: no account, no location, no notification, no way of knowing
/// whether the number still belongs to the person or whether they still donate.
/// Calling one is a cold call to a stranger, and it should feel like one.
///
/// They used to sit in the club list with a small badge to tell them apart,
/// which quietly promised the same thing for both. The club list answers "who
/// near me has agreed to be asked"; this screen answers "I have tried everyone
/// and I need more numbers". Different questions, different screens — and this
/// one is the second stop, never the first.
///
/// **Taluk is the organising unit**, because it is the only geography these
/// records have. There is no distance to sort by and there never will be: a
/// directory contact has no position and is never going to share one. So the
/// list is grouped by taluk, and widening the search is an explicit step to the
/// rest of the district rather than a slider to nowhere.
///
/// Nothing is dressed up. No distance, because there is none. No presence dot,
/// because nobody is being tracked. A group, a name, a place, and a number.
class ImportedDirectoryScreen extends StatefulWidget {
  const ImportedDirectoryScreen({super.key});

  @override
  State<ImportedDirectoryScreen> createState() =>
      _ImportedDirectoryScreenState();
}

class _ImportedDirectoryScreenState extends State<ImportedDirectoryScreen> {
  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  String get _lang => trLang();

  String? _group;
  String? _talukId;
  bool _includeNeighbours = false;
  List<_Taluk> _taluks = const [];
  List<BloodDonorEntity> _contacts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTaluks();
    _load();
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
        ..sort((a, b) =>
            a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()));
      if (mounted) setState(() => _taluks = list);
    } catch (_) {/* the dropdown stays on "all areas" */}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await sl<BloodDonorRepository>().searchDonors(
      bloodGroup: _group,
      geographyId: _talukId,
      // Only meaningful with a taluk chosen: it widens to the rest of that
      // taluk's district.
      nearby: _includeNeighbours && _talukId != null,
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

  /// Contacts under their taluk heading, taluks in alphabetical order.
  ///
  /// Grouping is done here rather than asked of the server because the server
  /// already returned everything the filter allows — the only question left is
  /// how to show it, and a flat run of four hundred names from six taluks is
  /// not a list, it is a wall.
  List<MapEntry<String, List<BloodDonorEntity>>> _byTaluk() {
    final buckets = <String, List<BloodDonorEntity>>{};
    for (final c in _contacts) {
      // Contacts whose taluk was never recorded still have to be reachable —
      // hiding them would quietly shrink the directory.
      final where = c.locationName(_lang) ?? trId('area_not_recorded');
      (buckets[where] ??= []).add(c);
    }
    final entries = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byTaluk();
    return Scaffold(
      appBar: AppBar(title: Text(trId('wider_directory'))),
      body: Column(
        children: [
          // Said once, at the top, where it sets expectations for everything
          // below it — rather than as a badge repeated on every row.
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(DSSpacing.md),
            color: AppColors.warning.withValues(alpha: 0.10),
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
          _TalukFilter(
            taluks: _taluks,
            selectedId: _talukId,
            includeNeighbours: _includeNeighbours,
            lang: _lang,
            onSelect: (id) {
              setState(() {
                _talukId = id;
                if (id == null) _includeNeighbours = false;
              });
              _load();
            },
            onToggleNeighbours: (v) {
              setState(() => _includeNeighbours = v);
              _load();
            },
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
              children: [
                for (final g in [null, ..._groups])
                  Padding(
                    padding: EdgeInsets.only(right: DSSpacing.xs, top: 6),
                    child: ChoiceChip(
                      label: Text(g ?? trId('all')),
                      selected: _group == g,
                      // Spelled out rather than inherited: the ambient chip
                      // theme rendered unselected labels the same colour as the
                      // chip, so the row read as eight blank outlines.
                      labelStyle: TextStyle(
                        color:
                            _group == g ? AppColors.background : context.cText,
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
                    : ListView(
                        padding: EdgeInsets.fromLTRB(DSSpacing.md, 0,
                            DSSpacing.md, DSSpacing.xl),
                        children: [
                          for (final entry in grouped) ...[
                            _TalukHeading(
                                name: entry.key, count: entry.value.length),
                            for (final c in entry.value)
                              _ContactRow(
                                contact: c,
                                lang: _lang,
                                onGetNumber: () => _reveal(c),
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

/// Which taluk, and whether to widen to the rest of the district.
///
/// Two steps rather than a radius, because the data has no radius in it. A
/// taluk is the finest thing these records know, and "the rest of the district"
/// is the only larger unit that means anything to someone who lives here.
class _TalukFilter extends StatelessWidget {
  const _TalukFilter({
    required this.taluks,
    required this.selectedId,
    required this.includeNeighbours,
    required this.lang,
    required this.onSelect,
    required this.onToggleNeighbours,
  });

  final List<_Taluk> taluks;
  final String? selectedId;
  final bool includeNeighbours;
  final String lang;
  final ValueChanged<String?> onSelect;
  final ValueChanged<bool> onToggleNeighbours;

  @override
  Widget build(BuildContext context) {
    final ta = lang == 'ta';
    String label(_Taluk t) =>
        ta ? (t.nameTa.isNotEmpty ? t.nameTa : t.nameEn) : t.nameEn;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          DSSpacing.md, DSSpacing.sm, DSSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(DSRadius.card),
              border: Border.all(color: context.cBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: selectedId,
                icon: Icon(Icons.expand_more, color: context.cTextSecondary),
                hint: Text(trId('all_locations'),
                    style:
                        TextStyle(fontSize: 14, color: context.cTextSecondary)),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(trId('all_locations'),
                        style: const TextStyle(fontSize: 14)),
                  ),
                  ...taluks.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(label(t),
                            style: const TextStyle(fontSize: 14)),
                      )),
                ],
                onChanged: onSelect,
              ),
            ),
          ),
          // Only offered once a taluk is chosen: "nearby" has nothing to be
          // near until then.
          if (selectedId != null)
            InkWell(
              onTap: () => onToggleNeighbours(!includeNeighbours),
              child: Row(
                children: [
                  Checkbox(
                    value: includeNeighbours,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => onToggleNeighbours(v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      trId('include_nearby_taluks'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TalukHeading extends StatelessWidget {
  const _TalukHeading({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DSSpacing.md, bottom: DSSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 15, color: context.cTextSecondary),
          SizedBox(width: DSSpacing.xs),
          Expanded(
            child: Text(name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text('$count',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.cTextSecondary)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.lang,
    required this.onGetNumber,
  });

  final BloodDonorEntity contact;
  final String lang;
  final VoidCallback onGetNumber;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: DSColors.danger.withValues(alpha: 0.10),
        child: Text(
          contact.bloodGroup,
          style: const TextStyle(
            color: DSColors.danger,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      // Two lines for a name. It is the only thing on the row that identifies
      // a person, and clipping it to "Imported Don…" identifies nobody.
      title: Text(contact.displayName(lang),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: TextButton.icon(
        onPressed: onGetNumber,
        icon: const Icon(Icons.call_rounded, size: 16),
        label: Text(trId('get_number')),
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

class _Taluk {
  final String id;
  final String nameEn;
  final String nameTa;
  const _Taluk({required this.id, required this.nameEn, required this.nameTa});
}
