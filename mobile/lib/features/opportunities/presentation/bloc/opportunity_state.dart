import 'package:equatable/equatable.dart';
import '../../domain/entities/opportunity_entity.dart';

abstract class OpportunityState extends Equatable {
  const OpportunityState();
  @override
  List<Object?> get props => [];
}

class OpportunityInitial extends OpportunityState {
  const OpportunityInitial();
}

class OpportunityLoading extends OpportunityState {
  const OpportunityLoading();
}

class OpportunityLoaded extends OpportunityState {
  final List<OpportunityEntity> opportunities;
  const OpportunityLoaded(this.opportunities);
  @override
  List<Object?> get props => [opportunities];
}

class OpportunityApplySuccess extends OpportunityState {
  final String title;
  const OpportunityApplySuccess(this.title);
  @override
  List<Object?> get props => [title];
}

class OpportunityFailure extends OpportunityState {
  final String message;
  const OpportunityFailure(this.message);
  @override
  List<Object?> get props => [message];
}
