import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';

/// The one list of things a person can report, shared by every screen.
///
/// It lived inside the report screen, which meant the reviewer's queue had
/// nothing to translate an API code with and rendered `DRINKING_WATER` — a raw
/// enum member, in English, inside a Tamil interface. The hardcoded-literal
/// scan cannot catch that: the string arrives from the server, so no Dart
/// source ever contains it.
///
/// `code` matches the backend's `CivicCategory`, which is what the routing
/// ladder is keyed on. Anything the server sends that is not in this list falls
/// back to the code itself rather than to a blank chip — an unfamiliar label is
/// a translation to add, an empty one is a bug nobody notices.
class CivicCategory {
  final String code;
  final String labelId;
  final IconData icon;
  const CivicCategory(this.code, this.labelId, this.icon);

  static const all = <CivicCategory>[
    CivicCategory('ROAD', 'cat_road', Icons.dangerous_outlined),
    CivicCategory('STREET_LIGHT', 'cat_street_light', Icons.lightbulb_outline),
    CivicCategory('DRINKING_WATER', 'cat_drinking_water', Icons.water_drop_outlined),
    CivicCategory('DRAINAGE', 'cat_drainage', Icons.water_damage_outlined),
    CivicCategory('GARBAGE', 'cat_garbage', Icons.delete_outline),
    CivicCategory('ELECTRICITY', 'cat_electricity', Icons.bolt_outlined),
    CivicCategory('PUBLIC_HEALTH', 'cat_public_health', Icons.pest_control_outlined),
    CivicCategory('ENCROACHMENT', 'cat_encroachment', Icons.fence_outlined),
    CivicCategory('SCHOOL', 'cat_school', Icons.school_outlined),
    CivicCategory('HEALTHCARE', 'cat_healthcare', Icons.local_hospital_outlined),
    CivicCategory('POLLUTION', 'cat_pollution', Icons.factory_outlined),
    CivicCategory('TRANSPORT', 'cat_transport', Icons.directions_bus_outlined),
    CivicCategory('SAFETY', 'cat_safety', Icons.local_police_outlined),
    CivicCategory('OTHER', 'cat_other', Icons.more_horiz),
  ];

  /// Category names this app wrote before the redesign, so complaints filed
  /// under them still read correctly in a queue rather than showing a code.
  static const _legacy = <String, String>{
    'ROAD_TRAFFIC': 'ROAD',
    'POWER_CUT': 'ELECTRICITY',
    'WATER': 'DRINKING_WATER',
    'SANITATION': 'GARBAGE',
  };

  static CivicCategory? find(String? code) {
    if (code == null || code.isEmpty) return null;
    final key = _legacy[code] ?? code;
    for (final c in all) {
      if (c.code == key) return c;
    }
    return null;
  }

  /// What a person should see for a category code, in their own language.
  static String label(String? code) {
    final found = find(code);
    return found == null ? (code ?? '') : trId(found.labelId);
  }

  static IconData iconFor(String? code) =>
      find(code)?.icon ?? Icons.report_gmailerrorred_outlined;
}
