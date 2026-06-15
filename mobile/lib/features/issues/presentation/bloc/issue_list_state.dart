import 'package:equatable/equatable.dart';
import '../../domain/entities/issue_entity.dart';

abstract class IssueListState extends Equatable {
  const IssueListState();
  @override
  List<Object?> get props => [];
}

class IssueListInitial extends IssueListState {
  const IssueListInitial();
}

class IssueListLoading extends IssueListState {
  const IssueListLoading();
}

class IssueListLoaded extends IssueListState {
  final List<IssueEntity> issues;
  final String? status;
  const IssueListLoaded(this.issues, {this.status});
  @override
  List<Object?> get props => [issues, status];
}

class IssueListFailure extends IssueListState {
  final String message;
  const IssueListFailure(this.message);
  @override
  List<Object?> get props => [message];
}
