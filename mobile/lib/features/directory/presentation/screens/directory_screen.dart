import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/contact_entity.dart';
import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../bloc/directory_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  static const _categories = [
    'POLICE',
    'FIRE',
    'AMBULANCE',
    'HOSPITAL',
    'ELECTRICITY_BOARD',
    'REVENUE_OFFICE',
    'TALUK_OFFICE',
    'RTO',
    'MUNICIPALITY',
    'CM_HELPLINE',
    'OTHER',
  ];

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    context.read<DirectoryBloc>().add(const DirectoryFetchRequested());
  }

  void _filter(String? category) {
    setState(() => _selectedCategory = category);
    context
        .read<DirectoryBloc>()
        .add(DirectoryFetchRequested(category: category));
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == 'ta' ? 'அவசர தொடர்பு' : 'Directory'),
      ),
      body: Column(
        children: [
          _FilterRow(
            categories: _categories,
            selected: _selectedCategory,
            lang: _lang,
            onSelect: _filter,
          ),
          Expanded(
            child: BlocConsumer<DirectoryBloc, DirectoryState>(
              listener: (context, state) {
                if (state is DirectoryFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is DirectoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is DirectoryLoaded) {
                  if (state.contacts.isEmpty) {
                    return _EmptyContacts(lang: _lang);
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<DirectoryBloc>().add(
                            DirectoryFetchRequested(
                                category: _selectedCategory),
                          );
                    },
                    child: _ContactList(contacts: state.contacts, lang: _lang,
                        onCall: _launchPhone, onWhatsApp: _launchWhatsApp),
                  );
                }
                if (state is DirectoryFailure) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.read<DirectoryBloc>().add(
                                DirectoryFetchRequested(
                                    category: _selectedCategory),
                              ),
                          child: Text(_lang == 'ta'
                              ? 'மீண்டும் முயற்சிக்கவும்'
                              : 'Retry'),
                        ),
                      ],
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
}

class _FilterRow extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final String lang;
  final void Function(String?) onSelect;

  const _FilterRow({
    required this.categories,
    required this.selected,
    required this.lang,
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
              label: Text(lang == 'ta' ? 'அனைத்தும்' : 'All'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  '${ContactEntity.categoryEmojiFor(c)} '
                  '${ContactEntity.categoryLabelFor(c, lang)}',
                ),
                selected: selected == c,
                selectedColor: AppColors.primary.withOpacity(0.15),
                onSelected: (_) => onSelect(selected == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactList extends StatelessWidget {
  final List<ContactEntity> contacts;
  final String lang;
  final Future<void> Function(String) onCall;
  final Future<void> Function(String) onWhatsApp;

  const _ContactList({
    required this.contacts,
    required this.lang,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    // Group contacts by category, preserving display_order.
    final sorted = [...contacts]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final Map<String, List<ContactEntity>> grouped = {};
    for (final c in sorted) {
      grouped.putIfAbsent(c.category, () => []).add(c);
    }

    final children = <Widget>[];
    grouped.forEach((category, items) {
      children.add(_SectionHeader(
        label: '${ContactEntity.categoryEmojiFor(category)} '
            '${ContactEntity.categoryLabelFor(category, lang)}',
      ));
      children.addAll(items.map((c) => _ContactCard(
            contact: c,
            lang: lang,
            onCall: () => onCall(c.phonePrimary),
            onWhatsApp:
                c.hasWhatsApp ? () => onWhatsApp(c.whatsappNumber!) : null,
          )));
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ContactEntity contact;
  final String lang;
  final VoidCallback onCall;
  final VoidCallback? onWhatsApp;

  const _ContactCard({
    required this.contact,
    required this.lang,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final designation = contact.displayDesignation(lang);
    final geography = contact.displayGeography(lang);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.displayName(lang),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (designation != null && designation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                designation,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
            if (geography != null && geography.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      geography,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  contact.phonePrimary,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone, size: 16),
                    label: Text(lang == 'ta' ? 'அழைக்க' : 'Call'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                if (onWhatsApp != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  final String lang;
  const _EmptyContacts({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📇', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            lang == 'ta' ? 'தொடர்புகள் இல்லை' : 'No contacts found',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
