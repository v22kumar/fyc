import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/community_repository.dart';

/// One member as another member may see them — the Instagram-minimal card
/// the club asked for: a face, a name, a role, how long they have served,
/// what they have done, and — when they allow it — the days the club
/// celebrates with them. Nothing else: no phone, no age, no blood group.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen(
      {super.key, required this.userId, required this.repo});

  final String userId;
  final CommunityRepository repo;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late final Future<Map<String, dynamic>> _future =
      widget.repo.fetchMemberCard(widget.userId);

  @override
  Widget build(BuildContext context) {
    final ta = trLang() == 'ta';
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(trId('member_profile'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final card = snap.data;
          if (card == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(trId('request_failed'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.cTextSecondary)),
              ),
            );
          }
          final name = ta
              ? (card['full_name_ta'] as String?)?.trim()
              : (card['full_name_en'] as String?)?.trim();
          final fallback = (card['full_name_en'] as String?)?.trim() ?? '';
          final display = (name == null || name.isEmpty) ? fallback : name;
          final photo = card['profile_image_url'] as String?;
          final role = (card['role'] as String?) ?? '';
          final since = card['member_since'] as String?;
          final isBirthday = card['is_birthday_today'] == true;
          final isAnniversary = card['is_anniversary_today'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      (photo != null && photo.isNotEmpty)
                          ? NetworkImage(photo)
                          : null,
                  child: (photo == null || photo.isEmpty)
                      ? Text(
                          display.isEmpty ? '?' : display[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(display,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.cText)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _RolePill(role: role),
                    if (since != null)
                      Text(
                        trId('member_since',
                            {'year': since.substring(0, 4)}),
                        style: TextStyle(
                            fontSize: 12.5, color: context.cTextSecondary),
                      ),
                  ],
                ),
              ),
              if (isBirthday || isAnniversary) ...[
                const SizedBox(height: 16),
                _CelebrationBanner(
                    label: trId(
                        isBirthday ? 'birthday_today' : 'anniversary_today')),
              ] else ...[
                // The next date the club celebrates with them — day and
                // month only; the year never leaves the profile.
                for (final (key, label) in [
                  ('birthday_day_month', '🎂'),
                  ('anniversary_day_month', '💐'),
                ])
                  if (card[key] != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '$label ${trId('celebrates_on', {
                              'date': _prettyDayMonth(card[key] as String)
                            })}',
                        style: TextStyle(
                            fontSize: 12.5, color: context.cTextSecondary),
                      ),
                    ),
                  ],
              ],
              const SizedBox(height: 24),
              // ── The community record ─────────────────────────────────────
              Row(children: [
                _Stat(
                    value: '${card['events_attended'] ?? 0}',
                    label: trId('events_attended')),
                _Stat(
                    value: '${card['blood_donations'] ?? 0}',
                    label: trId('blood_donations_2')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _Stat(
                    value: '${card['trees_planted'] ?? 0}',
                    label: trId('trees_planted_2')),
                _Stat(
                    value: '${card['sports_matches_played'] ?? 0}',
                    label: trId('matches_played')),
              ]),
            ],
          );
        },
      ),
    );
  }

  String _prettyDayMonth(String mmdd) {
    final parts = mmdd.split('-');
    if (parts.length != 2) return mmdd;
    final month = int.tryParse(parts[0]) ?? 1;
    final day = int.tryParse(parts[1]) ?? 1;
    return DateFormat('d MMM').format(DateTime(2000, month, day));
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'ADMIN' || 'SUPER_ADMIN' => trId('admin'),
      'EXECUTIVE_MEMBER' => trId('executive'),
      _ => trId('volunteer_4'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary)),
    );
  }
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: context.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w800, color: context.cText)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.cText)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11, color: context.cTextSecondary)),
        ]),
      ),
    );
  }
}
