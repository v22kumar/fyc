import '../../domain/entities/complaint_entities.dart';

ComplaintAuthor _author(String? v) => switch (v) {
      'FYC' => ComplaintAuthor.club,
      'SYSTEM' => ComplaintAuthor.system,
      _ => ComplaintAuthor.member,
    };

CallOutcome? _outcome(String? v) => switch (v) {
      'REACHED' => CallOutcome.reached,
      'NO_ANSWER' => CallOutcome.noAnswer,
      'PROMISED' => CallOutcome.promised,
      _ => null,
    };

String outcomeWire(CallOutcome o) => switch (o) {
      CallOutcome.reached => 'REACHED',
      CallOutcome.noAnswer => 'NO_ANSWER',
      CallOutcome.promised => 'PROMISED',
    };

LadderRung rungFromJson(Map<String, dynamic> j) => LadderRung(
      position: (j['position'] as num?)?.toInt() ?? 0,
      departmentCode: j['department_code'] as String? ?? '',
      departmentName: j['department_name_en'] as String? ?? '',
      covers: j['covers_en'] as String? ?? '',
      canCall: j['can_call'] as bool? ?? false,
      canWrite: j['can_write'] as bool? ?? false,
      waitDays: (j['wait_days'] as num?)?.toInt() ?? 14,
      designation: j['designation_en'] as String?,
      phone: j['phone'] as String?,
      email: j['email'] as String?,
    );

CallLadder ladderFromJson(Map<String, dynamic> j) => CallLadder(
      category: j['category'] as String? ?? '',
      placeName: j['place_name'] as String?,
      fallbackHelpline: j['fallback_helpline'] as String?,
      fallbackPortalUrl: j['fallback_portal_url'] as String?,
      rungs: [
        for (final r in (j['rungs'] as List? ?? []))
          rungFromJson(r as Map<String, dynamic>)
      ],
    );

ComplaintEvent eventFromJson(Map<String, dynamic> j) => ComplaintEvent(
      id: j['id'] as String? ?? '',
      author: _author(j['author'] as String?),
      authorName: j['author_name'] as String?,
      type: j['event_type'] as String? ?? '',
      authorityLabel: j['authority_label'] as String?,
      callOutcome: _outcome(j['call_outcome'] as String?),
      note: j['note'] as String?,
      at: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );

ComplaintState stateFromJson(Map<String, dynamic> j) => ComplaintState(
      id: j['id'] as String? ?? '',
      lane:
          (j['lane'] == 'VIA_CLUB') ? ComplaintLane.viaClub : ComplaintLane.self,
      severity: (j['severity'] == 'SERIOUS')
          ? ComplaintSeverity.serious
          : ComplaintSeverity.routine,
      status: j['status'] as String? ?? '',
      waitingDays: (j['waiting_days'] as num?)?.toInt(),
      isClosed: j['is_closed'] as bool? ?? false,
      closedReason: j['closed_reason'] as String?,
      events: [
        for (final e in (j['events'] as List? ?? []))
          eventFromJson(e as Map<String, dynamic>)
      ],
    );

ComplaintDraft draftFromJson(Map<String, dynamic> j) => ComplaintDraft(
      toEmail: j['to_email'] as String?,
      toLabel: j['to_label'] as String? ?? '',
      subject: j['subject'] as String? ?? '',
      body: j['body'] as String? ?? '',
      cc: [for (final c in (j['cc'] as List? ?? [])) c as String],
      bcc: [for (final c in (j['bcc'] as List? ?? [])) c as String],
      aiWritten: j['ai_written'] as bool? ?? false,
    );
