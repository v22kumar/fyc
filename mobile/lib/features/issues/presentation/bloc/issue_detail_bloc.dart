import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/mark_issue_resolved_usecase.dart';
import '../../domain/usecases/log_email_sent_usecase.dart';
import '../../domain/entities/issue_entity.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class IssueDetailEvent extends Equatable {
  const IssueDetailEvent();
  @override
  List<Object?> get props => [];
}

class IssueMarkResolvedRequested extends IssueDetailEvent {
  final String id;
  const IssueMarkResolvedRequested(this.id);
  @override
  List<Object?> get props => [id];
}

class IssueLogEmailRequested extends IssueDetailEvent {
  final String id;
  const IssueLogEmailRequested(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class IssueDetailState extends Equatable {
  const IssueDetailState();
  @override
  List<Object?> get props => [];
}

class IssueDetailInitial extends IssueDetailState {}
class IssueDetailLoading extends IssueDetailState {}

class IssueDetailActionSuccess extends IssueDetailState {
  final String message;
  final IssueEntity? updatedIssue;
  const IssueDetailActionSuccess(this.message, {this.updatedIssue});
  @override
  List<Object?> get props => [message, updatedIssue];
}

class IssueDetailActionFailure extends IssueDetailState {
  final String message;
  const IssueDetailActionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class IssueDetailBloc extends Bloc<IssueDetailEvent, IssueDetailState> {
  final MarkIssueResolvedUseCase _markResolved;
  final LogEmailSentUseCase _logEmail;

  IssueDetailBloc({
    required MarkIssueResolvedUseCase markResolved,
    required LogEmailSentUseCase logEmail,
  })  : _markResolved = markResolved,
        _logEmail = logEmail,
        super(IssueDetailInitial()) {
    on<IssueMarkResolvedRequested>(_onMarkResolved);
    on<IssueLogEmailRequested>(_onLogEmail);
  }

  Future<void> _onMarkResolved(
    IssueMarkResolvedRequested event,
    Emitter<IssueDetailState> emit,
  ) async {
    emit(IssueDetailLoading());
    final result = await _markResolved(event.id);
    result.fold(
      (f) => emit(IssueDetailActionFailure(f.message)),
      (issue) => emit(IssueDetailActionSuccess('Issue marked as RESOLVED', updatedIssue: issue)),
    );
  }

  Future<void> _onLogEmail(
    IssueLogEmailRequested event,
    Emitter<IssueDetailState> emit,
  ) async {
    emit(IssueDetailLoading());
    final result = await _logEmail(event.id);
    result.fold(
      (f) => emit(IssueDetailActionFailure(f.message)),
      (_) => emit(const IssueDetailActionSuccess('Email logged successfully')),
    );
  }
}
