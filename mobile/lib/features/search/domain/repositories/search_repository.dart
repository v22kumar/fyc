/// One query, grouped results. The payload is returned raw: the server has
/// answered with both a grouped map and a flat list historically, and the
/// screen owns the branch that copes with each.
abstract class SearchRepository {
  Future<dynamic> search(String query);
}
