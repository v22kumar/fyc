import 'package:equatable/equatable.dart';
import '../../domain/entities/community_profile_entity.dart';

abstract class CommunityState extends Equatable {
  const CommunityState();
  @override
  List<Object?> get props => [];
}

class CommunityInitial extends CommunityState {
  const CommunityInitial();
}

class CommunityLoading extends CommunityState {
  const CommunityLoading();
}

class CommunityLoaded extends CommunityState {
  final List<CommunityProfileEntity> profiles;
  const CommunityLoaded(this.profiles);
  @override
  List<Object?> get props => [profiles];
}

class CommunityFailure extends CommunityState {
  final String message;
  const CommunityFailure(this.message);
  @override
  List<Object?> get props => [message];
}
