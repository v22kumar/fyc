/// What the Complaint Box is made of.
///
/// The unusual shape here is [ComplaintEvent]. It always names an author,
/// because in the direct lane nobody can observe whether a letter was sent or
/// answered — the app hands the draft to another application and loses sight of
/// it. So the interface renders "You said you sent this" rather than a status
/// badge that could be wrong in front of somebody at a government counter.
library;

import 'package:equatable/equatable.dart';

/// Who carries the complaint, which decides who can know anything about it.
enum ComplaintLane {
  /// The member sends from their own mail. They are the source of truth.
  self,

  /// The club sends. It can be complete, because the reply comes back to it.
  viaClub,
}

/// How bad it is, which decides what the app suggests — never what it allows.
enum ComplaintSeverity {
  /// A light out, a pothole. Call first: faster, and usually enough.
  routine,

  /// A danger, a repeated failure, an office that refused. Write, because a
  /// call leaves no evidence and a letter is dated and quotable.
  serious,
}

enum ComplaintAuthor { member, club, system }

enum CallOutcome { reached, noAnswer, promised }

/// One office worth trying, with enough context to decide whether to.
class LadderRung extends Equatable {
  const LadderRung({
    required this.position,
    this.authorityId,
    required this.departmentCode,
    required this.departmentName,
    required this.covers,
    required this.canCall,
    required this.canWrite,
    required this.waitDays,
    this.designation,
    this.phone,
    this.email,
  });

  final int position;

  /// Which office this is. The Write button needs it to address the letter to
  /// this rung rather than to nobody.
  final String? authorityId;

  final String departmentCode;
  final String departmentName;

  /// What this office covers, in words: "your ward", "the division". Without
  /// it "Assistant Engineer" does not tell anyone whether he is the right
  /// person to ring.
  final String covers;

  /// Reachability is two questions, not one. An office with a mobile and no
  /// published address can be rung today but not written to.
  final bool canCall;
  final bool canWrite;

  final int waitDays;
  final String? designation;
  final String? phone;
  final String? email;

  String get title => designation ?? departmentName;

  @override
  List<Object?> get props => [
        position, authorityId, departmentCode, designation, phone, email,
        canCall, canWrite,
      ];
}

/// Every office worth trying for one complaint, nearest first.
///
/// Deliberately the whole list. A member handed one number who is ignored by
/// that number has no visible next step, and stops.
class CallLadder extends Equatable {
  const CallLadder({
    required this.category,
    required this.rungs,
    this.placeName,
    this.fallbackHelpline,
    this.fallbackPortalUrl,
  });

  final String category;
  final List<LadderRung> rungs;
  final String? placeName;
  final String? fallbackHelpline;
  final String? fallbackPortalUrl;

  bool get hasAnyoneToCall => rungs.any((r) => r.canCall);

  @override
  List<Object?> get props => [category, rungs, placeName];
}

/// One thing that happened, and who says so.
class ComplaintEvent extends Equatable {
  const ComplaintEvent({
    required this.id,
    required this.author,
    required this.type,
    required this.at,
    this.authorName,
    this.authorityLabel,
    this.callOutcome,
    this.note,
  });

  final String id;
  final ComplaintAuthor author;
  final String type;
  final DateTime at;
  final String? authorName;
  final String? authorityLabel;
  final CallOutcome? callOutcome;
  final String? note;

  @override
  List<Object?> get props => [id, author, type, at];
}

/// The complaint, and everything anybody has said about it.
class ComplaintState extends Equatable {
  const ComplaintState({
    required this.id,
    required this.lane,
    required this.severity,
    required this.status,
    required this.isClosed,
    required this.events,
    this.waitingDays,
    this.closedReason,
  });

  final String id;
  final ComplaintLane lane;
  final ComplaintSeverity severity;
  final String status;
  final bool isClosed;
  final List<ComplaintEvent> events;

  /// Days since the last thing that left. Null when nothing has, which is not
  /// the same as nothing being known — a report nobody has acted on is not
  /// waiting for a reply.
  final int? waitingDays;

  final String? closedReason;

  @override
  List<Object?> get props => [id, lane, severity, status, isClosed, waitingDays];
}

/// A letter ready to hand to the member's own mail app.
class ComplaintDraft extends Equatable {
  const ComplaintDraft({
    required this.toLabel,
    required this.subject,
    required this.body,
    required this.cc,
    required this.bcc,
    required this.aiWritten,
    this.toEmail,
  });

  final String toLabel;
  final String subject;
  final String body;
  final List<String> cc;
  final List<String> bcc;

  /// False when the model was unavailable and the member's own words were
  /// used. The screen mentions it quietly rather than hiding it.
  final bool aiWritten;

  final String? toEmail;

  @override
  List<Object?> get props => [toLabel, subject, body, cc, bcc, aiWritten];
}
