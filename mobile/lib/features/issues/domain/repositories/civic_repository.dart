/// The reviewed-complaint (civic ladder) endpoints — the seam the review
/// queue, timeline and review sheet bind to. Maps on purpose: the shapes are
/// the backend's own, and the field names match the API.
abstract class CivicRepository {
  Future<Map<String, dynamic>> queue();
  Future<Map<String, dynamic>> issue(String issueId);
  Future<Map<String, dynamic>> route(String issueId);
  Future<List<Map<String, dynamic>>> history(String issueId);
  Future<void> review(
    String issueId, {
    required bool approve,
    String? reason,
    String? departmentCodeOverride,
  });
  Future<Map<String, dynamic>> dispatch(String issueId);
}
