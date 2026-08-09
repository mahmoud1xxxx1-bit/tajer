import 'employee_permission_catalog.dart';

enum EmployeePermissionGroup {
  sales,
  customers,
  inventory,
  finance,
  reports,
}

class EmployeePermissionPresentation {
  final String key;
  final EmployeePermissionGroup group;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;

  const EmployeePermissionPresentation({
    required this.key,
    required this.group,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
  });
}

abstract final class EmployeePermissionPresentationCatalog {
  static const items = <EmployeePermissionPresentation>[
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.createOrders,
      group: EmployeePermissionGroup.sales,
      titleAr: 'إنشاء المبيعات والطلبات',
      titleEn: 'Create sales and orders',
      descriptionAr:
          'يسمح للموظف بإنشاء فاتورة بيع جديدة داخل الفروع المعيّنة له فقط.',
      descriptionEn:
          'Allows the employee to create new sales only in assigned branches.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.cancelOrders,
      group: EmployeePermissionGroup.sales,
      titleAr: 'إلغاء الطلبات والفواتير',
      titleEn: 'Cancel orders and invoices',
      descriptionAr:
          'صلاحية مالية حساسة تعكس آثار الفاتورة والمخزون عند الإلغاء.',
      descriptionEn:
          'Sensitive financial permission that reverses invoice and stock effects.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.sellOnCredit,
      group: EmployeePermissionGroup.sales,
      titleAr: 'البيع الآجل',
      titleEn: 'Sell on credit',
      descriptionAr: 'يسمح بإنشاء مديونية على العميل بدل التحصيل الفوري.',
      descriptionEn:
          'Allows creating customer debt instead of immediate payment.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.viewAllOrders,
      group: EmployeePermissionGroup.sales,
      titleAr: 'عرض جميع الطلبات',
      titleEn: 'View all orders',
      descriptionAr:
          'يسمح بعرض طلبات موظفين آخرين ضمن نطاق الفروع المسموحة له.',
      descriptionEn:
          'Allows viewing other employees’ orders within assigned branches.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.manageCustomers,
      group: EmployeePermissionGroup.customers,
      titleAr: 'إدارة العملاء',
      titleEn: 'Manage customers',
      descriptionAr: 'إضافة وتعديل بيانات العملاء.',
      descriptionEn: 'Create and edit customer records.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.receivePayments,
      group: EmployeePermissionGroup.customers,
      titleAr: 'استلام دفعات العملاء',
      titleEn: 'Receive customer payments',
      descriptionAr:
          'يسمح بتسجيل سداد ديون العملاء، وهي عملية مالية يجب منحها للمخولين فقط.',
      descriptionEn:
          'Allows recording customer debt payments; grant only to authorized staff.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.manageProducts,
      group: EmployeePermissionGroup.inventory,
      titleAr: 'إدارة المنتجات',
      titleEn: 'Manage products',
      descriptionAr: 'إضافة وتعديل بيانات المنتجات الأساسية.',
      descriptionEn: 'Create and edit product master data.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.manageInventory,
      group: EmployeePermissionGroup.inventory,
      titleAr: 'إدارة المخزون',
      titleEn: 'Manage inventory',
      descriptionAr: 'تعديل الكميات وتنفيذ تحويلات المخزون في الفروع المسموحة.',
      descriptionEn:
          'Adjust quantities and transfer stock within assigned branches.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.viewCost,
      group: EmployeePermissionGroup.inventory,
      titleAr: 'عرض تكلفة المنتجات',
      titleEn: 'View product cost',
      descriptionAr: 'يسمح بعرض تكلفة الشراء وهو بيان تجاري حساس.',
      descriptionEn:
          'Allows viewing purchase cost, which is sensitive business data.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.manageExpenses,
      group: EmployeePermissionGroup.finance,
      titleAr: 'إدارة المصروفات',
      titleEn: 'Manage expenses',
      descriptionAr: 'إضافة وتعديل وحذف المصروفات ضمن نطاق الفرع المسموح.',
      descriptionEn:
          'Create, edit and delete expenses within the allowed branch scope.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.viewReports,
      group: EmployeePermissionGroup.reports,
      titleAr: 'عرض التقارير',
      titleEn: 'View reports',
      descriptionAr:
          'يسمح بالوصول إلى التقارير المتاحة ضمن نطاق الفروع المسموحة.',
      descriptionEn: 'Allows access to reports limited to assigned branches.',
    ),
    EmployeePermissionPresentation(
      key: EmployeePermissionKeys.viewShiftArchive,
      group: EmployeePermissionGroup.reports,
      titleAr: 'عرض أرشيف الورديات',
      titleEn: 'View shift archive',
      descriptionAr: 'يسمح بعرض أرشيف الورديات ضمن الفروع المعينة فقط.',
      descriptionEn:
          'Allows viewing shift archive within assigned branches only.',
    ),
  ];

  static Set<String> get keys => items.map((item) => item.key).toSet();

  static List<EmployeePermissionPresentation> forGroup(
    EmployeePermissionGroup group,
  ) =>
      items.where((item) => item.group == group).toList(growable: false);
}
