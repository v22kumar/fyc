import 'package:equatable/equatable.dart';

abstract class SpectatorEvent extends Equatable {
  const SpectatorEvent();

  @override
  List<Object?> get props => [];
}

class ConnectSpectator extends SpectatorEvent {
  final String gameId;
  final String token;

  const ConnectSpectator({required this.gameId, required this.token});

  @override
  List<Object?> get props => [gameId, token];
}

class DisconnectSpectator extends SpectatorEvent {
  const DisconnectSpectator();
}
