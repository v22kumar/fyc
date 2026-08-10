import '../../../../core/network/api_client.dart';
import '../../domain/entities/search_hit.dart';
import '../../domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<SearchHit>> search(String query, {String? lang}) async {
    final response = await _api.dio.get('/api/v1/search', queryParameters: {
      'q': query,
      if (lang != null) 'lang': lang,
    });
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SearchHit.fromJson)
        .toList();
  }
}
