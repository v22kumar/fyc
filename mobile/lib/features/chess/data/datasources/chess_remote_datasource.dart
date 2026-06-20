import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/chess_game_model.dart';

abstract class ChessRemoteDataSource {
  Future<ChessGameModel> submitGame(Map<String, dynamic> payload);
  Future<List<ChessGameModel>> myGames({int limit = 30});
  Future<ChessStatsModel> myStats();
}

class ChessRemoteDataSourceImpl implements ChessRemoteDataSource {
  final ApiClient _client;

  ChessRemoteDataSourceImpl(this._client);

  @override
  Future<ChessGameModel> submitGame(Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.chessGames,
        data: payload,
      );
      return ChessGameModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<ChessGameModel>> myGames({int limit = 30}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.chessMyGames,
        queryParameters: {'limit': limit},
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ChessGameModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ChessStatsModel> myStats() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessMyStats);
      return ChessStatsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
