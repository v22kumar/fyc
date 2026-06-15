import 'package:equatable/equatable.dart';

abstract class MembershipEvent extends Equatable {
  const MembershipEvent();
  @override
  List<Object?> get props => [];
}

class MembershipCardRequested extends MembershipEvent {
  const MembershipCardRequested();
}
