import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';
import 'screens/auth/splash_screen.dart';
import 'services/app_navigation.dart';
import 'services/app_theme_notifier.dart';
import 'services/attendance_notification_service.dart';
import 'providers/app_state_notifier.dart';
import 'providers/reference_data_store.dart';
import 'widgets/session_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  // Crashlytics has no Flutter Web implementation — routing errors to it
  // there throws its own assertion and masks the real error.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  if (!AppConstants.disableAppCheck) {
    final shouldActivate =
        !kIsWeb || AppConstants.appCheckRecaptchaSiteKey.isNotEmpty;
    if (shouldActivate) {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        webProvider: AppConstants.appCheckRecaptchaSiteKey.isEmpty
            ? null
            : ReCaptchaV3Provider(AppConstants.appCheckRecaptchaSiteKey),
      );
    }
  }
  await AttendanceNotificationService.instance.initialize();
  await AppThemeNotifier.instance.loadSaved();
  runApp(const CodesapiensApp());
}

class CodesapiensApp extends StatelessWidget {
  const CodesapiensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppStateNotifier.instance),
        ChangeNotifierProvider.value(value: ReferenceDataStore.instance),
      ],
      child: ListenableBuilder(
        listenable: AppThemeNotifier.instance,
        builder: (context, _) => MaterialApp(
          navigatorKey: appNavigatorKey,
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: const SplashScreen(),
          // Wraps the Navigator itself so it stays mounted across every
          // screen — the single place session-invalidation redirects fire
          // from, regardless of what's currently on top.
          builder: (context, child) => SessionGuard(child: child!),
        ),
      ),
    );
  }
}
