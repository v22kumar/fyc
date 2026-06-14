import 'package:equatable/equatable.dart';
import '../../domain/entities/public_issue_entity.dart';

abstract class IssueState extends Equatable {
  const IssueState();
  @override
  List<Object?> get props => [];
}

class IssueInitial extends IssueState {
  const IssueInitial();
}

class IssueLoading extends IssueState {
  const IssueLoading();
}

class IssueSubmitSuccess extends IssueState {
  final PublicIssueEntity issue;
  const IssueSubmitSuccess(this.issue);
  @override
  List<Object?> get props => [issue];
}

class IssueFailure extends IssueState {
  final String message;
  const IssueFailure(this.message);
  @override
  List<Object?> get props => [message];
}
