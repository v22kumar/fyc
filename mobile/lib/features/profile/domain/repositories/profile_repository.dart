/// The profile feature's server conversations: the journey stats and the
/// profile-prompt catalogue/answers. Payloads stay dynamic — each caller
/// already owns its parsing.
abstract class ProfileRepository {
  Future<Map<String, dynamic>> myJourney();
  Future<Map<String, dynamic>?> promptCatalogue();
  Future<void> submitPromptAnswer(String path, Map<String, dynamic> body);
}
