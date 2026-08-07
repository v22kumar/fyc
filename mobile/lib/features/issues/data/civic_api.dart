import '../../../core/network/api_client.dart';
import '../../../service_locator.dart';

/// The reviewed-complaint endpoints, in one place.
///
/// Thin on purpose: these are the shapes the backend already returns, and
/// inventing a parallel set of Dart models for them would be a second place to
/// keep the ladder's meaning correct. The screens read the maps directly and
/// the field names match the API, so a mismatch shows up as a missing key
/// rather than as a silently wrong value.
class CivicApi {
  static final _dio = sl<ApiClient>().dio;

  /// Waiting on us / waiting on them / overdue.
  static Future<Map<String, dynamic>> queue() async {
    final r = await _dio.get('/api/v1/issues/queue');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// The complaint itself — needed because the action a reviewer is offered
  /// depends on where it already is: approve, or send, or escalate.
  static Future<Map<String, dynamic>> issue(String issueId) async {
    final r = await _dio.get('/api/v1/issues/$issueId');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// The whole ladder for one complaint — every rung, and which can be reached.
  static Future<Map<String, dynamic>> route(String issueId) async {
    final r = await _dio.get('/api/v1/issues/$issueId/route');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Every rung already tried, oldest first.
  static Future<List<Map<String, dynamic>>> history(String issueId) async {
    final r = await _dio.get('/api/v1/issues/$issueId/history');
    return (r.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// The gate. Approving does not send anything — that is a second, deliberate
  /// action, so the letter can be read first.
  static Future<void> review(
    String issueId, {
    required bool approve,
    String? reason,
    String? departmentCodeOverride,
  }) async {
    await _dio.post('/api/v1/issues/$issueId/review', data: {
      'approve': approve,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (departmentCodeOverride != null)
        'department_code_override': departmentCodeOverride,
    });
  }

  /// Send to the next office on the ladder. The same call sends the first
  /// letter and every escalation.
  static Future<Map<String, dynamic>> dispatch(String issueId) async {
    final r = await _dio.post('/api/v1/issues/$issueId/dispatch');
    return Map<String, dynamic>.from(r.data as Map);
  }
}
