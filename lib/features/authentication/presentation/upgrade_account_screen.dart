import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../authentication/data/auth_repository.dart';

class UpgradeAccountScreen extends ConsumerStatefulWidget {
  const UpgradeAccountScreen({super.key});

  @override
  ConsumerState<UpgradeAccountScreen> createState() => _UpgradeAccountScreenState();
}

class _UpgradeAccountScreenState extends ConsumerState<UpgradeAccountScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLinked = false;

  Future<void> _linkGoogleAccount() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('تم إلغاء تسجيل الدخول');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        setState(() => _isGoogleLinked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم ربط الحساب بنجاح!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الربط: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الهاتف')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // TODO: Update Firestore with the phone number
    
    Navigator.pop(context); // Go back to dashboard/paywall
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال التسجيل', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'لحماية بياناتك من الضياع، يرجى ربط حسابك بـ Google وإدخال رقم للتواصل.',
              style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!_isGoogleLinked)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _linkGoogleAccount,
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: const Text('الربط بحساب Google', style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            else
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('تم ربط الحساب بنجاح', style: TextStyle(fontFamily: 'Tajawal', color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (الواتساب)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              enabled: _isGoogleLinked,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (_isGoogleLinked && !_isLoading) ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator()
                : const Text('حفظ والمتابعة', style: TextStyle(fontSize: 18, fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }
}
