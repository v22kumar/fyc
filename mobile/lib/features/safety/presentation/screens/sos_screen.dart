import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/sos_bloc.dart';
import 'sos_live_screen.dart';
import 'sos_trigger_screen.dart';

/// One route, one bloc: the button before, and the incident after.
///
/// The live screen used to be reached with `Navigator.pushReplacement` from
/// the trigger screen. Two things went wrong at once, and both of them are
/// invisible in a debug build until you look:
///
/// * The new route was pushed onto the **root** navigator, so it landed as a
///   *sibling* of the `/sos` route rather than a child of the `BlocProvider`
///   that route creates. `SosLiveScreen`'s `BlocBuilder` threw
///   `ProviderNotFoundException` — which in a release build is not a red error
///   screen, it is a grey rectangle.
/// * `pushReplacement` also disposed the route being replaced, closing the
///   bloc that owned the incident.
///
/// The member had by then genuinely raised an SOS — the server had it, members
/// had been pushed — and was left staring at grey with no way to say they were
/// safe, no list of who was coming, and no Call 112 button. A blank screen is
/// bad anywhere; here it is the failure the whole feature exists to prevent.
///
/// So there is no navigation. The route holds the bloc, and which screen shows
/// is a function of whether an incident exists.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key, this.rehearsal = false});

  /// A dry run from the setup screen — the trigger behaves identically and
  /// nothing is ever raised, so this never reaches the live screen.
  final bool rehearsal;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SosBloc, SosViewState>(
      // Only the arrival and departure of an incident swaps the screen.
      // Everything else — readiness, busy, failures — is the current screen's
      // business, and rebuilding the whole route for it would restart the
      // countdown under the member's thumb.
      buildWhen: (a, b) => (a.incident == null) != (b.incident == null),
      builder: (context, state) => state.incident == null
          ? SosTriggerScreen(rehearsal: rehearsal)
          : const SosLiveScreen(),
    );
  }
}
