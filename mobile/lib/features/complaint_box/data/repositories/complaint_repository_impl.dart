import '../../domain/entities/complaint_entities.dart';
import '../../domain/repositories/complaint_repository.dart';
import '../datasources/complaint_datasource.dart';
import '../models/complaint_models.dart';

class ComplaintRepositoryImpl implements ComplaintRepository {
  ComplaintRepositoryImpl(this._source);

  final ComplaintDataSource _source;

  @override
  Future<CallLadder> ladder({required String category, String? geographyId,
          double? latitude, double? longitude}) =>
      _source.ladder(category: category, geographyId: geographyId,
          latitude: latitude, longitude: longitude);

  @override
  Future<ComplaintState> load(String complaintId) => _source.load(complaintId);

  @override
  Future<ComplaintState> logCall(
    String complaintId, {
    required CallOutcome outcome,
    String? authorityId,
    String? authorityLabel,
    String? note,
  }) =>
      _source.logCall(complaintId, {
        'outcome': outcomeWire(outcome),
        if (authorityId != null) 'authority_id': authorityId,
        if (authorityLabel != null) 'authority_label': authorityLabel,
        if (note != null) 'note': note,
      });

  @override
  Future<ComplaintDraft> draft(
    String complaintId, {
    String? authorityId,
    bool bccClub = true,
    bool useAi = true,
  }) =>
      _source.draft(complaintId, {
        if (authorityId != null) 'authority_id': authorityId,
        'bcc_club': bccClub,
        'use_ai': useAi,
      });

  @override
  Future<ComplaintState> markSent(String complaintId,
          {String? authorityId, String? authorityLabel}) =>
      _source.post(complaintId, 'sent', {
        if (authorityId != null) 'authority_id': authorityId,
        if (authorityLabel != null) 'authority_label': authorityLabel,
      });

  @override
  Future<ComplaintState> markReplied(String complaintId, {String? note}) =>
      _source.post(complaintId, 'reply', {if (note != null) 'note': note});

  @override
  Future<ComplaintState> close(String complaintId,
          {required bool resolved, String? reason}) =>
      _source.post(complaintId, 'close',
          {'resolved': resolved, if (reason != null) 'reason': reason});

  @override
  Future<ComplaintState> reopen(String complaintId) =>
      _source.post(complaintId, 'reopen');

  @override
  Future<ComplaintState> handToClub(String complaintId) =>
      _source.post(complaintId, 'handover');

  @override
  Future<void> suggestContact(String authorityId,
          {String? phone, String? email, String? howTheyKnow}) =>
      _source.suggestContact(authorityId, {
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (howTheyKnow != null && howTheyKnow.isNotEmpty)
          'how_they_know': howTheyKnow,
      });
}
