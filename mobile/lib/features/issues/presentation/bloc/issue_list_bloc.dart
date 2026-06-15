import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_issues_usecase.dart';
import 'issue_list_event.dart';
import 'issue_list_state.dart';

class IssueListBloc extends Bloc<IssueListEvent, IssueListState> {
  final FetchIssuesUseCase _fetchIssues;

  IssueListBloc({required FetchIssuesUseCase fetchIssues})
      : _fetchIssues = fetchIssues,
        super(const IssueListInitial()) {
    on<IssueListFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    IssueListFetchRequested event,
    Emitter<IssueListState> emit,
  ) async {
    emit(const IssueListLoading());
    final result = await _fetchIssues(status: event.status);
    result.fold(
      (f) => emit(IssueListFailure(f.message)),
      (issues) => emit(IssueListLoaded(issues, status: event.status)),
    );
  }
}
