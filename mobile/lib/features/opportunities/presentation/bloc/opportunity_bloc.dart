import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_opportunities_usecase.dart';
import '../../domain/usecases/apply_opportunity_usecase.dart';
import 'opportunity_event.dart';
import 'opportunity_state.dart';

class OpportunityBloc extends Bloc<OpportunityEvent, OpportunityState> {
  final FetchOpportunitiesUseCase _fetchOpportunities;
  final ApplyOpportunityUseCase _applyOpportunity;

  OpportunityBloc({
    required FetchOpportunitiesUseCase fetchOpportunities,
    required ApplyOpportunityUseCase applyOpportunity,
  })  : _fetchOpportunities = fetchOpportunities,
        _applyOpportunity = applyOpportunity,
        super(const OpportunityInitial()) {
    on<OpportunityFetchRequested>(_onFetch);
    on<OpportunityApplyRequested>(_onApply);
  }

  Future<void> _onFetch(
    OpportunityFetchRequested event,
    Emitter<OpportunityState> emit,
  ) async {
    emit(const OpportunityLoading());
    final result = await _fetchOpportunities();
    result.fold(
      (f) => emit(OpportunityFailure(f.message)),
      (opportunities) => emit(OpportunityLoaded(opportunities)),
    );
  }

  Future<void> _onApply(
    OpportunityApplyRequested event,
    Emitter<OpportunityState> emit,
  ) async {
    emit(const OpportunityLoading());
    final result = await _applyOpportunity(event.id);
    result.fold(
      (f) => emit(OpportunityFailure(f.message)),
      (_) => emit(OpportunityApplySuccess(event.title)),
    );
  }
}
