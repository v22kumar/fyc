import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_constants.dart';
import '../storage/local_storage.dart';
import '../../service_locator.dart';

/// Sends uncaught errors to our own backend.
///
/// Without this the club is blind: a member's app can die and nobody ever finds
/// out — which matters most because there is no device to reproduce it on. The
/// backend groups identical failures, so one bug hitting fifty phones is one
/// row an organizer can act on.
///
/// Everything here is best-effort by design. An error reporter that throws, or
/// that blocks the UI, turns one bug into two.
class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  static const _endpoint = '/api/v1/diagnostics/errors';
  static const _flushAfter = Duration(seconds: 5);
  static const _maxQueue = 20;

  /// A BARE Dio, deliberately not the app's configured ApiClient: an error
  /// raised inside the API layer must not be reported through that same layer,
  /// or a failure there becomes an infinite loop.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  String? _appVersion;

  final List<Map<String, dynamic>> _queue = [];
  final Set<String> _seenThisSession = {};
  Timer? _flushTimer;
  bool _installed = false;

  /// The screen the member is on, so a report says where it happened.
  String? currentContext;

  /// Route every uncaught error — framework, platform and zone — to [report].
  ///
  /// Call once, as early as possible. Installing this must never itself be able
  /// to stop the app starting.
  void install() {
    if (_installed) return;
    _installed = true;

    // Best-effort: a version string is useful but never worth failing over.
    PackageInfo.fromPlatform().then((info) {
      _appVersion = '${info.version}+${info.buildNumber}';
    }).catchError((_) => null);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // Keep the normal console output — this adds reporting, it does not
      // replace the developer experience.
      previousOnError?.call(details);
      report(details.exception, details.stack,
          context: details.library ?? currentContext);
    };

    // Errors that escape the framework entirely (async gaps, platform channels).
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true; // handled: do not take the app down
    };
  }

  /// Queue an error. Safe to call from anywhere, including an error handler.
  void report(Object error, StackTrace? stack, {String? context}) {
    try {
      final message = error.toString();
      if (message.trim().isEmpty) return;

      final trace = stack?.toString();
      // One crash loop must not flood the queue — or the member's data plan.
      final key = '$message|${_firstFrame(trace)}';
      if (!_seenThisSession.add(key)) return;

      if (_queue.length >= _maxQueue) return;
      _queue.add({
        'message': message,
        if (trace != null) 'stack': _trim(trace),
        'platform': defaultTargetPlatform.name,
        if (_appVersion != null) 'app_version': _appVersion,
        if ((context ?? currentContext) != null)
          'context': (context ?? currentContext),
      });

      // Batch briefly: a crash usually arrives with friends.
      _flushTimer ??= Timer(_flushAfter, flush);
    } catch (_) {
      // Reporting must never throw.
    }
  }

  /// Send whatever is queued. Failures are swallowed and the queue is dropped —
  /// retrying forever would be worse than losing a report.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_queue.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      String? token;
      try {
        token = await sl<LocalStorage>().getToken();
      } catch (_) {
        // Not signed in, or storage unavailable — report anonymously.
      }
      await _dio.post<void>(
        '${ApiConstants.baseUrl}$_endpoint',
        data: jsonEncode({'errors': batch}),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Organization-ID': ApiConstants.defaultOrgId,
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          // Any status is fine; we never act on the response.
          validateStatus: (_) => true,
        ),
      );
    } catch (_) {
      // Offline, or the server is the thing that is broken. Either way, drop it.
    }
  }

  static String _firstFrame(String? trace) {
    if (trace == null) return '';
    for (final line in trace.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String _trim(String trace) {
    // A stack is useful for a few frames and noise after that.
    final lines = trace.split('\n');
    return lines.take(30).join('\n');
  }
}
