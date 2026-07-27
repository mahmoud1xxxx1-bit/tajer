import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/subscription_service.dart';
import 'package:flutter/foundation.dart';
import '../../authentication/data/auth_repository.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(premiumProductDetailsProvider);
    final isGuest = ref.watch(authRepositoryProvider).currentUser?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_112, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 80, color: Colors.amber),
              SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.text_113,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.text_114,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
              ),
              SizedBox(height: 32),
              
              if (isGuest) ...[
                Text(
                  AppLocalizations.of(context)!.text_115,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontFamily: 'Tajawal'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/upgrade'),
                  child: Text(AppLocalizations.of(context)!.text_116, style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ] else if (kIsWeb) ...[
                Text(
                  AppLocalizations.of(context)!.text_117,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue, fontFamily: 'Tajawal', fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.text_118,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
              ] else ...[
                productAsync.when(
                  data: (product) {
                    if (product == null) {
                      return Text(
                        AppLocalizations.of(context)!.text_119,
                        style: TextStyle(fontFamily: 'Tajawal'),
                      );
                    }
                    
                    return Column(
                      children: [
                        Text(
                          '${product.price} / ${product.title}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(subscriptionServiceProvider).buyPremium(product);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          ),
                          child: Text(AppLocalizations.of(context)!.text_120, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(subscriptionServiceProvider).restorePurchases();
                          },
                          child: Text(AppLocalizations.of(context)!.text_121, style: TextStyle(fontFamily: 'Tajawal')),
                        ),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (err, stack) => Text('حدث خطأ: $err', style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
