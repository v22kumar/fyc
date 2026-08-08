import '../../domain/entities/work_entities.dart';
import '../../domain/repositories/work_repository.dart';
import '../datasources/work_datasource.dart';
import '../models/work_models.dart';

class WorkRepositoryImpl implements WorkRepository {
  WorkRepositoryImpl(this._source);

  final WorkDataSource _source;

  @override
  Future<List<WorkCategoryCount>> categories() async => [
        for (final c in await _source.categories())
          categoryFromJson((c as Map).cast<String, dynamic>())
      ];

  @override
  Future<List<WorkListing>> search({String? q, String? category, String? area}) async {
    final rows = await _source.search({
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null) 'category': category,
      if (area != null && area.isNotEmpty) 'area': area,
    });
    return [
      for (final r in rows) listingFromJson((r as Map).cast<String, dynamic>())
    ];
  }

  @override
  Future<WorkListing> listing(String id) async =>
      listingFromJson(await _source.listing(id));

  @override
  Future<void> recordView(String id) => _source.recordView(id);

  @override
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
  }) async =>
      myListingFromJson(await _source.create({
        'display_name': displayName,
        'category': category,
        'phone': phone,
        'kind': kind == ListingKind.business ? 'BUSINESS' : 'PERSON',
        if (about != null && about.isNotEmpty) 'about': about,
        if (area != null && area.isNotEmpty) 'area': area,
        if (whatsapp != null && whatsapp.isNotEmpty) 'whatsapp': whatsapp,
        if (address != null && address.isNotEmpty) 'address': address,
        if (hours != null && hours.isNotEmpty) 'hours': hours,
      }));

  @override
  Future<List<MyListing>> mine() async => [
        for (final r in await _source.mine())
          myListingFromJson((r as Map).cast<String, dynamic>())
      ];

  @override
  Future<void> report(String listingId,
          {required ReportReason reason, String? note}) =>
      _source.report(listingId, {
        'reason': reportReasonWire(reason),
        if (note != null && note.isNotEmpty) 'note': note,
      });
}
