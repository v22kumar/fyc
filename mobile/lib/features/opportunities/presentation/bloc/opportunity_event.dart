import 'package:equatable/equatable.dart';

abstract class OpportunityEvent extends Equatable {
  const OpportunityEvent();
  @override
  List<Object?> get props => [];
}

class OpportunityFetchRequested extends OpportunityEvent {
  const OpportunityFetchRequested();
}

class OpportunityApplyRequested extends OpportunityEvent {
  final String id;
  final String title;

  const OpportunityApplyRequested({required this.id, required this.title});

  @override
  List<Object?> get props => [id, title];
}
