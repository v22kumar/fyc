import '../../domain/entities/work_entities.dart';

ListingTrust _trustFromJson(Map<String, dynamic>? j) => ListingTrust(
      phoneVerified: j?['phone_verified'] as bool? ?? false,
      jobsConfirmed: (j?['jobs_confirmed'] as num?)?.toInt() ?? 0,
      isNew: j?['is_new'] as bool? ?? true,
      memberSinceYear: (j?['member_since_year'] as num?)?.toInt(),
    );

WorkListing listingFromJson(Map<String, dynamic> j) => WorkListing(
      id: j['id'] as String? ?? '',
      kind: (j['kind'] == 'BUSINESS') ? ListingKind.business : ListingKind.person,
      displayName: j['display_name'] as String? ?? '',
      category: j['category'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      about: j['about'] as String?,
      area: j['area'] as String?,
      whatsapp: j['whatsapp'] as String?,
      address: j['address'] as String?,
      hours: j['hours'] as String?,
      trust: _trustFromJson((j['trust'] as Map?)?.cast<String, dynamic>()),
    );

MyListing myListingFromJson(Map<String, dynamic> j) => MyListing(
      listing: listingFromJson(j),
      viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? true,
      isHidden: j['is_hidden'] as bool? ?? false,
    );

WorkCategoryCount categoryFromJson(Map<String, dynamic> j) => WorkCategoryCount(
      code: j['code'] as String? ?? '',
      count: (j['count'] as num?)?.toInt() ?? 0,
    );
