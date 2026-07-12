import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/drive_entity.dart';
import '../../domain/entities/green_stats.dart';
import '../bloc/green_bloc.dart';
import '../bloc/green_event.dart';
import '../bloc/green_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class GreenFycScreen extends StatefulWidget {
  const GreenFycScreen({super.key});

  @override
  State<GreenFycScreen> createState() => _GreenFycScreenState();
}

class _GreenFycScreenState extends State<GreenFycScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<GreenBloc>().add(const GreenFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Green FYC', ta: 'பசுமை FYC', hi: 'ग्रीन FYC', ml: 'ഗ്രീൻ FYC')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/green/register'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.park_rounded),
        label: Text(tr(en: 'Register a Tree', ta: 'மரம் பதிவு செய்க', hi: 'पेड़ पंजीकृत करें', ml: 'ഒരു മരം രജിസ്റ്റർ ചെയ്യുക')),
      ),
      body: BlocConsumer<GreenBloc, GreenState>(
        listener: (context, state) {
          if (state is GreenFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is GreenLoading || state is GreenInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GreenLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<GreenBloc>().add(const GreenFetchRequested());
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/impact_sapling.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: AppColors.primary.withOpacity(0.15)),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.0),
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 14,
                            child: Text(
                              tr(
                                en: 'Every tree is a promise to tomorrow',
                                ta: 'ஒவ்வொரு மரமும் ஒரு வாக்குறுதி',
                                hi: 'हर पेड़ कल के लिए एक वादा है',
                                ml: 'ഓരോ മരവും നാളെയ്ക്കുള്ള ഒരു വാഗ്ദാനമാണ്',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 6)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatsHeader(stats: state.stats, lang: lang),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    label: tr(
                      en: 'Plantation Drives',
                      ta: 'மரம் நடும் இயக்கங்கள்',
                      hi: 'वृक्षारोपण अभियान',
                      ml: 'വൃക്ഷത്തൈ നടീൽ യജ്ഞങ്ങൾ',
                    ),
                  ),
                  if (state.drives.isEmpty)
                    _EmptyDrives(lang: lang)
                  else
                    ...state.drives.map(
                      (d) => _DriveCard(drive: d, lang: lang),
                    ),
                ],
              ),
            );
          }
          if (state is GreenFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<GreenBloc>()
                        .add(const GreenFetchRequested()),
                    child: Text(
                        tr(en: 'Retry', ta: 'மீண்டும் முயற்சிக்கவும்', hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final GreenStats stats;
  final String lang;
  const _StatsHeader({required this.stats, required this.lang});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          icon: Icons.eco_rounded,
          value: stats.totalPlanted,
          label: tr(en: 'Total Planted', ta: 'மொத்தம் நடப்பட்டது', hi: 'कुल रोपित', ml: 'ആകെ നട്ടത്'),
        ),
        _StatCard(
          icon: Icons.grass_rounded,
          value: stats.growing,
          label: tr(en: 'Growing', ta: 'வளர்கிறது', hi: 'बढ़ रहे हैं', ml: 'വളരുന്നു'),
        ),
        _StatCard(
          icon: Icons.park_rounded,
          value: stats.mature,
          label: tr(en: 'Mature', ta: 'முதிர்ந்தது', hi: 'परिपक्व', ml: 'പക്വമായത്'),
        ),
        _StatCard(
          icon: Icons.local_florist_rounded,
          value: stats.dead,
          label: tr(en: 'Dead', ta: 'அழிந்தது', hi: 'मृत', ml: 'നശിച്ചത്'),
        ),
        _StatCard(
          icon: Icons.assignment_rounded,
          value: stats.drivesCount,
          label: tr(en: 'Drives', ta: 'இயக்கங்கள்', hi: 'अभियान', ml: 'യജ്ഞങ്ങൾ'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.cTextSecondary,
            ),
          ),
        ],
      ),
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.cTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DriveCard extends StatelessWidget {
  final DriveEntity drive;
  final String lang;
  const _DriveCard({required this.drive, required this.lang});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final location = drive.displayLocation(lang);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (drive.bannerUrl != null && drive.bannerUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusCard),
              ),
              child: Image.network(
                drive.bannerUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  color: AppColors.primarySurface,
                  child: const Center(
                    child: Icon(Icons.park_rounded, size: 40, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drive.displayTitle(lang),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: context.cTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      fmt.format(drive.driveDate.toLocal()),
                      style:
                          TextStyle(fontSize: 12, color: context.cTextSecondary),
                    ),
                  ],
                ),
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: context.cTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                              fontSize: 12, color: context.cTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: drive.progress,
                    minHeight: 8,
                    backgroundColor: context.cBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    en: '${drive.treeCount} / ${drive.targetCount} trees',
                    ta: '${drive.treeCount} / ${drive.targetCount} மரங்கள்',
                    hi: '${drive.treeCount} / ${drive.targetCount} पेड़',
                    ml: '${drive.treeCount} / ${drive.targetCount} മരങ്ങൾ',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.cTextSecondary,
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

class _EmptyDrives extends StatelessWidget {
  final String lang;
  const _EmptyDrives({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park_rounded, size: 64, color: AppColors.primary.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              tr(
                en: 'No plantation drives yet',
                ta: 'மரம் நடும் இயக்கங்கள் இல்லை',
                hi: 'अभी तक कोई वृक्षारोपण अभियान नहीं',
                ml: 'ഇതുവരെ വൃക്ഷത്തൈ നടീൽ യജ്ഞങ്ങളൊന്നുമില്ല',
              ),
              style: TextStyle(fontSize: 16, color: context.cTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
