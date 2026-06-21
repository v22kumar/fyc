import 'package:equatable/equatable.dart';
import 'package:squares/squares.dart';

abstract class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class StartLocalGame extends GameEvent {
  final String whiteName;
  final String blackName;
  const StartLocalGame({required this.whiteName, required this.blackName});
  @override
  List<Object?> get props => [whiteName, blackName];
}

class MakeMove extends GameEvent {
  final Move move;
  const MakeMove(this.move);
  @override
  List<Object?> get props => [move];
}

class OfferDraw extends GameEvent {
  const OfferDraw();
}

class AcceptDraw extends GameEvent {
  const AcceptDraw();
}

class Resign extends GameEvent {
  final bool whiteResigns;
  const Resign({required this.whiteResigns});
  @override
  List<Object?> get props => [whiteResigns];
}

class FlipBoard extends GameEvent {
  const FlipBoard();
}

class NewGame extends GameEvent {
  const NewGame();
}

// Fired internally after game ends — fire-and-forget backend sync
class SubmitGameToBackend extends GameEvent {
  final Map<String, dynamic> payload;
  const SubmitGameToBackend(this.payload);
  @override
  List<Object?> get props => [];
}
