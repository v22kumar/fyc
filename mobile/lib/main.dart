import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/storage/local_storage.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'service_locator.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('ta'));

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage _) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  await initServiceLocator();
  localeNotifier.value = Locale(sl<LocalStorage>().getLang());
  runApp(const FycApp());
}

class FycApp extends StatelessWidget {
  const FycApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthBloc>(),
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (context, locale, child) {
          return MaterialApp.router(
            title: 'FYC',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: appRouter,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => Column(
              children: [
                const OfflineBanner(),
                Expanded(child: child ?? const SizedBox()),
              ],
            ),
          );
        },
      ),
    );
  }
}
