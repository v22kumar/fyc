import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/thirukkural_datasource.dart';
import '../../data/models/thirukkural_model.dart';

/// "Thirukkural of the day" card shown on the home screen. Displays the same
/// couplet for everyone on a given date, in both Tamil and English.
///
/// Non-critical: if the fetch fails (e.g. offline) the card renders nothing
/// rather than showing an error, so it never disrupts the home screen.
class DailyThirukkuralCard extends StatefulWidget {
  const DailyThirukkuralCard({super.key});

  @override
  State<DailyThirukkuralCard> createState() => _DailyThirukkuralCardState();
}

class _DailyThirukkuralCardState extends State<DailyThirukkuralCard> {
  late Future<ThirukkuralModel> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ThirukkuralDataSource>().fetchDaily();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThirukkuralModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ThirukkuralSkeleton();
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink(); // fail silently
        }
        return _ThirukkuralContent(kural: snapshot.data!);
      },
    );
  }
}

class _ThirukkuralContent extends StatelessWidget {
  final ThirukkuralModel kural;
  const _ThirukkuralContent({required this.kural});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Text('📜', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'இன்றைய திருக்குறள்',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Thirukkural of the Day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#${kural.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tamil couplet
          Text(
            kural.line1,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.5,
              color: AppColors.primary,
            ),
          ),
          Text(
            kural.line2,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kural.tamilMeaning,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),

          // English couplet
          Text(
            kural.englishCouplet,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            kural.englishMeaning,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 14),
          // Section (paal) footer
          Row(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${kural.paalTa}  •  ${kural.paalEn}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThirukkuralSkeleton extends StatelessWidget {
  const _ThirukkuralSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 34, height: 34, borderRadius: BorderRadius.circular(17)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 13, width: 140),
                    SizedBox(height: 6),
                    ShimmerBox(height: 10, width: 100),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const ShimmerBox(height: 16),
          const SizedBox(height: 8),
          const ShimmerBox(height: 16, width: 220),
          const SizedBox(height: 14),
          const ShimmerBox(height: 12),
          const SizedBox(height: 6),
          const ShimmerBox(height: 12, width: 180),
        ],
      ),
    );
  }
}
