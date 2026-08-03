import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/blood_request_api.dart';
import '../../data/models/blood_donor_model.dart';

const _groups = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
// Nagercoil town — the fallback centre if we can't get a live location.
const _fallbackCenter = LatLng(8.1780, 77.4340);
// Clustering grid: ~0.02° ≈ 2.2 km cells (donor coords already come ~1 km-coarse).
const _cell = 0.02;

/// Clustered map of nearby, opted-in FYC donors (approximate ~1 km locations).
class DonorMapScreen extends StatefulWidget {
  const DonorMapScreen({super.key});
  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  final MapController _map = MapController();
  LatLng _center = _fallbackCenter;
  LatLng? _me;
  String _group = 'All';
  List<BloodDonorModel> _donors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pos = await _currentLocation();
    if (pos != null) {
      _me = LatLng(pos.latitude, pos.longitude);
      _center = _me!;
    }
    await _fetch();
  }

  Future<Position?> _currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await BloodRequestApi.nearby(
        lat: _center.latitude,
        lng: _center.longitude,
        bloodGroup: _group == 'All' ? null : _group,
        radiusKm: 25,
      );
      if (mounted) setState(() { _donors = list.where((d) => d.approxLat != null && d.approxLng != null).toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _donors = []; _loading = false; });
    }
  }

  // Group donors into grid cells → one marker per cell.
  List<_Cluster> _clusters() {
    final map = <String, _Cluster>{};
    for (final d in _donors) {
      final gx = (d.approxLat! / _cell).round();
      final gy = (d.approxLng! / _cell).round();
      final key = '${gx}_$gy';
      (map[key] ??= _Cluster(LatLng(gx * _cell, gy * _cell))).donors.add(d);
    }
    return map.values.toList();
  }

  void _openCluster(_Cluster c) {
    final lang = sl<LocalStorage>().getLang();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(16),
          children: [
            Text('${c.donors.length} ${trId('donors_here')}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.cText)),
            SizedBox(height: 8),
            for (final d in c.donors)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withOpacity(0.12),
                  child: Text(d.bloodGroup, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                title: Text(d.displayName(lang), style: TextStyle(color: context.cText, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    if (d.distanceKm != null) '${d.distanceKm!.toStringAsFixed(1)} ${trId('km_away')}',
                    d.isEligible ? trId('eligible_now') : trId('eligible_soon'),
                  ].join(' · '),
                  style: TextStyle(color: context.cTextSecondary, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clusters = _clusters();
    final markers = <Marker>[
      for (final c in clusters)
        Marker(
          point: c.center,
          width: 46,
          height: 46,
          child: GestureDetector(
            onTap: () => _openCluster(c),
            child: _ClusterPin(count: c.donors.length),
          ),
        ),
      if (_me != null)
        Marker(
          point: _me!,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 8)],
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(trId('donors_near_you')),
        actions: [
          IconButton(
            tooltip: trId('recenter'),
            icon: Icon(Icons.my_location_rounded),
            onPressed: () {
              if (_me != null) _map.move(_me!, 13);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Blood-group filter
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final g in _groups)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: _group == g,
                      selectedColor: AppColors.accent,
                      labelStyle: TextStyle(
                          color: _group == g ? AppColors.background : context.cText,
                          fontWeight: FontWeight.w700, fontSize: 12),
                      onSelected: (_) { setState(() => _group = g); _fetch(); },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 12,
                    minZoom: 4,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.friendsyouthclub.fyc_connect',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                if (_loading)
                  Positioned(
                    top: 12, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.cSurface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text(trId('loading'), style: TextStyle(color: context.cText, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),
                if (!_loading && _donors.isEmpty)
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.cBorder),
                      ),
                      child: Text(trId('no_donors_shared_location_nearby'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.cTextSecondary, fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
          // OSM attribution (required by the tile usage policy).
          Container(
            width: double.infinity,
            color: context.cBackground,
            padding: EdgeInsets.symmetric(vertical: 3),
            child: Text('© OpenStreetMap',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: context.cTextSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Cluster {
  final LatLng center;
  final List<BloodDonorModel> donors = [];
  _Cluster(this.center);
}

class _ClusterPin extends StatelessWidget {
  final int count;
  const _ClusterPin({required this.count});
  @override
  Widget build(BuildContext context) {
    final single = count == 1;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 8)],
      ),
      child: single
          ? Icon(Icons.bloodtype_rounded, color: Colors.white, size: 22)
          : Text('$count',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
    );
  }
}
