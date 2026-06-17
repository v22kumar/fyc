import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../service_locator.dart';
import '../../../core/widgets/scale_on_tap.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  String get _lang => sl<LocalStorage>().getLang();
  String _selectedTab = 'ALL';
  final Set<String> _appliedIds = {};

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'opp_1',
      'type': 'VOLUNTEER',
      'title_en': 'Sapling Planting Coordinator',
      'title_ta': 'மரக்கன்று நடுகை ஒருங்கிணைப்பாளர்',
      'org': 'Green FYC',
      'hours': '5 hrs',
      'category_en': 'Environment',
      'category_ta': 'சுற்றுச்சூழல்',
      'location_en': 'Nagercoil Town Limits',
      'location_ta': 'நாகர்கோவில் நகர எல்லை',
      'desc_en': 'Lead a team of 5 volunteers to plant and water native tree saplings across municipal wards.',
      'desc_ta': 'நகராட்சி வார்டுகளில் நாட்டு மரக்கன்றுகளை நட்டு நீர் பாய்ச்ச 5 தன்னார்வலர்களை வழிநடத்துதல்.',
      'btn_text_en': 'Apply to Volunteer',
      'btn_text_ta': 'தன்னார்வலராக விண்ணப்பி',
    },
    {
      'id': 'opp_2',
      'type': 'VOLUNTEER',
      'title_en': 'Emergency Blood Drive Assistant',
      'title_ta': 'இரத்த தான முகாம் உதவியாளர்',
      'org': 'FYC Health Desk',
      'hours': '3 hrs',
      'category_en': 'Healthcare',
      'category_ta': 'சுகாதாரம்',
      'location_en': 'District Government Hospital',
      'location_ta': 'மாவட்ட அரசு மருத்துவமனை',
      'desc_en': 'Help manage registration, seat donor flow, and distribute refreshments during the emergency camp.',
      'desc_ta': 'அவசர முகாமின் போது கொடையாளர்களைப் பதிவுசெய்தல் மற்றும் தின்பண்டங்கள் வழங்குதல் போன்ற பணிகளில் உதவுதல்.',
      'btn_text_en': 'Apply to Volunteer',
      'btn_text_ta': 'தன்னார்வலராக விண்ணப்பி',
    },
    {
      'id': 'opp_3',
      'type': 'COURSE',
      'title_en': 'Basic Disaster Management & First Aid',
      'title_ta': 'பேரிடர் மேலாண்மை & முதலுதவி பயிற்சி',
      'org': 'Red Cross Certified',
      'hours': '12 hrs',
      'category_en': 'Training',
      'category_ta': 'பயிற்சி வகுப்பு',
      'location_en': 'FYC Community Hall',
      'location_ta': 'பிரண்ட்ஸ் கிளப் அரங்கம்',
      'desc_en': 'A certified training course covering CPR, basic life support, flood rescue tactics, and emergency response.',
      'desc_ta': 'முதலுதவி, சி.பி.ஆர் (CPR) மற்றும் பேரிடர் மீட்பு முறைகள் குறித்த சான்றளிக்கப்பட்ட பயிற்சி வகுப்பு.',
      'btn_text_en': 'Enroll in Course',
      'btn_text_ta': 'வகுப்பில் சேரவும்',
    },
    {
      'id': 'opp_4',
      'type': 'VOLUNTEER',
      'title_en': 'Panchayat School Mathematics Tutor',
      'title_ta': 'பஞ்சாயத்து பள்ளி கணித ஆசிரியர்',
      'org': 'FYC Literacy Drive',
      'hours': '6 hrs/week',
      'category_en': 'Education',
      'category_ta': 'கல்விச்சேவை',
      'location_en': 'Government School, Vadasery',
      'location_ta': 'அரசு பள்ளி, வடசேரி',
      'desc_en': 'Provide evening tutoring support for elementary school children to strengthen basic mathematical operations.',
      'desc_ta': 'ஆரம்ப பள்ளி குழந்தைகளுக்கு மாலை நேர கணித பாடங்களை எளிமையாக கற்றுக்கொடுக்க உதவுதல்.',
      'btn_text_en': 'Apply to Volunteer',
      'btn_text_ta': 'தன்னார்வலராக விண்ணப்பி',
    },
    {
      'id': 'opp_5',
      'type': 'COURSE',
      'title_en': 'Digital Literacy for Rural Youth',
      'title_ta': 'கிராமப்புற இளைஞர்களுக்கான கணினி கல்வி',
      'org': 'FYC Tech Academy',
      'hours': '8 hrs',
      'category_en': 'Training',
      'category_ta': 'பயிற்சி வகுப்பு',
      'location_en': 'FYC Computer Lab',
      'location_ta': 'பிரண்ட்ஸ் கிளப் கணினி அறை',
      'desc_en': 'Learn basic office tools, email communication, internet navigation, and secure online transaction principles.',
      'desc_ta': 'அடிப்படை கணினி பயன்பாடுகள், மின்னஞ்சல் மற்றும் இணையப் பாதுகாப்பு குறித்த எளிய பயிற்சி.',
      'btn_text_en': 'Enroll in Course',
      'btn_text_ta': 'வகுப்பில் சேரவும்',
    }
  ];

  void _handleAction(String id, String title) {
    setState(() {
      _appliedIds.add(id);
    });

    final isTa = _lang == 'ta';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isTa
                    ? 'வெற்றி! $title விண்ணப்பம் ஏற்றுக்கொள்ளப்பட்டது.'
                    : 'Success! Your request for "$title" has been submitted.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';
    final filtered = _items.where((item) {
      if (_selectedTab == 'ALL') return true;
      return item['type'] == _selectedTab;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'வாய்ப்புகள் & பயிற்சி' : 'Opportunities & Skills'),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', isTa ? 'அனைத்தும்' : 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('VOLUNTEER', isTa ? 'தன்னார்வ பணி' : 'Volunteer'),
                const SizedBox(width: 8),
                _buildFilterChip('COURSE', isTa ? 'பயிற்சிகள்' : 'Courses'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(isTa ? 'வாய்ப்புகள் ஏதுமில்லை' : 'No opportunities found'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final id = item['id'] as String;
                      final isApplied = _appliedIds.contains(id);
                      final title = isTa ? item['title_ta']! : item['title_en']!;
                      final cat = isTa ? item['category_ta']! : item['category_en']!;
                      final loc = isTa ? item['location_ta']! : item['location_en']!;
                      final desc = isTa ? item['desc_ta']! : item['desc_en']!;
                      final type = item['type'] as String;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          boxShadow: AppTheme.cardShadow,
                          border: Border(
                            left: BorderSide(
                              color: type == 'VOLUNTEER'
                                  ? AppColors.primary
                                  : const Color(0xFF8B5CF6),
                              width: 6,
                            ),
                            top: const BorderSide(color: AppColors.border, width: 1),
                            right: const BorderSide(color: AppColors.border, width: 1),
                            bottom: const BorderSide(color: AppColors.border, width: 1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: type == 'VOLUNTEER'
                                          ? AppColors.primary.withOpacity(0.08)
                                          : const Color(0xFF8B5CF6).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      type == 'VOLUNTEER'
                                          ? (isTa ? 'தன்னார்வ பணி' : 'VOLUNTEERING')
                                          : (isTa ? 'வகுப்பு' : 'SKILL COURSE'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: type == 'VOLUNTEER'
                                            ? AppColors.primary
                                            : const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    item['hours'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item['org']} • $cat',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      loc,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: isApplied
                                    ? OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check, color: AppColors.success),
                                        label: Text(
                                          isTa ? 'விண்ணப்பிக்கப்பட்டது' : 'Applied / Registered',
                                          style: const TextStyle(color: AppColors.success),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppColors.success, width: 1.5),
                                        ),
                                      )
                                    : ScaleOnTap(
                                        onTap: () => _handleAction(id, title),
                                        child: ElevatedButton(
                                          onPressed: () => _handleAction(id, title),
                                          style: type == 'VOLUNTEER'
                                              ? ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                )
                                              : ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF8B5CF6),
                                                ),
                                          child: Text(
                                            isTa ? item['btn_text_ta']! : item['btn_text_en']!,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
