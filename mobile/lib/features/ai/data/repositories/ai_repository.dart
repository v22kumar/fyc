import '../datasources/ai_datasource.dart';

class AiRepository {
  final AiDatasource _datasource;

  AiRepository(this._datasource);

  Future<Map<String, dynamic>> getDailyDigest() async {
    try {
      return await _datasource.getDailyDigest();
    } catch (e) {
      // Return a fallback so the UI handles it gracefully if backend is down
      return {
        "summary": "Check out the news and events directly!",
      };
    }
  }

  Future<Map<String, dynamic>> getNewsSummary() async {
    try {
      return await _datasource.getNewsSummary();
    } catch (e) {
      return {
        "summary": "Check out the detailed news categories below for the latest updates.",
        "trending_topics": []
      };
    }
  }
}
