import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/subscription_service.dart';
import 'package:flutter/foundation.dart';
import '../../authentication/data/auth_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(premiumPackagesProvider);
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
                packagesAsync.when(
                  data: (packages) {
                    if (packages.isEmpty) {
                      return Text(
                        AppLocalizations.of(context)!.text_119,
                        style: TextStyle(fontFamily: 'Tajawal'),
                      );
                    }
                    
                    return Column(
                      children: packages.map((package) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            children: [
                              Text(
                                '${package.storeProduct.priceString} / ${package.storeProduct.title}',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () async {
                                  final success = await ref.read(subscriptionServiceProvider).buyPackage(package);
                                  if (success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('تم تفعيل الاشتراك بنجاح!', style: TextStyle(fontFamily: 'Tajawal'))),
                                    );
                                    context.pop(); // Go back
                                  } else if (context.mounted) {
                                     ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('فشلت عملية الدفع أو تم إلغاؤها', style: TextStyle(fontFamily: 'Tajawal'))),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                ),
                                child: Text(AppLocalizations.of(context)!.text_120, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                              ),
                            ],
                          ),
                        );
                      }).toList()..add(
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextButton(
                            onPressed: () async {
                              final restored = await ref.read(subscriptionServiceProvider).restorePurchases();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(restored ? 'تم استعادة المشتريات وتفعيل الاشتراك' : 'لا يوجد اشتراك نشط لاستعادته', style: TextStyle(fontFamily: 'Tajawal'))),
                                );
                                if (restored) context.pop();
                              }
                            },
                            child: Text(AppLocalizations.of(context)!.text_121, style: TextStyle(fontFamily: 'Tajawal')),
                          ),
                        ),
                      ),
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
