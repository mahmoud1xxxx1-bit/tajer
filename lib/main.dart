import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/subscription_service.dart';
import 'core/services/fcm_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Analytics must never delay the first frame.
  unawaited(FirebaseAnalytics.instance.logAppOpen());

  const bool useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    // Safety check ensuring we only use the emulator for tests
    String emulatorHost =
        !kIsWeb && Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  }

  // Enable Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize Workmanager
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  // Initialize Hive
  await Hive.initFlutter();

  // Keep screen awake
  WakelockPlus.enable();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize RevenueCat Subscription Service
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  try {
    await container.read(subscriptionServiceProvider).initPlatformState();
  } catch (e) {
    debugPrint('Failed to initialize RevenueCat: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TajerApp(),
    ),
  );

  // FCM is intentionally initialized only after the first app frame.
  // Slow Play Services/network calls must never block Tajer startup.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      FCMService.initialize(
        onForegroundMessage: (message) {
          final title = message.notification?.title?.trim();
          final body = message.notification?.body?.trim();
          final text = [title, body]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join('\n');

          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(text.isEmpty ? 'إشعار جديد' : text),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onNotificationTap: (message) {
          final route = message.data['route']?.toString();
          if (route != null && route.startsWith('/')) {
            container.read(goRouterProvider).go(route);
          }
        },
      ),
    );
  });
}

class TajerApp extends ConsumerWidget {
  const TajerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Tajer',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      locale: locale,
      localizationsDelegates: [
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
      routerConfig: goRouter,
    );
  }
}
