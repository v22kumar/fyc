import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/tokens.dart';
import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// Explain the location request before Android makes it.
///
/// Android owns the permission, so the member is going to be asked whatever we
/// do. The only thing we control is whether the system dialog arrives cold. A
/// cold dialog is the one that gets denied — and denial on Android is sticky,
/// so it costs that member's location more or less permanently.
///
/// This is also what Play's prominent-disclosure rule asks for, and what the
/// DPDP Act means by consent that is specific and informed: at the moment of
/// asking, the member knows what is collected and why. A clause in a policy
/// document elsewhere satisfies neither.
///
/// Crucially, **"Not now" never reaches the operating system.** Declining here
/// is recoverable — we can ask again another day. Declining to Android is not.
/// That asymmetry is the whole reason this screen exists rather than calling
/// `requestPermission` directly.
class LocationDisclosure {
  LocationDisclosure._();

  static const _kAsked = 'location_disclosure_answered';

  /// Whether we may use location, asking the member first if we never have.
  ///
  /// Returns false without touching the system prompt when they decline, or
  /// when they declined before — this is not a dialog to show on every visit.
  static Future<bool> ensure(BuildContext context) async {
    // Already granted by some earlier flow: nothing to explain.
    final existing = await Geolocator.checkPermission();
    if (existing == LocationPermission.always ||
        existing == LocationPermission.whileInUse) {
      return true;
    }
    // Android will not re-prompt after a permanent denial, so showing our
    // explanation would raise a hope the system cannot honour.
    if (existing == LocationPermission.deniedForever) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kAsked) == true) return false;

    if (!context.mounted) return false;
    final agreed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _DisclosureSheet(),
        ) ??
        false;

    if (!agreed) {
      // "Not now" is remembered, so this is asked once rather than every time
      // the blood screen opens. Nagging is how a soft no becomes a hard one.
      await prefs.setBool(_kAsked, true);
      return false;
    }

    final granted = await Geolocator.requestPermission();
    if (granted == LocationPermission.always ||
        granted == LocationPermission.whileInUse) {
      await prefs.setBool(_kAsked, true);
      return true;
    }
    // They agreed with us and then the system dialog was dismissed or missed.
    // That is not a decision to hold them to, so leave the flag unset and let
    // the next visit try again — Android allows one more prompt before it stops
    // asking for good, and we would rather spend it than lose the member.
    if (granted == LocationPermission.deniedForever) {
      await prefs.setBool(_kAsked, true);
    }
    return false;
  }
}

class _DisclosureSheet extends StatelessWidget {
  const _DisclosureSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(DSSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined, size: 32, color: AppColors.primary),
            SizedBox(height: DSSpacing.sm),
            Text(
              trId('location_ask_title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: DSSpacing.sm),
            // Says what is collected and why, in that order. Both halves matter:
            // "roughly" and "when you open it" are the limits, and they are the
            // reason this is reasonable to agree to.
            Text(
              trId('location_ask_body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: DSSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: AppColors.success),
                SizedBox(width: DSSpacing.xs),
                Expanded(
                  child: Text(
                    trId('location_ask_no_tracking'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.success),
                  ),
                ),
              ],
            ),
            SizedBox(height: DSSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(trId('location_ask_yes')),
              ),
            ),
            // Declining is a real option, placed where a real option goes —
            // not greyed out, not hidden below the fold.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(trId('location_ask_no')),
              ),
            ),
            SizedBox(height: DSSpacing.xs),
            Text(
              trId('location_ask_change'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
