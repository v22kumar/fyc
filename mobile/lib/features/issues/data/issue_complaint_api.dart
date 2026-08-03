import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../service_locator.dart';

/// Result of forwarding a complaint to the concerned department (P1 backend).
class ForwardResult {
  final bool sent; // true = actually emailed via SMTP
  final String? recipient;
  final String? departmentName;
  final bool needsManual; // true = no dept email set → show helpline/portal
  final String? helpline;
  final String? portalUrl;
  final String? subject;

  const ForwardResult({
    required this.sent,
    this.recipient,
    this.departmentName,
    this.needsManual = false,
    this.helpline,
    this.portalUrl,
    this.subject,
  });

  factory ForwardResult.fromJson(Map<String, dynamic> j) {
    final dept = j['department'];
    return ForwardResult(
      sent: j['sent'] as bool? ?? false,
      recipient: j['recipient'] as String?,
      departmentName: dept is Map ? dept['name_en'] as String? : null,
      needsManual: j['needs_manual'] as bool? ?? false,
      helpline: j['helpline'] as String?,
      portalUrl: j['portal_url'] as String?,
      subject: j['subject'] as String?,
    );
  }
}

class IssueComplaintApi {
  static Dio get _dio => sl<ApiClient>().dio;

  /// Compose (AI-drafted) + dispatch the complaint to the concerned department.
  static Future<ForwardResult> forward(String issueId, {bool useAi = true}) async {
    final res = await _dio.post('/api/v1/issues/$issueId/forward', data: {'use_ai': useAi});
    return ForwardResult.fromJson((res.data as Map).cast<String, dynamic>());
  }
}
