import 'package:flutter/material.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../domain/employee_permission_catalog.dart';

import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/providers/settings_provider.dart';
import 'employee_activity_screen.dart';
import '../../../../../../../../core/theme/glass_card.dart';

void showBeautifulUpgradeDialog(BuildContext context) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.amber, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? "ترقية الحساب" : "Upgrade Account",
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      content: Text(
        isAr
            ? "لقد وصلت للحد المسموح به في الباقة الحالية.\n\nلتتمكن من إضافة المزيد من الموظفين وإدارة متجرك بلا حدود، نرجو ترقية حسابك إلى الباقة المميزة والاستمتاع بكافة المزايا! 🚀"
            : "You have reached the limit of your current plan.\n\nTo add more employees and manage your store without limits, please upgrade your account to the premium plan! 🚀",
        style:
            const TextStyle(fontFamily: 'Tajawal', height: 1.5, fontSize: 15),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isAr ? "ربما لاحقاً" : "Maybe later",
              style:
                  const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            context.push('/paywall');
          },
          child: Text(isAr ? "ترقية حسابي الآن ⭐" : "Upgrade now ⭐",
              style: const TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _merchantUid = FirebaseAuth.instance.currentUser?.uid;
  final _merchantEmail =
      FirebaseAuth.instance.currentUser?.email ?? "البريد غير متوفر";
  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Colors.green),
    );
  }

  void _shareCredentials(BuildContext context, String empName, String pin) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final text = isAr
        ? '''
مرحباً $empName،
تم إنشاء حساب موظف لك في تطبيق تاجر.
يرجى تحميل التطبيق، ثم اختيار "دخول موظف (بالرمز)".

الإيميل الخاص بالمتجر: $_merchantEmail
رمز الدخول الخاص بك (PIN): $pin

لا تشارك هذا الرمز مع أحد!
'''
        : '''
Hello $empName,
An employee account has been created for you in Tajer app.
Please download the app, then select "Employee Login (PIN)".

Store Email: $_merchantEmail
Your PIN: $pin

Do not share this PIN with anyone!
''';
    Share.share(text);
  }

  void _showAddEmployeeDialog(int currentCount, String selectedBranchId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmployeeDialog(
        merchantEmail: _merchantEmail,
        ref: ref,
        selectedBranchId: selectedBranchId,
      ),
    );
  }

  void _showEditEmployeeDialog(String id, Map<String, dynamic> data) {
    context.push('/employee_permissions');
  }

  void _deleteEmployee(String id) async {
    final appUser = ref.read(appUserProvider).value;
    if (appUser != null) {
      if (!mounted) return;
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      final success = await PinConfirmationDialog.requirePinOrSetup(
        context,
        appUser,
        title: isAr ? 'تحذير: طرد موظف' : 'Warning: Fire employee',
        warning: isAr
            ? 'حذف الموظف سيمنعه فوراً من الدخول للنظام. لا يمكن التراجع عن هذا الإجراء.'
            : 'Deleting the employee will immediately prevent them from accessing the system. This action cannot be undone.',
      );
      if (!success) return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).deleteEmployee(id);
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAr ? "تم حذف الموظف" : "Employee deleted",
                style: const TextStyle(fontFamily: 'Tajawal'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", ""),
                style: const TextStyle(fontFamily: 'Tajawal'))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_merchantUid == null) {
      return Scaffold(
          body: Center(
              child: Text(isAr
                  ? "يجب تسجيل الدخول كتاجر"
                  : "You must login as a merchant")));
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final selectedBranchId = ref.watch(selectedBranchIdProvider);
    final allOrders = ordersAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? "إدارة الموظفين والأداء" : "Employees & Performance",
            style: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_merchantUid)
                  .collection('employees')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final assigned = data['assignedBranchIds'] as List<dynamic>? ?? [];
                  return assigned.contains(selectedBranchId);
                }).toList();
                final currentCount = docs.length;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Instructions Card
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                      isAr
                                          ? 'معلومات عن إضافة الموظفين'
                                          : 'Employee Addition Info',
                                      style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isAr
                                    ? "1. يمكنك إضافة حد أقصى 3 موظفين.\n2. عندما يحمل الموظف التطبيق، يجب أن يختار (دخول موظف بالرمز).\n3. سيطلب منه التطبيق إدخال إيميلك الأساسي ورمز الدخول الذي أنشأته له."
                                    : "1. You can add a maximum of 3 employees.\n2. When the employee downloads the app, they must select (Employee Login by PIN).\n3. The app will ask them to enter your primary email and the PIN you created.",
                                style: const TextStyle(
                                    fontFamily: 'Tajawal', height: 1.5),
                              ),
                              const Divider(height: 24),
                              Text(
                                  isAr
                                      ? "إيميلك الأساسي (الذي يجب أن يكتبه الموظف):"
                                      : "Your primary email (employee must enter this):",
                                  style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.5)),
                                ),
                                child: Text(_merchantEmail,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              isAr
                                  ? "قائمة الموظفين لهذا الفرع ($currentCount)"
                                  : "Employees List for this branch ($currentCount)",
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showAddEmployeeDialog(currentCount, selectedBranchId),
                            icon: const Icon(Icons.person_add, size: 20),
                            label: Text(isAr ? "إضافة" : "Add",
                                style: const TextStyle(fontFamily: 'Tajawal')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // List
                      Expanded(
                        child: docs.isEmpty
                            ? Center(
                                child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                      isAr
                                          ? "لا يوجد موظفين حالياً"
                                          : "No employees currently",
                                      style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          color: Colors.grey[600],
                                          fontSize: 16)),
                                ],
                              ))
                            : ListView.separated(
                                itemCount: currentCount,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final data = docs[index].data()
                                      as Map<String, dynamic>;
                                  final id = docs[index].id;
                                  final name = data['name'] ??
                                      (isAr ? 'بدون اسم' : 'Unnamed');
                                  final pin = data['pin'] ?? '****';

                                  final employeeOrders = allOrders
                                      .where((o) => o.creatorId == id)
                                      .toList();
                                  final totalSales =
                                      employeeOrders.fold<double>(
                                          0, (sum, o) => sum + o.total);

                                  return ListTile(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EmployeeActivityScreen(
                                            employeeId: id,
                                            employeeName: name,
                                          ),
                                        ),
                                      );
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(Icons.history,
                                          color: theme.colorScheme.primary),
                                    ),
                                    title: Text(name,
                                        style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            isAr
                                                ? "رمز الدخول: $pin"
                                                : "PIN: $pin",
                                            style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          isAr
                                              ? "المبيعات: $totalSales ${currentCurrency.code}"
                                              : "Sales: $totalSales ${currentCurrency.code}",
                                          style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700]),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.share,
                                              color: Colors.green),
                                          tooltip: isAr
                                              ? "مشاركة بيانات الدخول (واتساب)"
                                              : "Share credentials (WhatsApp)",
                                          onPressed: () => _shareCredentials(
                                              context, name, pin),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          tooltip: isAr
                                              ? "تعديل الصلاحيات"
                                              : "Edit permissions",
                                          onPressed: () =>
                                              _showEditEmployeeDialog(id, data),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          tooltip: isAr
                                              ? "حذف الموظف"
                                              : "Delete employee",
                                          onPressed: () => _deleteEmployee(id),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class EmployeeDialog extends StatefulWidget {
  final String merchantEmail;
  final WidgetRef ref;
  final Map<String, dynamic>? initialData;
  final String? employeeUid;
  final String selectedBranchId;

  const EmployeeDialog({
    super.key,
    required this.merchantEmail,
    required this.ref,
    required this.selectedBranchId,
    this.initialData,
    this.employeeUid,
  });

  @override
  State<EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<EmployeeDialog> {
  final nameController = TextEditingController();
  final pinController = TextEditingController();
  bool isSaving = false;

  Map<String, String> _getPermissionLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return {
      'can_manage_products': l10n.permCanManageProducts,
      'can_view_cost': l10n.permCanViewCost,
      'can_manage_inventory': l10n.permCanManageInventory,
      'can_create_orders': l10n.permCanCreateOrders,
      'can_cancel_orders': l10n.permCanCancelOrders,
      'can_sell_on_credit': l10n.permCanSellOnCredit,
      'can_manage_customers': l10n.permCanManageCustomers,
      'can_receive_payments': l10n.permCanReceivePayments,
      'can_manage_expenses': l10n.permCanManageExpenses,
      'can_view_reports':
          isAr ? 'السماح برؤية قسم التقارير' : 'Allow viewing reports',
      'can_view_all_orders':
          isAr ? 'السماح برؤية جميع الطلبات' : 'Allow viewing all orders',
    };
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      nameController.text = widget.initialData!['name'] ?? '';
      pinController.text = widget.initialData!['pin'] ?? '';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employeeUid != null;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(
          isEdit
              ? (isAr
                  ? "تعديل الموظف والصلاحيات"
                  : "Edit Employee & Permissions")
              : (isAr ? "إضافة موظف جديد" : "Add New Employee"),
          style: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: isAr ? "اسم الموظف" : "Employee Name",
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                readOnly: isEdit,
                decoration: InputDecoration(
                    labelText: isAr ? "رمز الدخول (6 أرقام)" : "PIN (6 digits)",
                    prefixIcon: const Icon(Icons.pin),
                    border: const OutlineInputBorder(),
                    helperText: isEdit
                        ? (isAr
                            ? "لا يمكن تعديل رمز الدخول بعد الحفظ"
                            : "PIN cannot be edited after save")
                        : (isAr
                            ? "مثال: 123456 (باسورد الموظف)"
                            : "e.g., 123456 (Employee Password)"),
                    helperStyle: const TextStyle(fontFamily: 'Tajawal')),
              ),
              const Divider(height: 32),
              Text(
                  isAr
                      ? '\u0635\u0644\u0627\u062d\u064a\u0627\u062a \u0627\u0644\u0645\u0648\u0638\u0641:'
                      : 'Employee permissions:',
                  style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? '\u064a\u062a\u0645 \u062a\u062d\u062f\u064a\u062f \u0627\u0644\u0635\u0644\u0627\u062d\u064a\u0627\u062a \u0628\u0639\u062f \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0645\u0648\u0638\u0641 \u0645\u0646 \u0634\u0627\u0634\u0629 "\u0627\u0644\u0635\u0644\u0627\u062d\u064a\u0627\u062a \u0627\u0644\u0645\u062a\u0642\u062f\u0645\u0629".'
                    : 'Configure permissions after creating the employee from "Advanced Permissions".',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(isAr ? "إلغاء" : "Cancel",
              style:
                  const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: isSaving
              ? null
              : () async {
                  final name = nameController.text.trim();
                  final pin = pinController.text.trim();

                  if (name.isEmpty) {
                    _showError(isAr
                        ? "يرجى إدخال اسم الموظف"
                        : "Please enter employee name");
                    return;
                  }
                  if (pin.length < 6) {
                    _showError(isAr
                        ? "رمز الدخول يجب أن يكون 6 أرقام على الأقل"
                        : "PIN must be at least 6 digits");
                    return;
                  }

                  setState(() => isSaving = true);
                  try {
                    if (isEdit) {
                      if (mounted) Navigator.of(context).pop();
                      _showSuccess(isAr
                          ? "تم تحديث الصلاحيات بنجاح"
                          : "Permissions updated successfully");
                    } else {
                      await widget.ref
                          .read(authRepositoryProvider)
                          .createEmployee(widget.merchantEmail, name, pin,
                              permissions: EmployeePermissionCatalog
                                  .leastPrivilegeDefaults,
                              branchId: widget.selectedBranchId);
                      if (mounted) Navigator.of(context).pop();
                      _showSuccess(isAr
                          ? "تم إضافة الموظف بنجاح"
                          : "Employee added successfully");
                    }
                  } catch (e) {
                    final errorMsg = e.toString().replaceAll("Exception: ", "");
                    if (errorMsg.contains("الباقة الشهرية") ||
                        errorMsg.contains("حد") ||
                        errorMsg.contains("تفعيل") ||
                        errorMsg.contains("limit")) {
                      if (mounted) Navigator.of(context).pop();
                      showBeautifulUpgradeDialog(context);
                    } else {
                      _showError(errorMsg);
                    }
                  } finally {
                    if (mounted) setState(() => isSaving = false);
                  }
                },
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  isEdit
                      ? (isAr ? "حفظ التعديلات" : "Save Changes")
                      : (isAr ? "إضافة" : "Add"),
                  style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ],
    );
  }
}
