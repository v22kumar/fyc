import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../service_locator.dart';
import 'chess_tournament_models.dart';

class ChessTournamentApi {
  static Dio get _dio => sl<ApiClient>().dio;
  static const _base = '/api/v1/chess/tournaments';

  static Future<List<ChessTournament>> list() async {
    final res = await _dio.get(_base);
    return ((res.data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChessTournament.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<ChessTournamentDetail> detail(String id) async {
    final res = await _dio.get('$_base/$id');
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<ChessTournament> create(
      {required String name, String? description, String? registrationDeadline}) async {
    final res = await _dio.post(_base, data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      if (registrationDeadline != null) 'registration_deadline': registrationDeadline,
    });
    return ChessTournament.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<void> register(String id) async {
    await _dio.post('$_base/$id/register');
  }

  /// Manager approves or rejects a pending registration.
  static Future<ChessTournamentDetail> decide(
      String tourId, String userId, bool approve) async {
    final res = await _dio.post('$_base/$tourId/registrations/$userId/decision',
        data: {'approve': approve});
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Manager manually closes registration (no more sign-ups).
  static Future<ChessTournamentDetail> closeRegistration(String id) async {
    final res = await _dio.post('$_base/$id/close');
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Manager reopens a prematurely-closed registration.
  static Future<ChessTournamentDetail> reopenRegistration(String id) async {
    final res = await _dio.post('$_base/$id/reopen');
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<ChessTournamentDetail> start(String id) async {
    final res = await _dio.post('$_base/$id/start');
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Manager activates the next round once the current one is fully decided.
  static Future<ChessTournamentDetail> nextRound(String id) async {
    final res = await _dio.post('$_base/$id/next-round');
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// A player marks themselves ready for their activated online match.
  static Future<ChessTournamentDetail> markReady(String tourId, String matchId) async {
    final res = await _dio.post('$_base/$tourId/matches/$matchId/ready');
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Returns the game_id for the match's Arena board.
  static Future<String> play(String tourId, String matchId) async {
    final res = await _dio.post('$_base/$tourId/matches/$matchId/play');
    return (res.data as Map)['game_id'] as String;
  }

  static Future<ChessTournamentDetail> reportResult(
      String tourId, String matchId, String winnerId) async {
    final res = await _dio.post('$_base/$tourId/matches/$matchId/result',
        data: {'winner_id': winnerId});
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Organizer sets how a match is conducted: 'APP' (online) or 'PHYSICAL'.
  /// For a physical match an optional venue + reporting time is attached and
  /// both players are notified.
  static Future<ChessTournamentDetail> setConduct(
      String tourId, String matchId, String mode,
      {String? venue, String? reportingTime}) async {
    final res = await _dio.post('$_base/$tourId/matches/$matchId/conduct', data: {
      'mode': mode,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
      if (reportingTime != null) 'reporting_time': reportingTime,
    });
    return ChessTournamentDetail.fromJson((res.data as Map).cast<String, dynamic>());
  }
}
