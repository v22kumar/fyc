import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/complaint_entities.dart';

/// Ask a member for a contact the club does not have.
///
/// These blanks are the local desks — ward councillor, panchayat president,
/// section office — and they are blank precisely because no district web page
/// lists them. The person standing outside that office is the best source
/// there is.
///
/// It is explicit that this waits for the club. A member who thinks they have
/// just fixed the directory, and then sees the same "no contact" a week later,
/// will not offer a second time.
class SuggestContactSheet extends StatefulWidget {
  const SuggestContactSheet({
    super.key,
    required this.rung,
    required this.onSubmit,
  });

  final LadderRung rung;
  final void Function(String? phone, String? email, String? howTheyKnow) onSubmit;

  @override
  State<SuggestContactSheet> createState() => _SuggestContactSheetState();
}

class _SuggestContactSheetState extends State<SuggestContactSheet> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _how = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _how.dispose();
    super.dispose();
  }

  bool get _hasSomething =>
      _phone.text.trim().isNotEmpty || _email.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: DSSpacing.md,
        right: DSSpacing.md,
        top: DSSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + DSSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.rung.title,
              style: Theme.of(context).textTheme.titleMedium),
          Text(widget.rung.covers,
              style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: DSSpacing.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: trId('phone_number'),
              prefixIcon: const Icon(Icons.call_outlined),
            ),
          ),
          SizedBox(height: DSSpacing.sm),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: trId('email_optional'),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          SizedBox(height: DSSpacing.sm),
          TextField(
            controller: _how,
            maxLines: 2,
            decoration: InputDecoration(
              // Not a URL. The people who have a ward councillor's number read
              // it off a board outside his office, and demanding a link would
              // exclude exactly the contributions worth having.
              labelText: trId('how_do_you_know'),
              hintText: trId('how_do_you_know_hint'),
            ),
          ),
          SizedBox(height: DSSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined,
                  size: 16, color: context.cTextSecondary),
              SizedBox(width: DSSpacing.xs),
              Expanded(
                // Said plainly, because a member who believes they have just
                // fixed the directory and finds it unchanged next week will
                // not offer a second time.
                child: Text(trId('checked_before_used'),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
          SizedBox(height: DSSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _hasSomething
                  ? () {
                      widget.onSubmit(_phone.text.trim(), _email.text.trim(),
                          _how.text.trim());
                      Navigator.of(context).pop();
                    }
                  : null,
              child: Text(trId('send_to_fyc')),
            ),
          ),
        ],
      ),
    );
  }
}
