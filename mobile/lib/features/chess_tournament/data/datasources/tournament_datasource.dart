import 'package:dio/dio.dart';

import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/tournament_entities.dart';
import '../models/tournament_models.dart';

/// The one place that talks to the server about tournaments.
///
/// Replaces a class of static methods that reached into the service locator
/// from inside widgets — which meant no seam to test against, and no way to
/// hand a screen a tournament without a network.
abstract class TournamentDataSource {
  Future<List<Tournament>> list();
  Future<TournamentDetail> detail(String id);
  Future<Tournament> create(Map<String, dynamic> body);
  Future<List<({String value, String label})>> timeControlOptions();
  Future<void> register(String id);
  Future<TournamentDetail> post(String id, String action,
      [Map<String, dynamic>? body]);
  Future<TournamentDetail> patchSettings(String id, Map<String, dynamic> body);
  Future<String> play(String id, String matchId);
}

class TournamentDataSourceImpl implements TournamentDataSource {
  TournamentDataSourceImpl(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/chess/tournaments';

  Map<String, dynamic> _map(Response r) =>
      (r.data as Map).cast<String, dynamic>();

  @override
  Future<List<Tournament>> list() async {
    try {
      final r = await _api.dio.get<dynamic>(_base);
      return [
        for (final j in (r.data as List? ?? []))
          if (j is Map) tournamentFromJson(j.cast<String, dynamic>())
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<TournamentDetail> detail(String id) async {
    try {
      return detailFromJson(_map(await _api.dio.get<dynamic>('$_base/$id')));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<Tournament> create(Map<String, dynamic> body) async {
    try {
      return tournamentFromJson(
          _map(await _api.dio.post<dynamic>(_base, data: body)));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<({String value, String label})>> timeControlOptions() async {
    try {
      final r = await _api.dio.get<dynamic>('$_base/meta/time-controls');
      return [
        for (final j in (r.data as List? ?? []))
          if (j is Map)
            (
              value: (j['value'] ?? '').toString(),
              label: (j['label'] ?? '').toString(),
            )
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<void> register(String id) async {
    try {
      await _api.dio.post<dynamic>('$_base/$id/register');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<TournamentDetail> post(String id, String action,
      [Map<String, dynamic>? body]) async {
    try {
      return detailFromJson(_map(
          await _api.dio.post<dynamic>('$_base/$id/$action', data: body ?? {})));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<TournamentDetail> patchSettings(
      String id, Map<String, dynamic> body) async {
    try {
      return detailFromJson(_map(
          await _api.dio.patch<dynamic>('$_base/$id/settings', data: body)));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<String> play(String id, String matchId) async {
    try {
      final r = await _api.dio
          .post<dynamic>('$_base/$id/matches/$matchId/play');
      return (_map(r)['game_id'] ?? '').toString();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
