import 'package:equatable/equatable.dart';
import 'package:squares/squares.dart';

abstract class OnlineGameEvent extends Equatable {
  const OnlineGameEvent();
  @override
  List<Object?> get props => [];
}

// App-initiated
class ConnectToGame extends OnlineGameEvent {
  final String gameId;
  final String token;
  final String myColor; // "white" | "black"
  const ConnectToGame({
    required this.gameId,
    required this.token,
    required this.myColor,
  });
  @override
  List<Object?> get props => [gameId, myColor];
}

class SendMove extends OnlineGameEvent {
  final Move move;
  const SendMove(this.move);
  @override
  List<Object?> get props => [move];
}

class SendResign extends OnlineGameEvent {
  const SendResign();
}

class SendOfferDraw extends OnlineGameEvent {
  const SendOfferDraw();
}

class SendAcceptDraw extends OnlineGameEvent {
  const SendAcceptDraw();
}

class SendDeclineDraw extends OnlineGameEvent {
  const SendDeclineDraw();
}

class FlipOnlineBoard extends OnlineGameEvent {
  const FlipOnlineBoard();
}

class SendFlag extends OnlineGameEvent {
  const SendFlag();
}

// Internal — fired every second when a timed game is in progress
class ClockTick extends OnlineGameEvent {
  const ClockTick();
}

// Server-push (translated from WS messages by bloc)
class ServerMessage extends OnlineGameEvent {
  final Map<String, dynamic> msg;
  const ServerMessage(this.msg);
  @override
  List<Object?> get props => [];
}
