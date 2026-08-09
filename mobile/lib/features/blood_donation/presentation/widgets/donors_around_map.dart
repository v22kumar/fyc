import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/blood_donor_entity.dart';
import 'donor_presence.dart';

/// The people around you, on the screen where you are asking for blood.
///
/// The map used to be its own route behind an icon in the app bar, which meant
/// nobody was ever going to see it. That was the wrong shape for what it is:
/// this is not a feature to navigate to, it is the answer to the first question
/// someone in trouble asks — *is there anybody near me?*
///
/// So it sits at the top of the page and it leads with a count. A number over a
/// map of dots does something a list cannot: it says **you are not alone here**
/// before the member has read a single name. That is the whole point of putting
/// it here, and it is why the count is the largest thing on the panel.
///
/// It is deliberately honest about which dots are which — see [DonorPresence].
/// A screen full of green would be a better feeling and a worse promise.
class DonorsAroundMap extends StatefulWidget {
  const DonorsAroundMap({
    super.key,
    required this.donors,
    required this.me,
    required this.onTapCluster,
    this.height = 240,
  });

  /// Club donors. Imported directory contacts have no location and never
  /// appear here — they are a phone number, not a neighbour.
  final List<BloodDonorEntity> donors;
  final LatLng? me;
  /// Called with everyone standing on one pin. The server publishes positions
  /// rounded to about a kilometre, so two neighbours are frequently the *same*
  /// point — a pin per donor drew four people as one dot and made the count
  /// above it look like a lie.
  final ValueChanged<List<BloodDonorEntity>> onTapCluster;
  final double height;

  @override
  State<DonorsAroundMap> createState() => _DonorsAroundMapState();
}

class _DonorsAroundMapState extends State<DonorsAroundMap> {
  final MapController _map = MapController();

  /// Nagercoil town, used only until we know better. Showing the middle of the
  /// ocean while a location resolves looks like a broken app.
  static const _fallbackCentre = LatLng(8.1780, 77.4340);

  List<BloodDonorEntity> get _placed => widget.donors
      .where((d) => d.approxLat != null && d.approxLng != null)
      .toList();

  LatLng get _centre =>
      widget.me ??
      (_placed.isEmpty
          ? _fallbackCentre
          : LatLng(_placed.first.approxLat!, _placed.first.approxLng!));

  @override
  void didUpdateWidget(DonorsAroundMap old) {
    super.didUpdateWidget(old);
    // Both arrive after the first build — the screen renders before the phone
    // answers and before the ranked list comes back.
    if (widget.me != old.me || widget.donors.length != old.donors.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _frame());
    }
  }

  /// Put everyone the panel is counting inside the panel.
  ///
  /// A fixed zoom around the member looks right in a town and wrong everywhere
  /// else: at 12.5 the visible strip is about four kilometres, so a donor six
  /// kilometres away was counted in the heading and drawn off the edge. The
  /// heading and the dots have to agree or the count stops being believable.
  ///
  /// Capped at a neighbourhood zoom so a single nearby donor does not slam the
  /// camera down to street level, and floored so one distant outlier does not
  /// zoom the whole district into uselessness.
  void _frame() {
    if (!mounted) return;
    final points = [
      if (widget.me != null) widget.me!,
      for (final d in _placed) LatLng(d.approxLat!, d.approxLng!),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 13);
      return;
    }
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          // Room for the count, which floats over the top of the panel.
          padding: const EdgeInsets.fromLTRB(48, 96, 48, 40),
          maxZoom: 14,
          minZoom: 9,
        ),
      );
    } catch (_) {
      // Degenerate bounds (everyone on one point) — the move above covers the
      // case that matters and a failed fit must not take the panel down.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Counted over the mapped donors, not all of them — the panel is about
    // what is on it. Two numbers drawn from different populations is how a
    // count ends up disagreeing with the dots underneath it.
    final ready = _placed.where((d) => d.isAvailable && d.isEligible);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _centre,
                initialZoom: 12.5,
                // Rotation on a panel this size is an accident waiting to
                // happen, not a feature anyone asked for.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.friendsyouthclub.fyc_connect',
                  // No tiles is a normal state here — a rural signal, an
                  // offline phone. The dots and the count still work, so the
                  // panel degrades to a plain field rather than to an error.
                  errorTileCallback: (_, __, ___) {},
                ),
                MarkerLayer(markers: _markers()),
              ],
            ),
          ),
          // A soft top edge so the count sits on something, whatever the map
          // happens to be showing underneath it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.cBackground.withValues(alpha: 0.92),
                      context.cBackground.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: DSSpacing.sm,
            left: DSSpacing.md,
            right: DSSpacing.md,
            child: IgnorePointer(
              child: _AroundYou(
                total: _placed.length,
                readyNow: ready.length,
                // Before we know where the member is there is nothing to be
                // near, so "nobody is around you" would be a claim we have not
                // earned — and a discouraging one to flash at someone who came
                // here in an emergency.
                located: widget.me != null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Everyone who resolves to the same published point, gathered.
  ///
  /// The grid is the server's own rounding — about a kilometre — rather than a
  /// number picked here. Clustering finer than the data would invent precision
  /// the server deliberately withheld.
  List<List<BloodDonorEntity>> _clusters() {
    final cells = <String, List<BloodDonorEntity>>{};
    for (final d in _placed) {
      final key = '${d.approxLat!.toStringAsFixed(2)},'
          '${d.approxLng!.toStringAsFixed(2)}';
      (cells[key] ??= []).add(d);
    }
    return cells.values.toList();
  }

  List<Marker> _markers() {
    return [
      for (final cell in _clusters())
        Marker(
          point: LatLng(cell.first.approxLat!, cell.first.approxLng!),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => widget.onTapCluster(cell),
            child: _DonorPin(donors: cell),
          ),
        ),
      if (widget.me != null)
        Marker(
          point: widget.me!,
          width: 20,
          height: 20,
          child: const _MePin(),
        ),
    ];
  }
}

/// The count, and what it is a count of.
///
/// Two numbers, in the order they matter: how many people are around you at
/// all, then how many of those could give today. The second is the smaller and
/// harder number, and hiding it would make the panel a nicer lie.
class _AroundYou extends StatelessWidget {
  const _AroundYou({
    required this.total,
    required this.readyNow,
    required this.located,
  });

  final int total;
  final int readyNow;
  final bool located;

  @override
  Widget build(BuildContext context) {
    if (!located) return const SizedBox.shrink();
    if (total == 0) {
      return Text(
        trId('nobody_mapped_yet'),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: context.cTextSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trId('donors_around_you', {'n': total}),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.cText,
                fontWeight: FontWeight.w800,
              ),
        ),
        Row(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 14, color: AppColors.success),
            SizedBox(width: DSSpacing.xs),
            Text(
              trId('n_can_give_today', {'n': readyNow}),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.success),
            ),
          ],
        ),
      ],
    );
  }
}

/// A pin: one donor's blood group, or how many are standing here.
///
/// The group is on the pin because it is what someone is scanning for, and a
/// map of identical dots would make them tap every one to find out. Where
/// several share a point the count replaces the group — "3" is the useful fact,
/// and the sheet behind the tap has the groups.
///
/// The colour is the freshest presence in the cell, because that is what makes
/// a pin worth walking to. See [DonorPresence].
class _DonorPin extends StatelessWidget {
  const _DonorPin({required this.donors});

  final List<BloodDonorEntity> donors;

  DonorPresence get _best {
    var best = DonorPresence.unknown;
    for (final d in donors) {
      final p = DonorPresence.of(d.locationBasis);
      if (p.index < best.index) best = p;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final presence = _best;
    final label =
        donors.length == 1 ? donors.single.bloodGroup : '${donors.length}';
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: presence.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: presence.color.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// You.
///
/// Deliberately neither green nor blue: both of those already mean something
/// here, and a member who reads their own dot as "a donor seen recently" is
/// counting themselves. White with a dark ring belongs to no category, which is
/// exactly right — this pin is the frame of reference, not one of the results.
class _MePin extends StatelessWidget {
  const _MePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textPrimary, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
