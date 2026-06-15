import '../../domain/entities/green_stats.dart';

class GreenStatsModel extends GreenStats {
  const GreenStatsModel({
    required super.totalPlanted,
    required super.growing,
    required super.mature,
    required super.dead,
    required super.drivesCount,
  });

  factory GreenStatsModel.fromJson(Map<String, dynamic> json) {
    return GreenStatsModel(
      totalPlanted: (json['total_planted'] as num?)?.toInt() ?? 0,
      growing: (json['growing'] as num?)?.toInt() ?? 0,
      mature: (json['mature'] as num?)?.toInt() ?? 0,
      dead: (json['dead'] as num?)?.toInt() ?? 0,
      drivesCount: (json['drives_count'] as num?)?.toInt() ?? 0,
    );
  }
}
