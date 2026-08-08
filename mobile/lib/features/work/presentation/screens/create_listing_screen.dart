import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/work_entities.dart';
import '../../domain/repositories/work_repository.dart';

/// List what you do — done once, so short enough to finish standing up.
///
/// Name, category, your own words, area, phone. Nothing else is required, and
/// the shop fields appear only for somebody who says they are a shop.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key, required this.repo});

  final WorkRepository repo;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _name = TextEditingController();
  final _about = TextEditingController();
  final _area = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _hours = TextEditingController();

  static const _categories = [
    'TUITION', 'CARPENTRY', 'MASONRY', 'PAINTING', 'ELECTRICAL', 'PLUMBING',
    'WELDING', 'BIKE_REPAIR', 'CAR_REPAIR', 'MOBILE_REPAIR', 'COMPUTER',
    'SOFTWARE', 'PHOTOGRAPHY', 'VIDEOGRAPHY', 'TAILORING', 'CATERING',
    'DRIVER', 'DAILY_LABOUR', 'CLEANING', 'BEAUTY', 'EVENTS', 'REPAIRS_GENERAL',
  ];

  String? _category;
  bool _isShop = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _about, _area, _phone, _address, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  /// What is still missing, said before they reach for the button rather than
  /// after — the same lesson the Complaint Box capture screen taught.
  String? get _missing {
    if (_name.text.trim().length < 2) return trId('what_you_do');
    if (_category == null) return trId('what_you_do');
    if (_phone.text.trim().length < 6) return trId('phone');
    return null;
  }

  Future<void> _save() async {
    final missing = _missing;
    if (missing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missing), backgroundColor: AppColors.accent),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.create(
        displayName: _name.text.trim(),
        category: _category!,
        phone: _phone.text.trim(),
        kind: _isShop ? ListingKind.business : ListingKind.person,
        about: _about.text.trim(),
        area: _area.text.trim(),
        address: _isShop ? _address.text.trim() : null,
        hours: _isShop ? _hours.text.trim() : null,
      );
      // The haptic is fired without awaiting, so nothing touches `context`
      // after an async gap — the analyzer was right that the widget can be
      // gone by then, and a disposed-context lookup here would crash on the
      // one screen somebody only ever uses once.
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      // Say what happens next. The alternative is silence, and somebody who
      // hears silence concludes it did not work.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trId('your_listing_is_live'))),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trId('action_failed_try_again')),
            backgroundColor: AppColors.accent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSScreenHeader(
        title: trId('list_what_you_do'),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: EdgeInsets.all(DSSpacing.md),
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: trId('what_you_do')),
          ),
          SizedBox(height: DSSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            items: [
              for (final c in _categories)
                DropdownMenuItem(
                    value: c,
                    child: Text(trId('work_cat_${c.toLowerCase()}'))),
            ],
            onChanged: (v) => setState(() => _category = v),
            decoration: InputDecoration(labelText: trId('work')),
          ),
          SizedBox(height: DSSpacing.sm),
          TextField(
            controller: _about,
            maxLines: 3,
            // Where "I do interlock brick work" lives, and it is searched.
            decoration: InputDecoration(labelText: trId('in_your_words')),
          ),
          SizedBox(height: DSSpacing.sm),
          TextField(
            controller: _area,
            decoration: InputDecoration(labelText: trId('your_area')),
          ),
          SizedBox(height: DSSpacing.sm),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: trId('phone')),
          ),
          SizedBox(height: DSSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isShop,
            onChanged: (v) => setState(() => _isShop = v),
            title: Text(trId('i_am_a_shop')),
          ),
          // Only a shop has these, which is the only real difference between a
          // person and a business here.
          if (_isShop) ...[
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: trId('shop_address')),
            ),
            SizedBox(height: DSSpacing.sm),
            TextField(
              controller: _hours,
              decoration: InputDecoration(labelText: trId('opening_hours')),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_missing != null && !_saving) ...[
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: context.cTextSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_missing!,
                        style: TextStyle(
                            fontSize: 13, color: context.cTextSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                // Live even when incomplete, and it answers when tapped.
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(trId('publish_listing'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
