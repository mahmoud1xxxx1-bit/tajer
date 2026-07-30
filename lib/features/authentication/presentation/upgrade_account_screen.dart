import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/services/data_migration_service.dart';

class UpgradeAccountScreen extends ConsumerStatefulWidget {
  const UpgradeAccountScreen({super.key});

  @override
  ConsumerState<UpgradeAccountScreen> createState() => _UpgradeAccountScreenState();
}

class _UpgradeAccountScreenState extends ConsumerState<UpgradeAccountScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLinked = false;
  String _linkedEmail = '';

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (!user.isAnonymous) {
        setState(() {
          _isLinked = true;
          _linkedEmail = user.email ?? 'حساب مسجل';
        });
      }
      
      // Fetch phone if exists
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final phone = doc.data()!['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          _phoneController.text = phone;
        }
      }
    }
  }

  Future<void> _handleDataMerge(Future<void> Function(bool merge) onDecide) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('دمج البيانات', style: TextStyle(fontFamily: 'Tajawal')),
        content: Text(
          'لقد قمت مسبقاً بإنشاء حساب بهذا البريد.\nهل تريد دمج أي بيانات تجريبية قمت بإضافتها (كالمنتجات أو الطلبات) مع حسابك القديم؟',
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('لا، أريد حسابي القديم فقط', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('نعم، قم بالدمج', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );

    if (result != null) {
      await onDecide(result);
    }
  }

  Future<void> _linkGoogleAccount() async {
    setState(() => _isLoading = true);
    try {
      final appUser = ref.read(appUserProvider).value;
      if (appUser == null) throw Exception(AppLocalizations.of(context)!.text_29);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception(AppLocalizations.of(context)!.text_29);

      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInOrLinkWithGoogle();

      setState(() {
        _isLinked = true;
        _linkedEmail = FirebaseAuth.instance.currentUser?.email ?? 'حساب مسجل';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.text_31)),
        );
      }
    } catch (e) {
      if (e.toString().contains('requires-merge-decision')) {
        await _handleDataMerge((merge) async {
           final authRepo = ref.read(authRepositoryProvider);
           final migrationService = ref.read(dataMigrationServiceProvider);
           
           try {
             setState(() => _isLoading = true);
             await authRepo.resolveMerge(merge, migrationService);
             
             setState(() {
               _isLinked = true;
               _linkedEmail = FirebaseAuth.instance.currentUser?.email ?? 'حساب مسجل';
             });
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(AppLocalizations.of(context)!.text_31)),
               );
             }
           } catch (mergeError) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('خطأ في الدمج: $mergeError')),
               );
             }
           }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الربط: ${e.toString().replaceAll("Exception: ", "")}')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.text_32)),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    if (mounted) {
      Navigator.pop(context); // Go back to dashboard/paywall
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_33, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.text_34,
              style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            if (!_isLinked) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _linkGoogleAccount,
                icon: Icon(Icons.g_mobiledata, size: 32),
                label: Text(AppLocalizations.of(context)!.text_35, style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => context.push('/email_auth'),
                icon: Icon(Icons.email, size: 24),
                label: Text('ربط باستخدام البريد الإلكتروني', style: TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.blue[900],
                ),
              ),
            ] else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('تم تسجيل الدخول وتأمين حسابك بنجاح', style: TextStyle(fontFamily: 'Tajawal', color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'باستخدام: $_linkedEmail',
                    style: TextStyle(fontFamily: 'Tajawal', color: Colors.blue[900], fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.text_37,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              enabled: _isLinked,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (_isLinked && !_isLoading) ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator()
                : Text(AppLocalizations.of(context)!.text_38, style: TextStyle(fontSize: 18, fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }
}


