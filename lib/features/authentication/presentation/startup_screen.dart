import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';
import 'auth_controller.dart';
import '../../../core/services/data_migration_service.dart';
import 'package:flutter/foundation.dart';

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

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

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("يرجى إدخال البريد الإلكتروني وكلمة المرور");
      return;
    }

    if (!_isLogin && name.isEmpty) {
      _showError("يرجى إدخال اسمك");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final migrationService = ref.read(dataMigrationServiceProvider);

      if (_isLogin) {
        await authRepo.signInWithEmail(email, password, mergeData: false, migrationService: migrationService);
        _showSuccess("تم تسجيل الدخول بنجاح");
      } else {
        if (authRepo.currentUser == null) {
          await authRepo.signInAnonymously();
        }
        await authRepo.signUpWithEmail(email, password, name);
        _showSuccess("تم إنشاء الحساب! يرجى مراجعة بريدك الإلكتروني لتفعيله (تأكد من مجلد Spam/الرسائل غير المرغوب فيها).");
      }
    } catch (e) {
      if (e.toString().contains("email-not-verified")) {
        _showError("يرجى تفعيل بريدك الإلكتروني أولاً عبر الرابط المرسل إليك (تأكد من مجلد Spam/الرسائل غير المرغوب فيها).");
      } else if (e.toString().contains('requires-merge-decision')) {
        await _handleDataMerge((merge) async {
           // We will handle merge logic below for google, but for email login it's different.
           // Actually email login doesn't throw requires-merge-decision right now. 
        });
      } else {
        _showError(e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);

      await authRepo.signInOrLinkWithGoogle();
      _showSuccess("تم تسجيل الدخول بنجاح");
    } catch (e) {
      if (e.toString().contains('requires-merge-decision-web')) {
        await _handleDataMerge((merge) async {
          setState(() => _isLoading = true);
          try {
            await ref.read(authRepositoryProvider).resolveMergeWeb(merge, ref.read(dataMigrationServiceProvider));
            _showSuccess("تم تسجيل الدخول بنجاح");
          } catch(ex) {
            _showError(ex.toString().replaceAll("Exception: ", ""));
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        });
      } else if (e.toString().contains('requires-merge-decision')) {
        await _handleDataMerge((merge) async {
          setState(() => _isLoading = true);
          try {
            await ref.read(authRepositoryProvider).resolveMerge(merge, ref.read(dataMigrationServiceProvider));
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

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError("يرجى إدخال بريدك الإلكتروني أولاً");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      _showSuccess("تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني (يرجى تفقد مجلد Spam إذا لم تجده)");
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
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
              Icon(Icons.storefront, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                "تطبيق تاجر",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "الاسم",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "كلمة المرور",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              
              if (_isLogin)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text("نسيت كلمة المرور؟", style: TextStyle(fontFamily: 'Tajawal')),
                  ),
                )
              else
                const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitEmailAuth,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _isLogin ? "تسجيل الدخول" : "إنشاء حساب",
                      style: const TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                    ),
              ),
              
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text("المتابعة باستخدام حساب Google", style: TextStyle(fontFamily: 'Tajawal')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              const SizedBox(height: 16),
              
              TextButton(
                onPressed: _isLoading ? null : _enterAsGuest,
                child: const Text("الدخول لاحقاً كزائر وتجربة التطبيق", style: TextStyle(fontFamily: 'Tajawal', decoration: TextDecoration.underline)),
              ),

              const SizedBox(height: 24),
              
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin ? "ليس لديك حساب؟ إنشاء حساب جديد" : "لديك حساب بالفعل؟ تسجيل الدخول",
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
