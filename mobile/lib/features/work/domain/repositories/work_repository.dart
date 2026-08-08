import '../entities/work_entities.dart';

/// What the work index can do.
///
/// Note what is absent: no rating, no approval, no chat, no payment. Those are
/// deliberate — see docs/work/02-screens.md.
abstract class WorkRepository {
  /// Only categories somebody is actually in.
  Future<List<WorkCategoryCount>> categories();

  /// Search. Free text matches the name and what they wrote about themselves,
  /// because "interlock brick" is never going to be a category.
  Future<List<WorkListing>> search({String? q, String? category, String? area});

  Future<WorkListing> listing(String id);

  /// Somebody opened it — feeds the count the owner sees.
  Future<void> recordView(String id);

  Future<MyListing> create({
    required String displayName,
    required String category,
    required String phone,
    ListingKind kind = ListingKind.person,
    String? about,
    String? area,
    String? whatsapp,
    String? address,
    String? hours,
  });

  Future<List<MyListing>> mine();

  /// Anyone can report — not only members, not only people who hired.
  Future<void> report(String listingId,
      {required ReportReason reason, String? note});
}
