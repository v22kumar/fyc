import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/features/work/domain/entities/work_entities.dart';
import 'package:fyc_connect/features/work/domain/repositories/work_repository.dart';
import 'package:fyc_connect/features/work/presentation/bloc/work_bloc.dart';

class _Fake implements WorkRepository {
  final List<String> calls = [];
  bool viewThrows = false;
  List<WorkListing> results = const [];
  List<WorkCategoryCount> cats = const [
    WorkCategoryCount(code: 'CARPENTRY', count: 3),
  ];

  @override
  Future<List<WorkCategoryCount>> categories() async {
    calls.add('categories');
    return cats;
  }

  @override
  Future<List<WorkListing>> search({String? q, String? category, String? area}) async {
    calls.add('search:q=$q:cat=$category');
    return results;
  }

  @override
  Future<WorkListing> listing(String id) async => results.first;

  @override
  Future<void> recordView(String id) async {
    calls.add('view:$id');
    if (viewThrows) throw Exception('offline');
  }

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
  }) async {
    calls.add('create:$displayName:$category');
    return MyListing(
      listing: WorkListing(
        id: 'l1', kind: kind, displayName: displayName, category: category,
        phone: phone,
        trust: const ListingTrust(
            phoneVerified: true, jobsConfirmed: 0, isNew: true),
      ),
      viewCount: 0, isActive: true, isHidden: false,
    );
  }

  @override
  Future<List<MyListing>> mine() async {
    calls.add('mine');
    return [];
  }

  @override
  Future<void> report(String listingId,
      {required ReportReason reason, String? note}) async {
    calls.add('report:$listingId:${reportReasonWire(reason)}');
  }
}

WorkListing _listing({bool isNew = true, int jobs = 0}) => WorkListing(
      id: 'l1', kind: ListingKind.person, displayName: 'Murugan A.',
      category: 'CARPENTRY', phone: '9443132365', area: 'Vadasery',
      about: 'interlock brick work',
      trust: ListingTrust(
          phoneVerified: true, jobsConfirmed: jobs, isNew: isNew,
          memberSinceYear: 2022),
    );

void main() {
  late _Fake repo;
  late WorkBloc bloc;

  setUp(() {
    repo = _Fake();
    bloc = WorkBloc(repo);
  });
  tearDown(() => bloc.close());

  test('opening loads only the categories somebody is in', () async {
    bloc.add(const WorkOpened());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.categories.single.code, 'CARPENTRY');
    expect(bloc.state.categories.single.count, 3);
  });

  test('"nothing found" and "you have not looked yet" are different states',
      () async {
    // Without this distinction an untouched screen tells a member the app is
    // empty when it is not.
    bloc.add(const WorkOpened());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.hasSearched, isFalse);

    bloc.add(const WorkSearched(q: 'nobody'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.hasSearched, isTrue);
    expect(bloc.state.results, isEmpty);
  });

  test('searching keeps the categories on screen', () async {
    // Replacing the whole page with a spinner on every search is how a
    // directory feels slow even when it is not.
    bloc.add(const WorkOpened());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WorkSearched(q: 'carpenter'));
    expect(bloc.state.loading, isFalse);
    expect(bloc.state.categories, isNotEmpty);
  });

  test('a failed view count never interrupts anything', () async {
    // Somebody is reading a phone number. A analytics call that fails must not
    // surface as an error over the thing they came for.
    repo.viewThrows = true;
    bloc.add(const ListingViewed('l1'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.failure, isNull);
  });

  test('free text search reaches the repository verbatim', () async {
    // "interlock brick" is never going to be a category and is exactly what
    // somebody types.
    bloc.add(const WorkSearched(q: 'interlock brick'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, contains('search:q=interlock brick:cat=null'));
  });

  test('a category search carries the category', () async {
    bloc.add(const WorkSearched(category: 'CARPENTRY'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, contains('search:q=null:cat=CARPENTRY'));
    expect(bloc.state.activeCategory, 'CARPENTRY');
  });

  test('reporting is recorded with its reason', () async {
    bloc.add(const ListingReported('l1', reason: ReportReason.tookMoney));
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, contains('report:l1:TOOK_MONEY'));
    expect(bloc.state.reported, isTrue);
  });

  test('a new listing is marked new rather than left blank', () async {
    repo.results = [_listing()];
    bloc.add(const WorkSearched(q: 'x'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.results.single.trust.isNew, isTrue);
  });

  test('a worked listing carries confirmed jobs, and no score', () async {
    repo.results = [_listing(isNew: false, jobs: 9)];
    bloc.add(const WorkSearched(q: 'x'));
    await Future<void>.delayed(Duration.zero);

    final trust = bloc.state.results.single.trust;
    expect(trust.jobsConfirmed, 9);
    expect(trust.isNew, isFalse);
    // There is no rating field to assert on, deliberately — a five-star
    // average in a town this size is a popularity contest with a feud attached.
    expect(trust.props.length, 4);
  });
}
