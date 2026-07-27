import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();
    // Start anonymous login immediately when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).signInAnonymously();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: authState.when(
          data: (_) => const CircularProgressIndicator(),
          loading: () => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.text_27,
                style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
              ),
            ],
          ),
          error: (error, stack) => Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'حدث خطأ في الاتصال: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).signInAnonymously();
                  },
                  child: Text(AppLocalizations.of(context)!.text_28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
