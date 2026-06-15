import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/submit_issue_usecase.dart';
import 'issue_event.dart';
import 'issue_state.dart';

class IssueBloc extends Bloc<IssueEvent, IssueState> {
  final SubmitIssueUseCase _submitIssue;

  IssueBloc({required SubmitIssueUseCase submitIssue})
      : _submitIssue = submitIssue,
        super(const IssueInitial()) {
    on<IssueSubmitRequested>(_onSubmit);
  }

  Future<void> _onSubmit(
    IssueSubmitRequested event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());
    final result = await _submitIssue(
      category: event.category,
      descriptionTa: event.descriptionTa,
      descriptionEn: event.descriptionEn,
      latitude: event.latitude,
      longitude: event.longitude,
      photoUrl: event.photoUrl,
    );
    result.fold(
      (f) => emit(IssueFailure(f.message)),
      (issue) => emit(IssueSubmitSuccess(issue)),
    );
  }
}
