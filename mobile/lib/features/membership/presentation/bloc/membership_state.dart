import 'package:equatable/equatable.dart';
import '../../domain/entities/membership_entity.dart';

abstract class MembershipState extends Equatable {
  const MembershipState();
  @override
  List<Object?> get props => [];
}

class MembershipInitial extends MembershipState {
  const MembershipInitial();
}

class MembershipLoading extends MembershipState {
  const MembershipLoading();
}

class MembershipLoaded extends MembershipState {
  final MembershipEntity card;
  const MembershipLoaded(this.card);
  @override
  List<Object?> get props => [card];
}

class MembershipFailure extends MembershipState {
  final String message;
  const MembershipFailure(this.message);
  @override
  List<Object?> get props => [message];
}
