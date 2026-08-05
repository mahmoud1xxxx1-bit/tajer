import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/data/auth_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/providers/settings_provider.dart';
import 'employee_activity_screen.dart';

void showBeautifulUpgradeDialog(BuildContext context) {
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
            child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            "ترقية الحساب",
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      content: const Text(
        "لقد وصلت للحد المسموح به في الباقة الحالية.\n\nلتتمكن من إضافة المزيد من الموظفين وإدارة متجرك بلا حدود، نرجو ترقية حسابك إلى الباقة المميزة والاستمتاع بكافة المزايا! 🚀",
        style: TextStyle(fontFamily: 'Tajawal', height: 1.5, fontSize: 15),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("ربما لاحقاً", style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            context.push('/paywall');
          },
          child: const Text("ترقية حسابي الآن ⭐", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
  final _merchantEmail = FirebaseAuth.instance.currentUser?.email ?? "البريد غير متوفر";
  bool _isLoading = false;

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

  void _shareCredentials(String empName, String pin) {
    final text = '''
مرحباً $empName،
تم إنشاء حساب موظف لك في تطبيق تاجر.
يرجى تحميل التطبيق، ثم اختيار "دخول موظف (بالرمز)".

الإيميل الخاص بالمتجر: $_merchantEmail
رمز الدخول الخاص بك (PIN): $pin

لا تشارك هذا الرمز مع أحد!
''';
    Share.share(text);
  }

  void _showAddEmployeeDialog(int currentCount) {
    if (currentCount >= 3) {
      showBeautifulUpgradeDialog(context);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmployeeDialog(
        merchantEmail: _merchantEmail,
        ref: ref,
      ),
    );
  }

  void _showEditEmployeeDialog(String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmployeeDialog(
        merchantEmail: _merchantEmail,
        ref: ref,
        employeeUid: id,
        initialData: data,
      ),
    );
  }

  void _deleteEmployee(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف موظف", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text("هل أنت متأكد من حذف هذا الموظف؟ لن يتمكن من تسجيل الدخول بعد الآن.", style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("حذف نهائياً", style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      final appUser = ref.read(appUserProvider).value;
      if (appUser != null) {
        final pin = await PinService.getDeletePin(appUser);
        if (pin != null) {
          if (!mounted) return;
          final success = await PinConfirmationDialog.show(context, pin);
          if (!success) return;
        }
      }
      setState(() => _isLoading = true);
      try {
        await ref.read(authRepositoryProvider).deleteEmployee(id);
        _showSuccess("تم حذف الموظف");
      } catch (e) {
        _showError(e.toString().replaceAll("Exception: ", ""));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_merchantUid == null) {
      return const Scaffold(body: Center(child: Text("يجب تسجيل الدخول كتاجر")));
    }

    final theme = Theme.of(context);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final allOrders = ordersAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة الموظفين والأداء", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(_merchantUid).collection('employees').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final currentCount = docs.length;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instructions Card
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text("تعليمات هامة للتاجر", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "1. يمكنك إضافة حد أقصى 3 موظفين.\n"
                              "2. عندما يحمل الموظف التطبيق، يجب أن يختار (دخول موظف بالرمز).\n"
                              "3. سيطلب منه التطبيق إدخال إيميلك الأساسي ورمز الدخول الذي أنشأته له.",
                              style: TextStyle(fontFamily: 'Tajawal', height: 1.5),
                            ),
                            const Divider(height: 24),
                            const Text("إيميلك الأساسي (الذي يجب أن يكتبه الموظف):", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300)
                              ),
                              child: Text(_merchantEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
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
                        Text("قائمة الموظفين ($currentCount/3)", style: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: () => _showAddEmployeeDialog(currentCount),
                          icon: const Icon(Icons.person_add, size: 20),
                          label: const Text("إضافة", style: TextStyle(fontFamily: 'Tajawal')),
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
                                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text("لا يوجد موظفين حالياً", style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[600], fontSize: 16)),
                              ],
                            )
                          )
                        : ListView.separated(
                            itemCount: currentCount,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final id = docs[index].id;
                              final name = data['name'] ?? 'بدون اسم';
                              final pin = data['pin'] ?? '****';

                              final employeeOrders = allOrders.where((o) => o.creatorId == id).toList();
                              final totalSales = employeeOrders.fold<double>(0, (sum, o) => sum + o.total);

                              return ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmployeeActivityScreen(
                                        employeeId: id,
                                        employeeName: name,
                                      ),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Icon(Icons.history, color: theme.colorScheme.primary),
                                ),
                                title: Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("رمز الدخول: $pin", style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "المبيعات: $totalSales ${currentCurrency.code}",
                                      style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.green[700]),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.green),
                                      tooltip: "مشاركة بيانات الدخول (واتساب)",
                                      onPressed: () => _shareCredentials(name, pin),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: "تعديل الصلاحيات",
                                      onPressed: () => _showEditEmployeeDialog(id, data),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: "حذف الموظف",
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

  const EmployeeDialog({
    super.key,
    required this.merchantEmail,
    required this.ref,
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

  Map<String, bool> permissions = {
    'can_manage_products': false,
    'can_view_cost': false,
    'can_manage_inventory': false,
    'can_create_orders': true,
    'can_cancel_orders': false,
    'can_sell_on_credit': false,
    'can_manage_customers': true,
    'can_receive_payments': true,
    'can_manage_expenses': false,
    'can_view_reports': true,
    'can_view_all_orders': true,
  };

  Map<String, String> _getPermissionLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
      'can_view_reports': 'السماح برؤية قسم التقارير',
      'can_view_all_orders': 'السماح برؤية جميع الطلبات',
    };
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      nameController.text = widget.initialData!['name'] ?? '';
      pinController.text = widget.initialData!['pin'] ?? '';
      if (widget.initialData!['permissions'] != null) {
        final Map<String, dynamic> perms = widget.initialData!['permissions'];
        permissions.forEach((key, value) {
          if (perms.containsKey(key)) {
            permissions[key] = perms[key] == true;
          }
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employeeUid != null;
    return AlertDialog(
      title: Text(isEdit ? "تعديل الموظف والصلاحيات" : "إضافة موظف جديد", style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "اسم الموظف",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                readOnly: isEdit,
                decoration: InputDecoration(
                  labelText: "رمز الدخول (6 أرقام)",
                  prefixIcon: const Icon(Icons.pin),
                  border: const OutlineInputBorder(),
                  helperText: isEdit ? "لا يمكن تعديل رمز الدخول بعد الحفظ" : "مثال: 123456 (باسورد الموظف)",
                  helperStyle: const TextStyle(fontFamily: 'Tajawal')
                ),
              ),
              const Divider(height: 32),
              const Text("صلاحيات الموظف:", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...permissions.keys.map((key) {
                final labels = _getPermissionLabels(context);
                return SwitchListTile(
                  title: Text(labels[key] ?? key, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                  value: permissions[key]!,
                  onChanged: (val) {
                    setState(() {
                      permissions[key] = val;
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text("إلغاء", style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : () async {
            final name = nameController.text.trim();
            final pin = pinController.text.trim();

            if (name.isEmpty) {
              _showError("يرجى إدخال اسم الموظف");
              return;
            }
            if (pin.length < 6) {
              _showError("رمز الدخول يجب أن يكون 6 أرقام على الأقل");
              return;
            }

            setState(() => isSaving = true);
            try {
              if (isEdit) {
                await widget.ref.read(authRepositoryProvider).updateEmployeePermissions(widget.employeeUid!, permissions);
                if (mounted) Navigator.of(context).pop();
                _showSuccess("تم تحديث الصلاحيات بنجاح");
              } else {
                await widget.ref.read(authRepositoryProvider).createEmployee(widget.merchantEmail, name, pin, permissions: permissions);
                if (mounted) Navigator.of(context).pop();
                _showSuccess("تم إضافة الموظف بنجاح");
              }
            } catch (e) {
              final errorMsg = e.toString().replaceAll("Exception: ", "");
              if (errorMsg.contains("الباقة الشهرية") || errorMsg.contains("حد") || errorMsg.contains("تفعيل") || errorMsg.contains("limit")) {
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
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(isEdit ? "حفظ التعديلات" : "إضافة", style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ],
    );
  }
}
