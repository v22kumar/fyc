import '../entities/complaint_entities.dart';

/// What the Complaint Box can do.
///
/// Note what is absent: there is no `setStatus`. In the direct lane the app
/// cannot observe whether a letter was sent or answered, so state changes only
/// ever arrive as statements somebody made — [logCall], [markSent],
/// [markReplied] — each recorded with its author.
abstract class ComplaintRepository {
  /// Every office worth trying, nearest first, including the ones nobody has
  /// filled in yet.
  /// Coordinates matter: without them the server cannot tell whether the
  /// report is inside the district this club's directory covers, and used to
  /// assume it was.
  Future<CallLadder> ladder({
    required String category,
    String? geographyId,
    double? latitude,
    double? longitude,
  });

  Future<ComplaintState> load(String complaintId);

  /// The member says they rang somebody. Becomes the opening line of any
  /// letter that follows.
  Future<ComplaintState> logCall(
    String complaintId, {
    required CallOutcome outcome,
    String? authorityId,
    String? authorityLabel,
    String? note,
  });

  /// Write the letter. [bccClub] off means genuinely off — no copy, no clock.
  Future<ComplaintDraft> draft(
    String complaintId, {
    String? authorityId,
    bool bccClub = true,
    bool useAi = true,
  });

  /// The member says they sent it. Only needed when the club's copy is off.
  Future<ComplaintState> markSent(String complaintId,
      {String? authorityId, String? authorityLabel});

  Future<ComplaintState> markReplied(String complaintId, {String? note});

  /// End it, whatever we know. [resolved] false is "I gave up" or "I sorted it
  /// another way" — both legitimate.
  Future<ComplaintState> close(String complaintId,
      {required bool resolved, String? reason});

  Future<ComplaintState> reopen(String complaintId);

  /// Hand it to the club.
  Future<ComplaintState> handToClub(String complaintId);

  /// Offer a contact for an office the directory has none for.
  ///
  /// It does not reach the directory until an organiser accepts it. A wrong
  /// number does not inconvenience one person — it sends every future
  /// complaint about that street to a stranger, over the club's name.
  Future<void> suggestContact(
    String authorityId, {
    String? phone,
    String? email,
    String? howTheyKnow,
  });
}
