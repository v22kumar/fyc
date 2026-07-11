import 'package:flutter/material.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../service_locator.dart';

/// Club member roster — the real "Members" directory (names, role, photo).
/// Backed by GET /api/v1/users/roster, which returns only safe public fields
/// (no phone/email/DOB). Distinct from the local-trade directory (now under
/// Opportunities) and the emergency-contacts directory (/directory).
class MembersRosterScreen extends StatefulWidget {
  const MembersRosterScreen({super.key});

  @override
  State<MembersRosterScreen> createState() => _MembersRosterScreenState();
}

class _MembersRosterScreenState extends State<MembersRosterScreen> {
  bool _loading = true;
  bool _error = false;
  List<_Member> _members = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await sl<ApiClient>().dio.get('/api/v1/users/roster');
      final list = (res.data as List)
          .map((e) => _Member.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _members = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = sl<LocalStorage>().getLang() == 'ta';
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: Text(tr(en: 'Members', ta: 'உறுப்பினர்கள்', hi: 'सदस्य', ml: 'അംഗങ്ങൾ')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(ta),
      ),
    );
  }

  Widget _buildBody(bool ta) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.wifi_off_rounded, size: 44, color: context.cTextSecondary),
                const SizedBox(height: 12),
                Text(tr(en: "Couldn't load members", ta: 'உறுப்பினர்களை ஏற்ற முடியவில்லை',
                    hi: 'सदस्य लोड नहीं हुए', ml: 'അംഗങ്ങളെ ലോഡ് ചെയ്യാനായില്ല')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _load,
                  child: Text(tr(en: 'Retry', ta: 'மீண்டும்', hi: 'पुनः', ml: 'വീണ്ടും')),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_members.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                const Text('👥', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 14),
                Text(tr(en: 'No members yet', ta: 'உறுப்பினர்கள் இல்லை',
                    hi: 'अभी कोई सदस्य नहीं', ml: 'ഇതുവരെ അംഗങ്ങളില്ല'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.cText)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    tr(en: 'Registered club members will appear here.',
                        ta: 'பதிவு செய்த கழக உறுப்பினர்கள் இங்கே தோன்றுவார்கள்.',
                        hi: 'पंजीकृत क्लब सदस्य यहाँ दिखाई देंगे।',
                        ml: 'രജിസ്റ്റർ ചെയ്ത ക്ലബ് അംഗങ്ങൾ ഇവിടെ കാണാം.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.cTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _members.length,
      itemBuilder: (context, i) => FadeSlideIn(
        delay: Duration(milliseconds: (i * 40).clamp(0, 400)),
        child: _MemberTile(member: _members[i], ta: ta),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final _Member member;
  final bool ta;
  const _MemberTile({required this.member, required this.ta});

  @override
  Widget build(BuildContext context) {
    final name = member.displayName(ta);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final photo = member.profileImageUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: hasPhoto
                ? NetworkImage(photo.startsWith('http') ? photo : '${ApiConstants.baseUrl}$photo')
                : null,
            child: hasPhoto
                ? null
                : Text(initial,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.cText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          _RoleBadge(role: member.role),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  (String, Color) _meta() {
    switch (role) {
      case 'SUPER_ADMIN':
      case 'ADMIN':
        return (tr(en: 'Admin', ta: 'நிர்வாகி', hi: 'एडमिन', ml: 'അഡ്മിൻ'), const Color(0xFFDC2626));
      case 'EXECUTIVE_MEMBER':
        return (tr(en: 'Executive', ta: 'செயற்குழு', hi: 'कार्यकारी', ml: 'എക്സിക്യൂട്ടീവ്'), const Color(0xFF7C3AED));
      case 'CLUB_MEMBER':
        return (tr(en: 'Member', ta: 'உறுப்பினர்', hi: 'सदस्य', ml: 'അംഗം'), AppColors.primary);
      case 'VOLUNTEER':
        return (tr(en: 'Volunteer', ta: 'தொண்டர்', hi: 'स्वयंसेवक', ml: 'വളണ്ടിയർ'), const Color(0xFF16A34A));
      default:
        return (role, Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _meta();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Member {
  final String id;
  final String? fullNameTa;
  final String? fullNameEn;
  final String role;
  final String? profileImageUrl;

  const _Member({
    required this.id,
    required this.role,
    this.fullNameTa,
    this.fullNameEn,
    this.profileImageUrl,
  });

  factory _Member.fromJson(Map<String, dynamic> json) => _Member(
        id: json['id'] as String,
        fullNameTa: json['full_name_ta'] as String?,
        fullNameEn: json['full_name_en'] as String?,
        role: json['role'] as String? ?? 'CLUB_MEMBER',
        profileImageUrl: json['profile_image_url'] as String?,
      );

  String displayName(bool ta) {
    final primary = ta ? fullNameTa : fullNameEn;
    return (primary != null && primary.trim().isNotEmpty)
        ? primary
        : (fullNameEn ?? fullNameTa ?? 'Member');
  }
}
