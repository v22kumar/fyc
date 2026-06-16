import 'package:dio/dio.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/drive_model.dart';
import '../models/green_stats_model.dart';
import '../models/tree_model.dart';

abstract class GreenDataSource {
  Future<GreenStatsModel> fetchStats();
  Future<List<DriveModel>> fetchDrives();
  Future<DriveModel> fetchDrive(String driveId);
  Future<List<TreeModel>> fetchTrees({String? driveId});
  Future<TreeModel> registerTree({
    String? driveId,
    String? speciesTa,
    String? speciesEn,
    double? latitude,
    double? longitude,
    String? geographyId,
    required DateTime plantedDate,
    String? photoUrl,
    String? notes,
  });
}

class GreenDataSourceImpl implements GreenDataSource {
  final ApiClient _client;
  GreenDataSourceImpl(this._client);

  // NOTE: api_constants.dart is read-only here; paths are inlined.
  static const String _stats = '/api/v1/green/stats';
  static const String _drives = '/api/v1/green/drives';
  static const String _trees = '/api/v1/green/trees';

  @override
  Future<GreenStatsModel> fetchStats() async {
    try {
      final response = await _client.dio.get(_stats);
      return GreenStatsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<DriveModel>> fetchDrives() async {
    try {
      final response = await _client.dio.get(_drives);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => DriveModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<DriveModel> fetchDrive(String driveId) async {
    try {
      final response = await _client.dio.get('$_drives/$driveId');
      return DriveModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<TreeModel>> fetchTrees({String? driveId}) async {
    try {
      final response = await _client.dio.get(
        _trees,
        queryParameters: driveId != null ? {'drive_id': driveId} : null,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => TreeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<TreeModel> registerTree({
    String? driveId,
    String? speciesTa,
    String? speciesEn,
    double? latitude,
    double? longitude,
    String? geographyId,
    required DateTime plantedDate,
    String? photoUrl,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        if (driveId != null) 'drive_id': driveId,
        if (speciesTa != null) 'species_ta': speciesTa,
        if (speciesEn != null) 'species_en': speciesEn,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (geographyId != null) 'geography_id': geographyId,
        'planted_date':
            plantedDate.toIso8601String().split('T').first, // YYYY-MM-DD
        if (photoUrl != null) 'photo_url': photoUrl,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post(_trees, data: body);
      return TreeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
