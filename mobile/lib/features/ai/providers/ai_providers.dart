import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/ai_datasource.dart';
import '../data/repositories/ai_repository.dart';
import '../../../service_locator.dart';
import '../../../core/network/api_client.dart';

// Provider for the Repository
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final apiClient = sl.get<ApiClient>();
  final datasource = AiDatasource(apiClient);
  return AiRepository(datasource);
});

// FutureProvider for the Daily Digest
final aiDailyDigestProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(aiRepositoryProvider);
  return repository.getDailyDigest();
});

// FutureProvider for the News Summary
final aiNewsSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(aiRepositoryProvider);
  return repository.getNewsSummary();
});
