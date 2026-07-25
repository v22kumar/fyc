import '../storage/local_storage.dart';
import '../../service_locator.dart';
import 'registry/registry.dart';

/// Resolve a registered UI string by its stable [id], in the app's current
/// language.
///
/// This is the primary way to render static UI text: the strings themselves
/// live in the central registry (`registry/en.dart`, `ta.dart`, …), so adding a
/// new language is one file — no call-site edits. Resolution order:
/// current language → English → the id itself (so a missing translation is
/// never a blank label).
///
/// [args] fills `{placeholder}` tokens, e.g.
/// `trId('need_runs', {'n': 5})` against `'Need {n} runs'`.
String trId(String id, [Map<String, Object?>? args]) {
  final lang = sl<LocalStorage>().getLang();
  var s = kStrings[lang]?[id] ?? kStrings['en']?[id] ?? id;
  if (args != null && args.isNotEmpty) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  }
  return s;
}

/// Inline language picker for **runtime bilingual data** and the handful of
/// interpolated strings that don't fit the id registry — e.g. AI content
/// returned by the API (`tr(en: data.en, ta: data.ta)`) or
/// `tr(en: 'Need $n runs', ta: '$n ரன் தேவை')`.
///
/// For static UI labels use [trId] instead so the text is centralized. Reads
/// the current language from storage on every call, so it updates live when the
/// user switches language (MaterialApp rebuilds via localeNotifier). `en` and
/// `ta` are required; `hi`/`ml` fall back to English when omitted.
String tr({required String en, required String ta, String? hi, String? ml}) {
  switch (sl<LocalStorage>().getLang()) {
    case 'ta':
      return ta;
    case 'hi':
      return hi ?? en;
    case 'ml':
      return ml ?? en;
    default:
      return en;
  }
}
