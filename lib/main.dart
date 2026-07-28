import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:freerasp/freerasp.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'core/services/backup_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null && !auth.currentUser!.isAnonymous) {
        final backupService = BackupService(FirebaseFirestore.instance, FirebaseStorage.instance);
        await backupService.exportToCloud(auth.currentUser!.uid);
      }
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void _initFreeRasp() {
  if (kIsWeb) return;
  
  // NOTE: You must update these with your actual package name and SHA-256 hash
  final config = TalsecConfig(
    androidConfig: AndroidConfig(
      packageName: 'com.example.tajer', // TODO: Change this to your actual package name
      signingCertHashes: ['YOUR_SHA256_BASE64_HASH'], // TODO: Add your Base64 SHA-256 hash here
    ),
    iosConfig: IOSConfig(
      bundleIds: ['com.example.tajer'], // TODO: Change this
      teamId: 'YOUR_TEAM_ID', // TODO: Change this
    ),
    watcherMail: 'support@alldown.uk',
    isProd: true, // Set to false during development if testing on emulators
  );

  final callback = ThreatCallback(
    onAppIntegrity: () => _handleThreat('App Integrity'),
    onObfuscationIssues: () => _handleThreat('Obfuscation'),
    onDebug: () => _handleThreat('Debugging'),
    onDeviceBinding: () => _handleThreat('Device Binding'),
    onDeviceID: () => _handleThreat('Device ID'),
    onHooks: () => _handleThreat('Hooks (Frida/Xposed)'),
    onPrivilegedAccess: () => _handleThreat('Privileged Access (Root/Jailbreak)'),
    onSecureHardwareNotAvailable: () => _handleThreat('Secure Hardware'),
    onSimulator: () => _handleThreat('Simulator/Emulator'),
    onUnofficialStore: () => _handleThreat('Unofficial Store'),
  );

  Talsec.instance.attachListener(callback);
  try {
    Talsec.instance.start(config);
  } catch (e) {
    debugPrint('Talsec start error: $e');
  }
}

void _handleThreat(String threat) {
  debugPrint('CRITICAL SECURITY THREAT DETECTED: $threat');
  if (kReleaseMode) {
    // exit(0); // Temporarily disabled for user testing
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Workmanager for auto backup (Android/iOS only)
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    // Register auto backup task every 12 hours
    Workmanager().registerPeriodicTask(
      "tajer-auto-backup",
      "backupTask",
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  // Initialize Firebase App Check (Temporarily disabled to fix black screen)
  // FirebaseAppCheck.instance.activate(
  //   androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  //   appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  // ).catchError((e) {
  //   debugPrint('Failed to initialize AppCheck: $e');
  // });

  // Initialize RASP (Anti-Tampering) (Temporarily disabled to fix black screen)
  // _initFreeRasp();

  // Initialize Hive
  await Hive.initFlutter();

  runApp(
    const ProviderScope(
      child: TajerApp(),
    ),
  );
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
