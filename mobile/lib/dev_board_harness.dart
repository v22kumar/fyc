/// TEMPORARY dev entrypoint: boot straight into a live online board.
///
/// Used to drive the REAL app with REAL mouse input, rather than synthetic
/// gestures. Not part of the shipped app and not referenced by anything.
///
///   flutter run -d linux -t lib/dev_board_harness.dart \
///     --dart-define=API_BASE_URL=... --dart-define=GAME_ID=... \
///     --dart-define=TOKEN=...
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/storage/local_storage.dart';
import 'features/chess/presentation/bloc/online_game_bloc.dart';
import 'features/chess/presentation/bloc/online_game_event.dart';
import 'features/chess/presentation/pages/online_game_page.dart';
import 'service_locator.dart';

const _gameId = String.fromEnvironment('GAME_ID');
const _token = String.fromEnvironment('TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (!sl.isRegistered<LocalStorage>()) {
    sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
  }
  await sl<LocalStorage>().saveToken(_token);

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BlocProvider<OnlineGameBloc>(
      create: (_) => OnlineGameBloc()
        ..add(const ConnectToGame(
          gameId: _gameId,
          token: _token,
          myColor: 'white',
        )),
      child: const OnlineGamePage(gameId: _gameId),
    ),
  ));
}
