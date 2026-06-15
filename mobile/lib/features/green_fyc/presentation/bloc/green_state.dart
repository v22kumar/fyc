import 'package:equatable/equatable.dart';
import '../../domain/entities/drive_entity.dart';
import '../../domain/entities/green_stats.dart';
import '../../domain/entities/tree_entity.dart';

abstract class GreenState extends Equatable {
  const GreenState();
  @override
  List<Object?> get props => [];
}

class GreenInitial extends GreenState {
  const GreenInitial();
}

class GreenLoading extends GreenState {
  const GreenLoading();
}

class GreenLoaded extends GreenState {
  final GreenStats stats;
  final List<DriveEntity> drives;
  const GreenLoaded({required this.stats, required this.drives});
  @override
  List<Object?> get props => [stats, drives];
}

class GreenTreesLoaded extends GreenState {
  final List<TreeEntity> trees;
  const GreenTreesLoaded(this.trees);
  @override
  List<Object?> get props => [trees];
}

class GreenTreeRegisteredSuccess extends GreenState {
  final TreeEntity tree;
  const GreenTreeRegisteredSuccess(this.tree);
  @override
  List<Object?> get props => [tree];
}

class GreenFailure extends GreenState {
  final String message;
  const GreenFailure(this.message);
  @override
  List<Object?> get props => [message];
}
