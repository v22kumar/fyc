import 'package:equatable/equatable.dart';
import '../../domain/entities/contact_entity.dart';

abstract class DirectoryState extends Equatable {
  const DirectoryState();
  @override
  List<Object?> get props => [];
}

class DirectoryInitial extends DirectoryState {
  const DirectoryInitial();
}

class DirectoryLoading extends DirectoryState {
  const DirectoryLoading();
}

class DirectoryLoaded extends DirectoryState {
  final List<ContactEntity> contacts;
  const DirectoryLoaded(this.contacts);
  @override
  List<Object?> get props => [contacts];
}

class DirectoryFailure extends DirectoryState {
  final String message;
  const DirectoryFailure(this.message);
  @override
  List<Object?> get props => [message];
}
