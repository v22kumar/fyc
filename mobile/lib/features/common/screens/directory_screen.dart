import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../service_locator.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _apiClient = sl<ApiClient>();
  late String _lang;
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _allContacts = [];
  List<dynamic> _filteredContacts = [];
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _lang = sl<LocalStorage>().getLang();
    _fetchContacts();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await _apiClient.dio.get('/api/v1/directory');
      final list = response.data as List<dynamic>;
      setState(() {
        _allContacts = list;
        _filteredContacts = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _lang == 'ta'
            ? 'தொடர்புகளைப் பெற முடியவில்லை: $e'
            : 'Failed to load directory: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((c) {
        // 1. Category Filter
        if (_selectedCategory != 'ALL' && c['category'] != _selectedCategory) {
          return false;
        }
        // 2. Search Query Filter
        if (query.isEmpty) return true;
        final nameEn = (c['name_en'] ?? '').toString().toLowerCase();
        final nameTa = (c['name_ta'] ?? '').toString().toLowerCase();
        final desigEn = (c['designation_en'] ?? '').toString().toLowerCase();
        final desigTa = (c['designation_ta'] ?? '').toString().toLowerCase();
        final geoEn = (c['geography_name_en'] ?? '').toString().toLowerCase();
        final geoTa = (c['geography_name_ta'] ?? '').toString().toLowerCase();

        return nameEn.contains(query) ||
            nameTa.contains(query) ||
            desigEn.contains(query) ||
            desigTa.contains(query) ||
            geoEn.contains(query) ||
            geoTa.contains(query);
      }).toList();
    });
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[+\s]'), '');
    final whatsappUrl = 'https://wa.me/$cleanPhone';
    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _getCategoryLabel(String category) {
    if (_lang == 'ta') {
      switch (category) {
        case 'ALL':
          return 'அனைத்தும்';
        case 'CLUB_OFFICIAL':
          return 'நிர்வாகிகள்';
        case 'POLICE':
          return 'காவல்துறை';
        case 'DOCTOR':
          return 'மருத்துவர்கள்';
        case 'FIRE_SAFETY':
          return 'தீயணைப்புத் துறை';
        case 'MUNICIPALITY':
          return 'நகராட்சி';
        case 'ELECTRICITY_BOARD':
          return 'மின்சார வாரியம்';
        case 'REVENUE_OFFICE':
          return 'வருவாய்த்துறை';
        case 'COMMUNITY_LEADER':
          return 'சமூகத் தலைவர்';
        case 'EMERGENCY_HELPLINE':
          return 'அவசர உதவி எண்';
        case 'VOLUNTEER_LEADER':
          return 'தொண்டர் தலைவர்';
        default:
          return category.replaceAll('_', ' ');
      }
    } else {
      switch (category) {
        case 'ALL':
          return 'All';
        case 'CLUB_OFFICIAL':
          return 'Club Officials';
        case 'POLICE':
          return 'Police';
        case 'DOCTOR':
          return 'Doctors';
        case 'FIRE_SAFETY':
          return 'Fire & Safety';
        case 'MUNICIPALITY':
          return 'Municipality';
        case 'ELECTRICITY_BOARD':
          return 'Electricity Board';
        case 'REVENUE_OFFICE':
          return 'Revenue Office';
        case 'COMMUNITY_LEADER':
          return 'Community Leaders';
        case 'EMERGENCY_HELPLINE':
          return 'Helplines';
        case 'VOLUNTEER_LEADER':
          return 'Volunteer Leaders';
        default:
          return category.replaceAll('_', ' ').titleCase();
      }
    }
  }

  List<String> _getUniqueCategories() {
    final Set<String> categories = {'ALL'};
    for (final c in _allContacts) {
      if (c['category'] != null) {
        categories.add(c['category'].toString());
      }
    }
    return categories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _lang == 'ta' ? 'உறுப்பினர் கோப்பகம்' : 'Member Directory';
    final searchHint = _lang == 'ta' ? 'பெயர், பதவி அல்லது வட்டாரத்தைத் தேடுக...' : 'Search by name, role or taluk...';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Category Selector Tabs
          if (_allContacts.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _getUniqueCategories().map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        _getCategoryLabel(cat),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                          _applyFilters();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),

          // Main list container
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⚠️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(_errorMessage, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchContacts,
                                child: Text(_lang == 'ta' ? 'மறுபடியும் முயற்சிக்கவும்' : 'Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredContacts.isEmpty
                        ? Center(
                            child: Text(
                              _lang == 'ta' ? 'தொடர்புகள் எதுவும் இல்லை' : 'No contacts found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchContacts,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final c = _filteredContacts[index];
                                final name = _lang == 'ta' ? (c['name_ta'] ?? c['name_en']) : (c['name_en'] ?? c['name_ta']);
                                final desig = _lang == 'ta' ? (c['designation_ta'] ?? c['designation_en']) : (c['designation_en'] ?? c['designation_ta']);
                                final geo = _lang == 'ta' ? (c['geography_name_ta'] ?? c['geography_name_en']) : (c['geography_name_en'] ?? c['geography_name_ta']);
                                final address = _lang == 'ta' ? (c['address_ta'] ?? c['address_en']) : (c['address_en'] ?? c['address_ta']);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left Profile Icon / Avatar
                                        CircleAvatar(
                                          backgroundColor: AppColors.primarySurface,
                                          child: Text(
                                            (name as String).substring(0, 1).toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Contact details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (desig != null && desig.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  desig,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                              if (geo != null && geo.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      geo,
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              if (address != null && address.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  address,
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Actions (WhatsApp / Phone)
                                        Column(
                                          children: [
                                            if (c['phone_primary'] != null)
                                              IconButton(
                                                icon: const Icon(Icons.phone, color: AppColors.primary, size: 20),
                                                onPressed: () => _launchCall(c['phone_primary'].toString()),
                                                tooltip: 'Call Primary',
                                              ),
                                            if (c['whatsapp_number'] != null)
                                              IconButton(
                                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 20),
                                                onPressed: () => _launchWhatsApp(c['whatsapp_number'].toString()),
                                                tooltip: 'WhatsApp',
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

extension _TitleCaseString on String {
  String titleCase() {
    if (isEmpty) return this;
    return split(' ').map((str) => str.isEmpty ? '' : str[0].toUpperCase() + str.substring(1).toLowerCase()).join(' ');
  }
}
