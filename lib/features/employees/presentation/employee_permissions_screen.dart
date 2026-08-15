import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../authentication/data/auth_repository.dart';

class EmployeePermissionsScreen extends ConsumerStatefulWidget {
  final String employeeUid;
  final Map<String, dynamic> initialData;

  const EmployeePermissionsScreen({
    super.key,
    required this.employeeUid,
    required this.initialData,
  });

  @override
  ConsumerState<EmployeePermissionsScreen> createState() => _EmployeePermissionsScreenState();
}

class _EmployeePermissionsScreenState extends ConsumerState<EmployeePermissionsScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;
  late Map<String, bool> _permissions;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialData['name'] ?? '';
    _permissions = {
      'can_manage_products': false,
      'can_view_cost': false,
      'can_manage_inventory': false,
      'can_create_orders': false,
      'can_cancel_orders': false,
      'can_sell_on_credit': false,
      'can_manage_customers': false,
      'can_receive_payments': false,
      'can_manage_expenses': false,
      'can_view_reports': false,
      'can_view_all_orders': false,
      'can_access_accounting_notebook': false,
    };

    if (widget.initialData['permissions'] != null) {
      final Map<String, dynamic> perms = widget.initialData['permissions'];
      _permissions.forEach((key, value) {
        if (perms.containsKey(key)) {
          _permissions[key] = perms[key] == true;
        }
      });
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

  Map<String, String> _getPermissionLabels(BuildContext context, bool isAr) {
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
      'can_view_reports': isAr ? 'السماح برؤية قسم التقارير' : 'Allow viewing reports',
      'can_view_all_orders': isAr ? 'السماح برؤية جميع الطلبات' : 'Allow viewing all orders',
      'can_access_accounting_notebook': l10n.permCanAccessAccountingNotebook,
    };
  }

  Map<String, String> _getPermissionDescriptions(BuildContext context, bool isAr) {
    final l10n = AppLocalizations.of(context)!;
    return {
      'can_manage_products': isAr ? 'يتيح للموظف إضافة، تعديل، أو حذف المنتجات والأصناف من المتجر.' : 'Allows the employee to add, edit, or delete products and categories.',
      'can_view_cost': isAr ? 'يتيح للموظف رؤية سعر التكلفة والأرباح الخاصة بالمنتجات والطلبات.' : 'Allows the employee to view cost price and profits for products and orders.',
      'can_manage_inventory': isAr ? 'يتيح للموظف إجراء عمليات جرد للمخزون وإدارة المواد الخام والموردين.' : 'Allows the employee to perform inventory checks and manage raw materials.',
      'can_create_orders': isAr ? 'يتيح للموظف الدخول إلى واجهة الكاشير وإنشاء طلبات أو فواتير جديدة.' : 'Allows the employee to access the POS and create new orders or invoices.',
      'can_cancel_orders': isAr ? 'يتيح للموظف تعديل أو إلغاء الطلبات بعد إنشائها.' : 'Allows the employee to edit or cancel orders after they are created.',
      'can_sell_on_credit': isAr ? 'يتيح للموظف بيع المنتجات وتسجيلها كدين (آجل) على العملاء.' : 'Allows the employee to sell products on credit to customers.',
      'can_manage_customers': isAr ? 'يتيح للموظف إضافة عملاء جدد وتعديل بياناتهم.' : 'Allows the employee to add new customers and edit their details.',
      'can_receive_payments': isAr ? 'يتيح للموظف استلام وتدوين الدفعات من ديون العملاء.' : 'Allows the employee to receive and record payments for customer debts.',
      'can_manage_expenses': isAr ? 'يتيح للموظف تسجيل وإدارة المصروفات اليومية للمتجر.' : 'Allows the employee to record and manage daily store expenses.',
      'can_view_reports': isAr ? 'يتيح للموظف رؤية الإحصائيات العامة للمتجر، المبيعات والمصروفات.' : 'Allows the employee to view general store statistics, sales, and expenses.',
      'can_view_all_orders': isAr ? 'يتيح للموظف رؤية جميع الطلبات القديمة للمتجر (إذا كان معطلاً سيرى طلبات آخر 7 أيام فقط).' : 'Allows the employee to view all old orders (if disabled, they only see the last 7 days).',
      'can_access_accounting_notebook': l10n.permCanAccessAccountingNotebookDesc,
    };
  }
  
  Map<String, bool> _getPermissionRisks() {
    return {
      'can_view_cost': true,
      'can_manage_inventory': true,
      'can_cancel_orders': true,
      'can_sell_on_credit': true,
      'can_manage_expenses': true,
      'can_view_reports': true,
      'can_access_accounting_notebook': true,
    };
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authRepositoryProvider).updateEmployeePermissions(widget.employeeUid, _permissions);
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      _showSuccess(isAr ? "تم حفظ الصلاحيات بنجاح" : "Permissions saved successfully");
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final labels = _getPermissionLabels(context, isAr);
    final descriptions = _getPermissionDescriptions(context, isAr);
    final risks = _getPermissionRisks();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primaryContainer,
        title: Text(isAr ? "صلاحيات الموظف" : "Employee Permissions", style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: Text(isAr ? "حفظ" : "Save", style: TextStyle(fontFamily: 'Tajawal', color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.initialData['name'] ?? '', style: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${isAr ? "رمز الدخول:" : "PIN:"} ${widget.initialData['pin']}', style: TextStyle(fontFamily: 'Tajawal', color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _permissions.keys.length,
              itemBuilder: (context, index) {
                final key = _permissions.keys.elementAt(index);
                final isRisky = risks[key] ?? false;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(
                      color: isRisky ? Colors.orange.withValues(alpha: 0.5) : (isDark ? Colors.white12 : Colors.grey.shade200),
                      width: 1,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        if (isRisky) ...[
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            labels[key] ?? key, 
                            style: TextStyle(
                              fontFamily: 'Tajawal', 
                              fontSize: 16, 
                              fontWeight: FontWeight.bold, 
                              color: isRisky ? Colors.orange : theme.colorScheme.onSurface
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        descriptions[key] ?? '', 
                        style: TextStyle(
                          fontFamily: 'Tajawal', 
                          fontSize: 13, 
                          height: 1.5, 
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600
                        ),
                      ),
                    ),
                    value: _permissions[key]!,
                    activeColor: isRisky ? Colors.orange : theme.colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _permissions[key] = val;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
