import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_my_card_usecase.dart';
import 'membership_event.dart';
import 'membership_state.dart';

class MembershipBloc extends Bloc<MembershipEvent, MembershipState> {
  final GetMyCardUseCase _getMyCard;

  MembershipBloc({required GetMyCardUseCase getMyCard})
      : _getMyCard = getMyCard,
        super(const MembershipInitial()) {
    on<MembershipCardRequested>(_onCardRequested);
  }

  Future<void> _onCardRequested(
    MembershipCardRequested event,
    Emitter<MembershipState> emit,
  ) async {
    emit(const MembershipLoading());
    final result = await _getMyCard();
    result.fold(
      (f) => emit(MembershipFailure(f.message)),
      (card) => emit(MembershipLoaded(card)),
    );
  }
}
