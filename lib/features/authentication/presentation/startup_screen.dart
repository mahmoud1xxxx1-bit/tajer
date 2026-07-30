import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/services/data_migration_service.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.green),
    );
  }

  Future<void> _handleDataMerge(Function(bool) onDecide) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("دمج البيانات", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: const Text(
            "لقد وجدنا حساباً مسجلاً مسبقاً. هل تريد دمج البيانات التجريبية الحالية (إن وجدت) مع حسابك القديم؟",
            style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("تجاهل البيانات", style: TextStyle(fontFamily: 'Tajawal', color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("نعم، دمج البيانات", style: TextStyle(fontFamily: 'Tajawal')),
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
      _showSuccess("تم تسجيل الدخول بنجاح كتاجر");
    } catch (e) {
      if (e.toString().contains('requires-merge-decision')) {
        await _handleDataMerge((merge) async {
          setState(() => _isLoading = true);
          try {
            if (e.toString().contains('web')) {
               await ref.read(authRepositoryProvider).resolveMergeWeb(merge, ref.read(dataMigrationServiceProvider));
            } else {
               await ref.read(authRepositoryProvider).resolveMerge(merge, ref.read(dataMigrationServiceProvider));
            }
            _showSuccess("تم تسجيل الدخول بنجاح");
          } catch(ex) {
            _showError(ex.toString().replaceAll("Exception: ", ""));
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        });
      } else {
        _showError(e.toString().replaceAll("Exception: ", ""));
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
      _showError("حدث خطأ: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmployeeLoginDialog() {
    final emailController = TextEditingController();
    final pinController = TextEditingController();
    bool isLoggingIn = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("دخول الموظف", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("أدخل إيميل التاجر ورمز الدخول الخاص بك (PIN).", style: TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "إيميل التاجر (الأساسي)",
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: "رمز الدخول (PIN)",
                      prefixIcon: Icon(Icons.password),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoggingIn ? null : () => Navigator.of(context).pop(),
                  child: const Text("إلغاء", style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoggingIn ? null : () async {
                    final email = emailController.text.trim();
                    final pin = pinController.text.trim();

                    if (email.isEmpty || pin.isEmpty) {
                      _showError("يرجى إدخال الإيميل ورمز الدخول");
                      return;
                    }

                    setDialogState(() => isLoggingIn = true);

                    try {
                      await ref.read(authRepositoryProvider).signInAsEmployee(email, pin);
                      Navigator.of(context).pop();
                      _showSuccess("تم تسجيل دخول الموظف بنجاح");
                    } catch (e) {
                      _showError(e.toString().replaceAll("Exception: ", ""));
                    } finally {
                      if (mounted) {
                        setDialogState(() => isLoggingIn = false);
                      }
                    }
                  },
                  child: isLoggingIn 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("تسجيل الدخول", style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.storefront, size: 100, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                "نظام تاجر",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "أهلاً بك في منصة المبيعات المتكاملة",
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
                icon: _isLoading ? const SizedBox() : const Icon(Icons.g_mobiledata, size: 32),
                label: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("دخول التاجر (Google)", style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
                label: const Text("دخول موظف (بالرمز)", style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 32),
              
              // Guest Login
              TextButton(
                onPressed: _isLoading ? null : _enterAsGuest,
                child: const Text("الدخول كزائر وتجربة النظام", style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
