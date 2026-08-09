/// The Home dashboard's reads — one card, one call. The five cards inside
/// home_screen.dart each owned a raw Dio GET; this seam is what they bind to
/// instead. Payloads stay dynamic deliberately: every card already parses its
/// own JSON and no two cards share a shape.
abstract class HomeRepository {
  Future<List<dynamic>> notifications();
  Future<List<dynamic>> events();
  Future<List<dynamic>> communityFeed({int limit = 5});
  Future<Map<String, dynamic>> communityStats();
  Future<Map<String, dynamic>> liveScores();
  Future<Map<String, dynamic>> weather({required double lat, required double lon});
  Future<Map<String, dynamic>> goldPrice();
}
