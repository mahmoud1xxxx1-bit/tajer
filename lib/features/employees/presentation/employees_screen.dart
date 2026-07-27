import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/employee_repository.dart';
import '../domain/employee.dart';
import '../../../core/theme/glass_card.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_5a835a, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showEmployeeDialog(context, ref, null);
        },
        icon: Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.text_0deab6, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: employeesAsync.when(
        data: (employees) {
          if (employees.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text_552d4f, style: TextStyle(fontFamily: 'Tajawal')));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
              return GlassCard(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(emp.name, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  subtitle: Text(emp.role == 'cashier' ? AppLocalizations.of(context)!.text_ce360b : AppLocalizations.of(context)!.text_c9ff42, style: TextStyle(fontFamily: 'Tajawal')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEmployeeDialog(context, ref, emp),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteEmployee(context, ref, emp.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  void _deleteEmployee(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.text_8a58d1, style: TextStyle(fontFamily: 'Tajawal')),
        content: Text(AppLocalizations.of(context)!.text_91f0a4, style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.text_b9568e, style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(employeeRepositoryProvider)?.deleteEmployee(id);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.text_3b9854, style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEmployeeDialog(BuildContext context, WidgetRef ref, Employee? employee) {
    final nameController = TextEditingController(text: employee?.name);
    final emailController = TextEditingController(text: employee?.email);
    final passwordController = TextEditingController();
    String selectedRole = employee?.role ?? 'cashier';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(employee == null ? AppLocalizations.of(context)!.text_0deab6 : AppLocalizations.of(context)!.text_80bd1c, style: TextStyle(fontFamily: 'Tajawal')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
                    style: TextStyle(fontFamily: 'Tajawal'),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontFamily: 'Tajawal'),
                    enabled: employee == null, // Cannot change email after creation
                  ),
                  if (employee == null) ...[
                    SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder()),
                      obscureText: true,
                      style: TextStyle(fontFamily: 'Tajawal'),
                    ),
                  ],
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(labelText: 'الصلاحية', border: OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'admin', child: Text('مدير', style: TextStyle(fontFamily: 'Tajawal'))),
                      DropdownMenuItem(value: 'cashier', child: Text('كاشير', style: TextStyle(fontFamily: 'Tajawal'))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  final password = passwordController.text;
                  if (name.isEmpty || email.isEmpty) return;
                  if (employee == null && password.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')));
                    return;
                  }

                  final newEmployee = Employee(
                    id: employee?.id ?? const Uuid().v4(),
                    name: name,
                    email: email,
                    role: selectedRole,
                    createdAt: employee?.createdAt ?? DateTime.now(),
                  );

                  if (employee == null) {
                    ref.read(employeeRepositoryProvider)?.addEmployee(newEmployee, password);
                  } else {
                    ref.read(employeeRepositoryProvider)?.updateEmployee(newEmployee);
                  }
                  Navigator.pop(context);
                },
                child: Text('حفظ', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          );
        }
      ),
    );
  }
}
