import 'package:equatable/equatable.dart';

abstract class CommunityEvent extends Equatable {
  const CommunityEvent();
  @override
  List<Object?> get props => [];
}

class CommunityFetchRequested extends CommunityEvent {
  const CommunityFetchRequested();
}
