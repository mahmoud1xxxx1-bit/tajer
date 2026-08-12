import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/glass_card.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الترقية (Pro)', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.workspace_premium, size: 80, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'الاشتراك الاحترافي',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
            ),
            SizedBox(height: 8),
            Text(
              'أطلق العنان لإمكانيات متجرك بدون أي قيود!',
              style: TextStyle(fontSize: 16, color: Colors.grey[700], fontFamily: 'Tajawal'),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            GlassCard(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '10\$',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  Text(
                    'شهرياً',
                    style: TextStyle(fontSize: 18, color: Colors.grey, fontFamily: 'Tajawal'),
                  ),
                  Divider(height: 32),
                  _buildFeatureRow('عدد غير محدود من المنتجات'),
                  _buildFeatureRow('عدد غير محدود من الطلبات والعملاء'),
                  _buildFeatureRow('إضافة حسابات لا محدودة للموظفين (كاشير)'),
                  _buildFeatureRow('تقارير مالية مفصلة وتصدير PDF'),
                  _buildFeatureRow('دعم فني ذو أولوية'),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement In-App Purchases (Google Play Billing)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('سيتم تفعيل الدفع قريباً بعد رفع التطبيق على متجر جوجل.', style: TextStyle(fontFamily: 'Tajawal'))),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'اشترك الآن',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }
}
