import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/blood_donor_model.dart';
import 'blood_request_models.dart';

import '../domain/repositories/blood_request_repository.dart';

/// Thin Dio client for the blood emergency endpoints (P2 backend).
class BloodRequestRepositoryImpl implements BloodRequestRepository {
  BloodRequestRepositoryImpl(this._api);

  final ApiClient _api;
  Dio get _dio => _api.dio;
  static const _base = '/api/v1/blood-requests';

  @override
  Future<BloodRequest> create({
    required String bloodGroup,
    int units = 1,
    String? hospital,
    double? lat,
    double? lng,
    String urgency = 'URGENT',
    String? note,
    String? contactPhone,
    /// Ask this one donor instead of alerting the neighbourhood.
    String? targetDonorId,
  }) async {
    final res = await _dio.post(_base, data: {
      'patient_blood_group': bloodGroup,
      'units_needed': units,
      if (hospital != null && hospital.isNotEmpty) 'hospital_name': hospital,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
      'urgency': urgency,
      if (note != null && note.isNotEmpty) 'note': note,
      if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
      if (targetDonorId != null) 'target_donor_id': targetDonorId,
    });
    return BloodRequest.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<BloodRequest>> list({String status = 'OPEN'}) async {
    final res = await _dio.get(_base, queryParameters: {'status_filter': status});
    return ((res.data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => BloodRequest.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<BloodRequest> detail(String id) async {
    final res = await _dio.get('$_base/$id');
    return BloodRequest.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<BloodRequest> pledge(String id, String status) async {
    final res = await _dio.post('$_base/$id/pledge', data: {'status': status});
    return BloodRequest.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Wake the whole club. Refused by the server once somebody has accepted,
  /// once it has already been sent, and beyond a few per club per day.
  @override
  Future<BloodRequest> broadcast(String id) async {
    final res = await _dio.post('$_base/$id/broadcast');
    return BloodRequest.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<BloodRequest> close(String id, {bool fulfilled = true}) async {
    final res = await _dio.post('$_base/$id/close', queryParameters: {'fulfilled': fulfilled});
    return BloodRequest.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// Location-aware donor search (P1 /nearby).
  @override
  Future<List<BloodDonorModel>> nearby({
    required double lat,
    required double lng,
    String? bloodGroup,
    double radiusKm = 15,
  }) async {
    final res = await _dio.get('/api/v1/blood-donors/nearby', queryParameters: {
      'lat': lat,
      'lng': lng,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      'radius_km': radiusKm,
    });
    return ((res.data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => BloodDonorModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
