import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
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
      SnackBar(content: Text(message, style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.green),
    );
  }

  Future<void> _submit() async {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (_isLogin) {
        await authRepo.signInWithEmail(email, password);
        _showSuccess("تم تسجيل الدخول بنجاح");
        if (mounted) context.go('/');
      } else {
        final isAnonymous = authRepo.currentUser?.isAnonymous ?? false;
        await authRepo.signUpWithEmail(email, password, name, forceLogout: !isAnonymous);
        
        if (isAnonymous) {
          _showSuccess("تم ربط الحساب بنجاح! يرجى مراجعة بريدك الإلكتروني لتفعيله لاحقاً.");
          if (mounted) Navigator.pop(context); // Go back to settings
        } else {
          _showSuccess("تم إنشاء الحساب! يرجى مراجعة بريدك الإلكتروني لتفعيله");
          if (mounted) context.go('/'); // Fresh signup, go to root to login
        }
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError("يرجى إدخال بريدك الإلكتروني أولاً في الحقل أعلاه");
      return;
    }

    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      _showSuccess("تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني");
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? "تسجيل الدخول" : "إنشاء حساب جديد", style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _isLogin ? Icons.login : Icons.person_add,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 32),
            
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "الاسم",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
            ],

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "البريد الإلكتروني",
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "كلمة المرور",
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(),
              ),
            ),
            
            if (_isLogin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: Text("نسيت كلمة المرور؟", style: TextStyle(fontFamily: 'Tajawal')),
                ),
              )
            else
              SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    _isLogin ? "تسجيل الدخول" : "إنشاء حساب",
                    style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                  ),
            ),
            
            SizedBox(height: 24),
            
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
              child: Text(
                _isLogin ? "ليس لديك حساب؟ إنشاء حساب جديد" : "لديك حساب بالفعل؟ تسجيل الدخول",
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
