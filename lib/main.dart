import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/force_update_service.dart';
import 'features/settings/presentation/force_update_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/subscription_service.dart';
import 'core/services/fcm_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return Future.value(true);
  });
}

Future<void> _initializePostStartupServices(ProviderContainer container) async {
  // These services must never block the first Flutter frame.
  // Each service is isolated so one failure cannot prevent the others.
  try {
    await FCMService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize FCM after startup: $e');
  }

  try {
    await container.read(subscriptionServiceProvider).initPlatformState();
  } catch (e) {
    debugPrint('Failed to initialize RevenueCat after startup: $e');
  }

  try {
    await FirebaseAnalytics.instance.logAppOpen();
  } catch (e) {
    debugPrint('Analytics failed after startup: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    // Safety check ensuring we only use the emulator for tests
    String emulatorHost = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  }

  // Enable Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Keep screen awake
  WakelockPlus.enable();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Workmanager registration is not required to render the first frame.
  // Defer it until after startup so it cannot delay the launch screen.
  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Workmanager().initialize(callbackDispatcher).catchError((e) {
        debugPrint('Failed to initialize Workmanager after startup: $e');
      });
    });
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TajerApp(),
    ),
  );

  // RevenueCat, FCM and Analytics are intentionally initialized only after
  // the first Flutter frame. This keeps startup independent of network,
  // Play Services and store-service latency while preserving their existing
  // initialization and subscription logic.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializePostStartupServices(container);
  });
}

class TajerApp extends ConsumerWidget {
  const TajerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final isForceUpdate = ref.watch(forceUpdateProvider).value ?? false;

    if (isForceUpdate) {
      return MaterialApp(
        title: 'Tajer',
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const ForceUpdateScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Tajer',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ar'),
        Locale('en'),
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
    );
  }
}
