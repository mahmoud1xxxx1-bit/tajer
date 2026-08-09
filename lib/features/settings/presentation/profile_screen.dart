import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/effective_merchant.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final nameController = TextEditingController(text: appUser?.name);

    return Scaffold(
      appBar: AppBar(
        title: Text('الملف الشخصي', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: appUser == null
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                GlassCard(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.person, size: 50, color: Colors.blue),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'الاسم',
                          border: OutlineInputBorder(),
                        ),
                        style: TextStyle(fontFamily: 'Tajawal'),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(text: appUser.email),
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                        style: TextStyle(
                            fontFamily: 'Tajawal', color: Colors.grey),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(
                            text: appUser.role == 'cashier' ? 'كاشير' : 'مدير'),
                        decoration: InputDecoration(
                          labelText: 'الصلاحية',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                        style: TextStyle(
                            fontFamily: 'Tajawal', color: Colors.grey),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                        ),
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          if (newName.isNotEmpty && newName != appUser.name) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(appUser.id)
                                  .update({'name': newName});
                              // Also update employee subcollection if they are not the merchant
                              if (!isOwnerLikeRole(appUser.role) &&
                                  appUser.merchantId != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentEffectiveMerchantId(appUser))
                                    .collection('employees')
                                    .doc(appUser.id)
                                    .update({'name': newName});
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'تم تحديث الاسم بنجاح',
                                            style: TextStyle(
                                                fontFamily: 'Tajawal'))));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'حدث خطأ: $e',
                                            style: TextStyle(
                                                fontFamily: 'Tajawal'))));
                              }
                            }
                          }
                        },
                        child: Text('حفظ التعديلات',
                            style:
                                TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
