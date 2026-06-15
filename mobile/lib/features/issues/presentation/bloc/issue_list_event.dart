import 'package:equatable/equatable.dart';

abstract class IssueListEvent extends Equatable {
  const IssueListEvent();
  @override
  List<Object?> get props => [];
}

class IssueListFetchRequested extends IssueListEvent {
  final String? status;
  const IssueListFetchRequested({this.status});
  @override
  List<Object?> get props => [status];
}
