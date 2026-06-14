import 'package:flutter/material.dart';
import 'strings_en.dart';
import 'strings_ta.dart';

abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('ta'),
    Locale('en'),
  ];

  // ── Generic ──────────────────────────────────────────────
  String get appName;
  String get loading;
  String get retry;
  String get cancel;
  String get submit;
  String get error;
  String get success;
  String get close;
  String get next;
  String get back;
  String get save;

  // ── Language select ───────────────────────────────────────
  String get selectLanguage;
  String get selectLanguageSubtitle;
  String get tamil;
  String get english;
  String get continueBtn;

  // ── Auth ──────────────────────────────────────────────────
  String get enterPhoneNumber;
  String get phoneHint;
  String get sendOtp;
  String get enterOtp;
  String get otpSentTo;
  String get verifyOtp;
  String get invalidOtp;
  String get resendOtp;
  String get noAccount;
  String get register;
  String get nameInTamil;
  String get nameInEnglish;
  String get selectRole;
  String get citizen;
  String get volunteer;
  String get alreadyHaveAccount;
  String get loginSuccess;
  String get logout;
  String get orgNotFound;

  // ── Home ──────────────────────────────────────────────────
  String get homeGreeting;
  String get homeSubtitle;
  String get bloodDonation;
  String get publicIssues;
  String get membership;
  String get directory;
  String get opportunityHub;
  String get events;
  String get gallery;
  String get statsTreesPlanted;
  String get statsDonors;
  String get statsEvents;
  String get statsImpacted;
  String get viewAll;

  // ── Blood Donation ────────────────────────────────────────
  String get bloodDonationHub;
  String get bloodDonationSubtitle;
  String get donorRegistration;
  String get bloodRequest;
  String get searchDonors;
  String get filterByBloodGroup;
  String get allBloodGroups;
  String get donorAvailable;
  String get donorUnavailable;
  String get requestContact;
  String get callDonor;
  String get whatsappDonor;
  String get noDonorsFound;
  String get registerAsDonor;
  String get selectBloodGroup;
  String get lastDonationDate;
  String get availability;
  String get available;
  String get unavailable;
  String get donorRegisteredSuccess;
  String get bloodGroupRequired;
  String get contactPrivacyNote;
  String get updateAvailability;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ta', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return locale.languageCode == 'ta'
        ? StringsTa()
        : StringsEn();
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
