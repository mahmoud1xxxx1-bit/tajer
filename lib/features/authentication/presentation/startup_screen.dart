import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/services/app_error_mapper.dart';
import '../../../core/widgets/tajer_message.dart';
import '../../../core/services/data_migration_service.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _isLoading = false;

  void _showSuccess(String message) {
    TajerMessage.success(
      context,
      AppErrorMapper.success(ar: message, en: message),
    );
  }

  Future<void> _handleDataMerge(Function(bool) onDecide) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isAr ? "دمج البيانات" : "Merge Data",
            style: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Text(
            isAr
                ? "لقد وجدنا حساباً مسجلاً مسبقاً. هل تريد دمج البيانات التجريبية الحالية (إن وجدت) مع حسابك القديم؟"
                : "We found an existing account. Do you want to merge current trial data (if any) with your old account?",
            style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isAr ? "تجاهل البيانات" : "Ignore Data",
                style:
                    const TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isAr ? "نعم، دمج البيانات" : "Yes, Merge Data",
                style: const TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
    if (result != null) {
      await onDecide(result);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInOrLinkWithGoogle();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      _showSuccess(isAr
          ? "تم تسجيل الدخول بنجاح كتاجر"
          : "Logged in successfully as merchant");
    } catch (e) {
      if (e.toString().contains('requires-merge-decision')) {
        await _handleDataMerge((merge) async {
          setState(() => _isLoading = true);
          try {
            if (e.toString().contains('web')) {
              await ref.read(authRepositoryProvider).resolveMergeWeb(
                  merge, ref.read(dataMigrationServiceProvider));
            } else {
              await ref
                  .read(authRepositoryProvider)
                  .resolveMerge(merge, ref.read(dataMigrationServiceProvider));
            }
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            _showSuccess(
                isAr ? "تم تسجيل الدخول بنجاح" : "Logged in successfully");
          } catch (ex) {
            TajerMessage.show(context, AppErrorMapper.fromError(ex));
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        });
      } else {
        TajerMessage.show(context, AppErrorMapper.fromError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enterAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
    } catch (e) {
      TajerMessage.show(context, AppErrorMapper.fromError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmployeeLoginDialog() {
    final emailController = TextEditingController();
    final pinController = TextEditingController();
    bool isLoggingIn = false;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isAr ? "دخول الموظف" : "Employee Login",
                  style: const TextStyle(
                      fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      isAr
                          ? "أدخل إيميل التاجر ورمز الدخول الخاص بك (PIN)."
                          : "Enter merchant email and your PIN.",
                      style:
                          const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: isAr
                          ? "إيميل التاجر (الأساسي)"
                          : "Merchant Email (Primary)",
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: isAr ? "رمز الدخول (PIN)" : "PIN code",
                      prefixIcon: const Icon(Icons.password),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoggingIn ? null : () => Navigator.of(context).pop(),
                  child: Text(isAr ? "إلغاء" : "Cancel",
                      style: const TextStyle(
                          fontFamily: 'Tajawal', color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoggingIn
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final pin = pinController.text.trim();

                          if (email.isEmpty || pin.isEmpty) {
                            TajerMessage.show(
                              context,
                              AppErrorMapper.validation(
                                ar: "يرجى إدخال البريد ورمز الدخول",
                                en: "Please enter email and PIN",
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isLoggingIn = true);

                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .signInAsEmployee(email, pin);
                            Navigator.of(context).pop();
                            TajerMessage.success(
                              context,
                              AppErrorMapper.success(
                                ar: "تم تسجيل دخول الموظف بنجاح",
                                en: "Employee signed in successfully",
                              ),
                            );
                          } catch (e) {
                            TajerMessage.show(
                              context,
                              AppErrorMapper.fromError(e,
                                  domain: 'employee-login'),
                            );
                          } finally {
                            if (mounted) {
                              setDialogState(() => isLoggingIn = false);
                            }
                          }
                        },
                  child: isLoggingIn
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isAr ? "تسجيل الدخول" : "Login",
                          style: const TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.storefront,
                  size: 100, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                isAr ? "نظام تاجر" : "Tajer System",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? "أهلاً بك في منصة المبيعات المتكاملة"
                    : "Welcome to the integrated sales platform",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'Tajawal',
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),

              // Merchant Login
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: _isLoading
                    ? const SizedBox()
                    : const Icon(Icons.g_mobiledata, size: 32),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        isAr
                            ? "دخول التاجر (Google)"
                            : "Merchant Login (Google)",
                        style: const TextStyle(
                            fontSize: 18,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Employee Login
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _showEmployeeLoginDialog,
                icon: const Icon(Icons.badge, size: 24),
                label: Text(
                    isAr ? "دخول موظف (بالرمز)" : "Employee Login (PIN)",
                    style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 32),

              // Guest Login
              TextButton(
                onPressed: _isLoading ? null : _enterAsGuest,
                child: Text(
                    isAr
                        ? "الدخول كزائر وتجربة النظام"
                        : "Enter as guest and try the system",
                    style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
