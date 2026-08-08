/// The local work index.
///
/// See docs/work/01-architecture.md. The shape that matters: there is one kind
/// of thing here, a [WorkListing], owned by a person or a shop — not separate
/// "worker" and "employer" populations, because a member who fixes motorbikes
/// needs a tutor for his sister.
library;

import 'package:equatable/equatable.dart';

enum ListingKind { person, business }

/// What is simply true about a listing.
///
/// Deliberately not a score. A five-star average in a town this size is a
/// popularity contest with a feud attached, and people do not believe them
/// anyway. These are facts that accumulate without anybody's judgement, shown
/// plainly so the person looking can decide for themselves.
class ListingTrust extends Equatable {
  const ListingTrust({
    required this.phoneVerified,
    required this.jobsConfirmed,
    required this.isNew,
    this.memberSinceYear,
  });

  final bool phoneVerified;

  /// Jobs the person who *received* the work confirmed. A self-reported total
  /// is the same claim as before, wearing a number.
  final int jobsConfirmed;

  /// Nothing has happened yet, and the card says so. Letting an empty record
  /// look like a good one is how a directory spends the only trust it has.
  final bool isNew;

  final int? memberSinceYear;

  @override
  List<Object?> get props => [phoneVerified, jobsConfirmed, isNew, memberSinceYear];
}

class WorkListing extends Equatable {
  const WorkListing({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.category,
    required this.phone,
    required this.trust,
    this.about,
    this.area,
    this.whatsapp,
    this.address,
    this.hours,
    this.isSample = false,
  });

  final String id;
  final ListingKind kind;
  final String displayName;
  final String category;
  final String phone;
  final ListingTrust trust;

  /// What they do in their own words — where "interlock brick work" lives.
  /// The category is for browsing; this is for finding.
  final String? about;

  /// The part of town. Nagercoil is one place, but Vadasery and Putheri are
  /// twenty minutes apart and that decides whether somebody rings.
  final String? area;

  final String? whatsapp;
  final String? address;
  final String? hours;

  /// Seeded by the club so the index is not empty on the first day. Shown as
  /// a sample, and never dialled — India reserves no fictional phone range, so
  /// the number on one of these cannot be allowed to reach anybody.
  final bool isSample;

  @override
  List<Object?> get props => [id, displayName, category, phone, trust, isSample];
}

/// A listing as its owner sees it — with the one number that tells them
/// anything happened.
class MyListing extends Equatable {
  const MyListing({
    required this.listing,
    required this.viewCount,
    required this.isActive,
    required this.isHidden,
  });

  final WorkListing listing;

  /// Somebody who listed once and heard nothing concludes it did not work.
  /// This is the only honest thing the app can show them.
  final int viewCount;

  final bool isActive;
  final bool isHidden;

  @override
  List<Object?> get props => [listing, viewCount, isActive, isHidden];
}

/// A category and how many people are in it.
///
/// Categories with nobody in them are never returned. A tile reading
/// "Plumbing 0" is an advertisement that the app does not work.
class WorkCategoryCount extends Equatable {
  const WorkCategoryCount({required this.code, required this.count});
  final String code;
  final int count;

  @override
  List<Object?> get props => [code, count];
}

/// Why somebody is reporting a listing.
///
/// Separate reasons, because "the number does not work" and "he took money and
/// did not come" need completely different responses.
enum ReportReason {
  wrongNumber,
  notDoingThisWork,
  tookMoney,
  rudeOrUnsafe,
  notARealPerson,
  other,
}

String reportReasonWire(ReportReason r) => switch (r) {
      ReportReason.wrongNumber => 'WRONG_NUMBER',
      ReportReason.notDoingThisWork => 'NOT_DOING_THIS_WORK',
      ReportReason.tookMoney => 'TOOK_MONEY',
      ReportReason.rudeOrUnsafe => 'RUDE_OR_UNSAFE',
      ReportReason.notARealPerson => 'NOT_A_REAL_PERSON',
      ReportReason.other => 'OTHER',
    };
