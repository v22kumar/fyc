import '../../../../core/network/api_client.dart';
import '../../domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<dynamic> search(String query) async =>
      (await _api.dio.get('/api/v1/search', queryParameters: {'q': query}))
          .data;
}
