import 'package:equatable/equatable.dart';

class GreenStats extends Equatable {
  final int totalPlanted;
  final int growing;
  final int mature;
  final int dead;
  final int drivesCount;

  const GreenStats({
    required this.totalPlanted,
    required this.growing,
    required this.mature,
    required this.dead,
    required this.drivesCount,
  });

  @override
  List<Object?> get props => [totalPlanted, growing, mature, dead, drivesCount];
}
