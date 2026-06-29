import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/blood_donor_model.dart';

abstract class BloodDonorDataSource {
  Future<List<BloodDonorModel>> searchDonors({
    String? bloodGroup,
    String? geographyId,
    bool nearby = false,
    bool availableOnly = true,
  });

  Future<BloodDonorModel> registerAsDonor({
    required String bloodGroup,
    bool isAvailable = true,
    String? geographyId,
    String? lastDonationDate,
  });

  Future<Map<String, String>> requestContact(String donorId);

  Future<BloodDonorModel> updateAvailability({
    required String donorId,
    required bool isAvailable,
  });
}

class BloodDonorDataSourceImpl implements BloodDonorDataSource {
  final ApiClient _client;

  BloodDonorDataSourceImpl(this._client);

  @override
  Future<List<BloodDonorModel>> searchDonors({
    String? bloodGroup,
    String? geographyId,
    bool nearby = false,
    bool availableOnly = true,
  }) async {
    try {
      final params = <String, dynamic>{'available_only': availableOnly};
      if (bloodGroup != null && bloodGroup.isNotEmpty) {
        params['blood_group'] = bloodGroup;
      }
      if (geographyId != null && geographyId.isNotEmpty) {
        params['geography_id'] = geographyId;
        params['nearby'] = nearby;
      }
      final response = await _client.dio.get(
        ApiConstants.bloodDonors,
        queryParameters: params,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => BloodDonorModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<BloodDonorModel> registerAsDonor({
    required String bloodGroup,
    bool isAvailable = true,
    String? geographyId,
    String? lastDonationDate,
  }) async {
    try {
      final body = <String, dynamic>{
        'blood_group': bloodGroup,
        'is_available': isAvailable,
      };
      if (geographyId != null) body['geography_id'] = geographyId;
      if (lastDonationDate != null) body['last_donation_date'] = lastDonationDate;

      final response = await _client.dio.post(
        ApiConstants.registerDonor,
        data: body,
      );
      return BloodDonorModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<Map<String, String>> requestContact(String donorId) async {
    try {
      final response = await _client.dio
          .post('${ApiConstants.bloodDonors}/$donorId/request-contact');
      final data = response.data as Map<String, dynamic>;
      return {
        'phone_number': data['phone_number'] as String,
        'whatsapp_link': data['whatsapp_link'] as String,
      };
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<BloodDonorModel> updateAvailability({
    required String donorId,
    required bool isAvailable,
  }) async {
    try {
      final response = await _client.dio.patch(
        '${ApiConstants.bloodDonors}/$donorId/availability',
        data: {'is_available': isAvailable},
      );
      return BloodDonorModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
