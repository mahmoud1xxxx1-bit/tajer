import 'package:flutter/material.dart';
import '../../../core/theme/glass_card.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'دليل استخدام التطبيق' : 'App User Guide', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.menu_book, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    isAr ? 'أهلاً بك في دليل تاجر!' : 'Welcome to Tajer Guide!',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr 
                      ? 'هذا الدليل سيساعدك خطوة بخطوة لضبط متجرك بشكل صحيح والبدء في البيع وإدارة المخزون باحترافية.'
                      : 'This guide will help you step-by-step to set up your store correctly and start selling and managing inventory professionally.',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildGuideStep(
            context,
            isAr,
            titleAr: '١. إعداد المتجر والضرائب',
            titleEn: '1. Store Setup & Taxes',
            icon: Icons.store,
            contentAr: 'من شاشة الإعدادات، ادخل إلى "إعدادات المتجر".\nقم بكتابة اسم متجرك، وتأكد من كتابة الرقم الضريبي إن وجد، ونسبة الضريبة (مثلاً 15). هذا سيضمن طباعة الفواتير بشكل متوافق مع هيئة الزكاة والدخل.',
            contentEn: 'From Settings, go to "Store Settings".\nEnter your store name, VAT number if applicable, and tax percentage (e.g. 15). This ensures invoices are printed in compliance with ZATCA.',
          ),
          
          _buildGuideStep(
            context,
            isAr,
            titleAr: '٢. مستودع المواد الخام',
            titleEn: '2. Raw Materials Inventory',
            icon: Icons.inventory_2,
            contentAr: 'المواد الخام هي أساس متجرك. يجب إضافتها بالكمية الكلية.\n\nمثال:\nإذا اشتريت شوال سكر 50 كيلو، قم بإضافته كمادة خام واكتب الكمية 50000 ووحدة القياس "جرام".\nإذا اشتريت كرتون خبز برجر فيه 100 حبة، أضف "خبز برجر" واكتب الكمية 100 ووحدة القياس "حبة".',
            contentEn: 'Raw materials are the foundation of your store. They must be added in total bulk quantity.\n\nExample:\nIf you buy a 50kg bag of sugar, add it as a raw material with quantity 50000 and unit "gram".\nIf you buy a box of burger buns with 100 pieces, add it with quantity 100 and unit "piece".',
          ),
          
          _buildGuideStep(
            context,
            isAr,
            titleAr: '٣. إضافة المنتجات والمقادير (الريسبي)',
            titleEn: '3. Adding Products & Recipes',
            icon: Icons.fastfood,
            contentAr: 'بعد إضافة المواد الخام، اذهب لصفحة "المنتجات" وأضف منتجاً يراه العميل (مثلاً: برجر لحم).\nفي خانة "المقادير (الريسبي)"، اربط المنتج بالمواد الخام التي يتكون منها، واكتب "الكمية المخصومة للطلب الواحد".\n\nمثال:\nلصنع برجر لحم واحد، النظام سيخصم تلقائياً (1 حبة خبز) و (150 جرام لحم) من المستودع عند كل عملية بيع.',
            contentEn: 'After adding raw materials, go to "Products" and add a product the customer buys (e.g. Beef Burger).\nIn the "Recipe" section, link the product to its raw materials, and enter the "Amount deducted per order".\n\nExample:\nTo make one Beef Burger, the system will automatically deduct (1 piece of bun) and (150 grams of meat) from the inventory upon each sale.',
          ),
          
          _buildGuideStep(
            context,
            isAr,
            titleAr: '٤. نقطة البيع (الكاشير)',
            titleEn: '4. Point of Sale (POS)',
            icon: Icons.point_of_sale,
            contentAr: 'اذهب لشاشة الطلبات، واضغط على زر (+) لفتح الكاشير.\nاختر المنتجات، واضغط على الدفع.\nإذا دفع العميل كاش بمبلغ أكبر من الفاتورة، يمكنك كتابة "المبلغ المستلم" وسيحسب لك النظام تلقائياً "المتبقي للعميل" لترجعه له بدون أخطاء.',
            contentEn: 'Go to Orders screen, press (+) to open POS.\nSelect products, and press Pay.\nIf the customer pays cash with a larger bill, you can enter the "Tendered Amount" and the system will calculate the "Change Given" automatically so you return it without errors.',
          ),
          
          _buildGuideStep(
            context,
            isAr,
            titleAr: '٥. العملاء والديون',
            titleEn: '5. Customers & Debts',
            icon: Icons.people,
            contentAr: 'يمكنك البيع بالآجل (دين) للعملاء.\nعند الدفع، فعّل خيار "دفع آجل"، واكتب المبلغ الذي دفعه العميل حالياً (أو صفر). النظام سيسجل الباقي كدين على العميل.\nيمكنك لاحقاً الذهاب لشاشة "العملاء" وتسديد ديونهم عند الدفع.',
            contentEn: 'You can sell on credit (debt) to customers.\nAt checkout, enable "Pay on Credit", and enter the amount paid right now (or zero). The system will record the rest as debt on the customer.\nYou can later go to "Customers" screen and settle their debts.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٦. الورديات والتقارير',
            titleEn: '6. Shifts & Reports',
            icon: Icons.analytics,
            contentAr: 'قبل البدء بالعمل، يجب أن يفتح الموظف "وردية جديدة" ويكتب المبلغ الموجود في الدرج.\nفي نهاية اليوم، يقوم الموظف بإنهاء الوردية. سيحسب النظام كل الفواتير والمبالغ الكاش المستلمة ويخبرك بالمبلغ الإجمالي الذي يجب أن يكون في الدرج لضمان عدم وجود عجز.',
            contentEn: 'Before starting work, the employee must open a "New Shift" and enter the cash starting amount in the drawer.\nAt the end of the day, the employee ends the shift. The system calculates all invoices and cash received, and tells you the exact total amount that should be in the drawer to ensure no shortages.',
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGuideStep(BuildContext context, bool isAr, {required String titleAr, required String titleEn, required IconData icon, required String contentAr, required String contentEn}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: ExpansionTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(isAr ? titleAr : titleEn, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isAr ? contentAr : contentEn,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
