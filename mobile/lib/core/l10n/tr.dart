import '../storage/local_storage.dart';
import '../../service_locator.dart';

/// Inline 4-language string picker for UI labels.
///
/// Reads the current language from storage on every call, so it updates live
/// when the user switches language (MaterialApp rebuilds via localeNotifier).
/// `en` and `ta` are required; `hi`/`ml` fall back to English when omitted.
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
