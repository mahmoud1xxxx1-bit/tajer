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
                    isAr ? 'أهلاً بك في الدليل الشامل لتاجر!' : 'Welcome to Tajer Comprehensive Guide!',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr 
                      ? 'هذا الدليل هو مرجعك الكامل لكل صغيرة وكبيرة في التطبيق، من إعداد متجرك وحتى قراءة تقاريرك المالية باحترافية.'
                      : 'This guide is your complete reference for every detail in the app, from setting up your store to reading your financial reports professionally.',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15),
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
            titleAr: '١. الحسابات والاشتراكات',
            titleEn: '1. Accounts & Subscriptions',
            icon: Icons.manage_accounts,
            contentAr: '• تسجيل الدخول: يمكنك تسجيل الدخول ببريدك الإلكتروني للحفاظ على بيانات متجرك في أمان.\n• الاشتراكات: من قسم الاشتراكات يمكنك اختيار الباقة التي تناسب حجم عملك لتتمتع بجميع ميزات التطبيق بلا قيود.',
            contentEn: '• Login: Log in with your email to keep your store data secure.\n• Subscriptions: Choose the plan that suits your business volume to enjoy all app features without limits.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٢. إعدادات المتجر والنسخ الاحتياطي',
            titleEn: '2. Store Settings & Backup',
            icon: Icons.settings,
            contentAr: '• إعدادات المتجر: أضف اسم متجرك والرقم الضريبي ونسبة الضريبة (مثال: 15%) لتظهر بوضوح في فواتير العملاء وتتوافق مع هيئة الزكاة.\n• النسخ الاحتياطي: ننصحك دائماً بعمل نسخة احتياطية لبياناتك السحابية أو تصديرها كملف Excel لضمان عدم ضياعها.\n• الطباعة: التطبيق يدعم ربط طابعات البلوتوث الحرارية، بالإضافة لإمكانية إصدار الفاتورة كـ PDF أو إرسالها للعميل عبر واتساب.',
            contentEn: '• Store Settings: Add your store name, VAT number, and tax percentage (e.g. 15%) to appear on invoices.\n• Backup: Always backup your data to the cloud or export to Excel to prevent data loss.\n• Printing: The app supports Bluetooth thermal printers, PDF generation, and sharing via WhatsApp.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٣. إدارة الموظفين والصلاحيات',
            titleEn: '3. Employees & Permissions',
            icon: Icons.badge,
            contentAr: '• إضافة كاشير: كمالك للمشروع، يمكنك الذهاب لقسم "الموظفين" وإضافة حسابات لموظفيك.\n• الصلاحيات: الكاشير يستطيع البيع وفتح الورديات، بينما المالك لديه الصلاحية الكاملة لرؤية التقارير المالية وحذف الفواتير.',
            contentEn: '• Add Cashier: As an owner, you can add accounts for your staff in the "Employees" section.\n• Permissions: A cashier can sell and open shifts, while the owner has full access to financial reports and invoice deletion.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٤. الموردين والمصروفات',
            titleEn: '4. Suppliers & Expenses',
            icon: Icons.local_shipping,
            contentAr: '• الموردين: سجل الأشخاص أو الشركات التي تزودك بالبضاعة. يمكنك الشراء منهم بالآجل وتسجيل ديونك لهم.\n• سداد الموردين: عندما تسدد دفعة لمورد، فإن هذا المبلغ يُعتبر من (رأس مالك الخاص) ولا يُخصم من كاش الوردية الحالي لكي لا يظهر عجز لدى الكاشير.\n• المصروفات التشغيلية: (مثل: الإيجار، الرواتب). سجلها لكي تُخصم من إجمالي أرباحك وتعرف ربحك الصافي الحقيقي.',
            contentEn: '• Suppliers: Register your goods providers. You can buy on credit and record your debts to them.\n• Paying Suppliers: Paying a supplier is considered from your own capital, so it does not deduct from the current shift cash to avoid cashier shortages.\n• Expenses: (e.g., Rent, Salaries). Log them to deduct from gross profit and know your true net profit.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٥. المخزون (تصنيفات، مواد خام، منتجات)',
            titleEn: '5. Inventory (Categories, Raw Materials, Products)',
            icon: Icons.inventory_2,
            contentAr: '• التصنيفات: نظّم متجرك (مثال: قسم المشروبات، قسم الوجبات) لتسهيل الوصول إليها.\n• المواد الخام: المكونات الأساسية التي تشتريها بالجملة (مثال: كرتون أكواب، شوال سكر).\n• إضافة منتج: المنتج هو ما تشتريه لكي تبيعه. أدخل السعر والتكلفة لحساب أرباحك.\n\nالخيارات المتقدمة للمنتج:\n- أزرار سريعة (Modifiers): مثل (بدون سكر، سفري) لتسهيل عمل الكاشير.\n- يُصنع عند الطلب (مهم جداً): إذا كان المنتج جاهزاً (كعلبة البيبسي) دعه مغلقاً. وإذا كان يُحضّر (كوجبة برجر) فقم بتفعيله، واربطه بمواده الخام (مثال: يخصم 1 خبز و 1 لحم لكل طلب). هكذا ينقص المخزون الخام فقط ولا يطلب منك إدخال كمية للبرجر نفسه.',
            contentEn: '• Categories: Organize your store (e.g., Drinks, Meals) for easy access.\n• Raw Materials: Basic bulk components (e.g., boxes of cups, bags of sugar).\n• Add Product: Enter price and cost to calculate profits.\n\nAdvanced Options:\n- Modifiers: Quick tags like (No Sugar, To-Go).\n- Made to Order (Crucial): Leave it off for ready items (e.g., Pepsi can). Turn it on for prepared items (e.g., Burger), link it to raw materials (deducts 1 bun, 1 meat per order). The system will only deduct raw materials without requiring stock for the burger itself.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٦. حركة المخزون والإشعارات',
            titleEn: '6. Inventory Log & Notifications',
            icon: Icons.history,
            contentAr: '• سجل المخزون: شاشة مفصلة تخبرك بكل حركة حدثت لمخزونك (شراء بضاعة جديدة، بيع فاتورة، استرجاع). ستعرف أين تذهب بضاعتك بالضبط.\n• الإشعارات: يقوم التطبيق بتنبيهك تلقائياً إذا انخفض مخزون أحد منتجاتك أو موادك الخام عن الحد المسموح لتسارع بإعادة تعبئته.',
            contentEn: '• Inventory Log: A detailed screen showing every inventory movement (purchases, sales, refunds) so you track your goods exactly.\n• Notifications: The app auto-alerts you if stock levels of products or raw materials drop below the threshold so you can restock.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٧. العملاء والديون',
            titleEn: '7. Customers & Debts',
            icon: Icons.people,
            contentAr: '• إدارة العملاء: يمكنك تسجيل بيانات عملائك لتقوية ولائهم.\n• البيع الآجل (الدين): عند دفع الفاتورة بالكاشير، اختر "بيع آجل"، وسيسجل النظام الفاتورة كدين على العميل.\n• السداد: عندما يسدد العميل دينه لك نقداً في وقت لاحق، فإن هذا المبلغ النقدي المستلم سيدخل فوراً في حسبة كاش الوردية الحالية.',
            contentEn: '• Customers: Register customers to build loyalty.\n• Credit Sales: At POS checkout, select "Credit Sale" and the invoice becomes debt on the customer.\n• Repayment: When a customer repays their debt in cash later, this cash immediately adds to the current shift\'s cash drawer.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٨. نقطة البيع والكاشير (POS)',
            titleEn: '8. Point of Sale (POS)',
            icon: Icons.point_of_sale,
            contentAr: '• البيع السريع: يمكنك مسح الباركود بالكاميرا أو الضغط على المنتجات.\n• تعليق الطلب: إذا نسي العميل محفظته وأراد إحضارها، يمكنك "تعليق" الفاتورة لخدمة العميل الذي يليه، والعودة للفاتورة لاحقاً.\n• الدفع المتعدد: يمكنك تقسيم الفاتورة (مثال: العميل دفع 50 ريال كاش، و 20 ريال ببطاقة مدى). النظام سيفصلها بدقة تامة في التقارير.',
            contentEn: '• Quick Sale: Scan barcodes or tap products.\n• Hold Order: If a customer forgets their wallet, "Hold" the invoice, serve the next customer, and resume later.\n• Split Payment: Split the bill (e.g., 50 SAR Cash, 20 SAR Card). The system tracks each separately in reports.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '٩. المرتجعات (Refunds)',
            titleEn: '9. Refunds',
            icon: Icons.keyboard_return,
            contentAr: '• عند إرجاع أو حذف طلب، يقوم النظام بـ:\n1. إعادة المنتجات أو المواد الخام فوراً إلى المستودع.\n2. خصم ضريبة الفاتورة من إجمالي ضرائب الوردية (لكي لا تدفع ضريبة عليها).\n3. إنقاص "الكاش المتوقع في الدرج" بقيمة الفاتورة المرتجعة للعميل.',
            contentEn: '• When refunding or deleting an order, the system:\n1. Returns products/materials to inventory instantly.\n2. Deducts the invoice tax from the shift\'s total taxes.\n3. Reduces the "Expected Drawer Cash" by the refunded amount.',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '١٠. الورديات (Shifts) وحساب الدرج',
            titleEn: '10. Shifts & Drawer Calculation',
            icon: Icons.lock_clock,
            contentAr: '• الوردية هي الأساس لضبط أموالك. يبدأ الموظف يومه بفتح وردية وتسجيل الكاش الافتتاحي.\n\nمثال حسابي لكيفية احتساب الكاش في الدرج:\n• فتحت الدرج وفيه: 100 ريال.\n• مبيعات (كاش): +200 ريال.\n• مبيعات (بطاقة/مدى): +150 ريال (تذهب لحسابك البنكي، لا تُحسب في الدرج).\n• دفع العميل دينه السابق (كاش): +50 ريال.\n• مصروفات دُفعت من الدرج: -20 ريال.\n• مرتجعات كاش للعميل: -30 ريال.\n\n= الكاش المتوقع في الدرج عند الإغلاق: 100 + 200 + 50 - 20 - 30 = (300 ريال).',
            contentEn: '• Shifts control your money. The employee opens a shift and logs starting cash.\n\nDrawer Calculation Example:\n• Opened drawer with: 100 SAR.\n• Cash Sales: +200 SAR.\n• Card Sales: +150 SAR (goes to bank, ignored in drawer).\n• Customer debt repaid (cash): +50 SAR.\n• Expenses paid from drawer: -20 SAR.\n• Cash Refunds: -30 SAR.\n\n= Expected Cash at Close: 100 + 200 + 50 - 20 - 30 = (300 SAR).',
          ),

          _buildGuideStep(
            context,
            isAr,
            titleAr: '١١. التقارير المالية (فهم الأرباح)',
            titleEn: '11. Financial Reports & Profits',
            icon: Icons.analytics,
            contentAr: '• إجمالي المبيعات (Revenue): جميع الأموال التي دخلت لك من المبيعات.\n• تكلفة البضاعة المباعة (COGS): تكلفة البضاعة التي تم بيعها فقط (بناءً على التكلفة التي حددتها للمنتج).\n• إجمالي الربح (Gross Profit): مبيعاتك ناقص التكلفة (COGS).\n• المصروفات (Expenses): الإيجارات، فواتير الكهرباء.\n• صافي الربح (Net Profit): إجمالي الربح ناقص المصروفات (وهو ربحك الصافي النهائي).\n\nستجد رسوماً بيانية تفصيلية توضح لك مبيعاتك اليومية ومصروفاتك في صفحة التقارير.',
            contentEn: '• Revenue: All money from sales.\n• COGS: Cost of only the goods that were sold.\n• Gross Profit: Revenue minus COGS.\n• Expenses: Rent, bills, salaries.\n• Net Profit: Gross Profit minus Expenses (Your final take-home profit).\n\nDetailed charts for daily sales and expenses are available in the Reports screen.',
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
              child: Align(
                alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  isAr ? contentAr : contentEn,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
