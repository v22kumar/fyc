import 'package:equatable/equatable.dart';

abstract class DirectoryEvent extends Equatable {
  const DirectoryEvent();
  @override
  List<Object?> get props => [];
}

class DirectoryFetchRequested extends DirectoryEvent {
  final String? category;
  const DirectoryFetchRequested({this.category});
  @override
  List<Object?> get props => [category];
}
