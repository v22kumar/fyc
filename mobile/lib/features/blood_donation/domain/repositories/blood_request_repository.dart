import '../../data/blood_request_models.dart';
import '../../data/models/blood_donor_model.dart';

/// The blood-emergency endpoints — the seam the request flow, the donor map
/// and the ask-donor sheet bind to, replacing a class of static futures.
abstract class BloodRequestRepository {
  Future<BloodRequest> create({
    required String bloodGroup,
    int units = 1,
    String? hospital,
    double? lat,
    double? lng,
    String urgency = 'URGENT',
    String? note,
    String? contactPhone,
    String? targetDonorId,
  });

  Future<List<BloodRequest>> list({String status = 'OPEN'});
  Future<BloodRequest> detail(String id);
  Future<BloodRequest> pledge(String id, String status);
  Future<BloodRequest> broadcast(String id);
  Future<BloodRequest> close(String id, {bool fulfilled = true});

  /// Location-aware donor search (P1 /nearby).
  Future<List<BloodDonorModel>> nearby({
    required double lat,
    required double lng,
    String? bloodGroup,
    double radiusKm = 15,
  });
}
