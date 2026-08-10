import '../entities/search_hit.dart';

/// One query, one ranked list.
///
/// This used to be `Future<dynamic>`, with a comment explaining that the server
/// had historically answered with both a grouped map and a flat list and that
/// "the screen owns the branch that copes with each". A contract that cannot
/// say what it returns pushes the decision into the widget, where it is
/// untestable and where a shape change fails silently at runtime.
abstract class SearchRepository {
  Future<List<SearchHit>> search(String query, {String? lang});
}
