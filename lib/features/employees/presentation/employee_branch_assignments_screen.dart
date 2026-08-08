import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_repository.dart';
import '../../branches/domain/branch.dart';
import '../data/employee_branch_access_repository.dart';

class EmployeeBranchAssignmentsScreen extends ConsumerWidget {
  const EmployeeBranchAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final user = ref.watch(appUserProvider).value;
    final isOwner = user?.role == 'merchant' || user?.role == 'admin';

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'فروع الموظفين' : 'Employee Branches'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr
                  ? 'هذه الصفحة متاحة للتاجر فقط.'
                  : 'This page is available to the merchant only.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final branchesAsync = ref.watch(branchesStreamProvider);
    final employeesAsync = ref.watch(employeeBranchAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تعيين الموظفين للفروع' : 'Assign Employees to Branches'),
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(isAr ? 'تعذر تحميل الفروع.' : 'Could not load branches.'),
        ),
        data: (allBranches) {
          final branches = allBranches.where((branch) => branch.isActive).toList();
          if (branches.isEmpty) {
            return Center(
              child: Text(isAr ? 'لا توجد فروع نشطة.' : 'No active branches.'),
            );
          }

          return employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(isAr
                  ? 'تعذر تحميل الموظفين.'
                  : 'Could not load employees.'),
            ),
            data: (employees) {
              if (employees.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isAr
                          ? 'لا يوجد موظفون بعد. أضف موظفًا أولاً من شاشة الموظفين والصلاحيات.'
                          : 'No employees yet. Add an employee first from Employees & Permissions.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isAr
                            ? 'حدد الفروع التي يستطيع كل موظف العمل بها. لن تسمح قواعد الأمان للموظف بقراءة أو تنفيذ عمليات في فرع غير معيّن له.'
                            : 'Choose the branches each employee can work in. Security rules block employees from reading or operating in unassigned branches.',
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...employees.map((employee) => _EmployeeAssignmentCard(
                        employee: employee,
                        branches: branches,
                        isAr: isAr,
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EmployeeAssignmentCard extends ConsumerStatefulWidget {
  final EmployeeBranchAccess employee;
  final List<Branch> branches;
  final bool isAr;

  const _EmployeeAssignmentCard({
    required this.employee,
    required this.branches,
    required this.isAr,
  });

  @override
  ConsumerState<_EmployeeAssignmentCard> createState() =>
      _EmployeeAssignmentCardState();
}

class _EmployeeAssignmentCardState
    extends ConsumerState<_EmployeeAssignmentCard> {
  late Set<String> selected;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selected = widget.employee.assignedBranchIds.toSet();
    selected.removeWhere(
      (id) => !widget.branches.any((branch) => branch.id == id),
    );
    if (selected.isEmpty && widget.branches.isNotEmpty) {
      final main = widget.branches.where((branch) => branch.isMain).toList();
      selected.add(main.isNotEmpty ? main.first.id : widget.branches.first.id);
    }
  }

  @override
  void didUpdateWidget(covariant _EmployeeAssignmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee.assignedBranchIds.join('|') !=
        widget.employee.assignedBranchIds.join('|')) {
      selected = widget.employee.assignedBranchIds.toSet();
    }
  }

  Future<void> _save() async {
    if (selected.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final repository = ref.read(employeeBranchAccessRepositoryProvider);
      if (repository == null) throw StateError('Employee repository unavailable');
      await repository.updateAssignedBranches(
        employeeId: widget.employee.employeeId,
        branchIds: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr
              ? 'تم تحديث فروع الموظف بنجاح.'
              : 'Employee branches updated successfully.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr
              ? 'تعذر تحديث الفروع. تحقق من أن الفروع نشطة وحاول مجددًا.'
              : 'Could not update branches. Verify active branches and try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_rounded)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.isAr ? 'الفروع المسموحة' : 'Allowed branches',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            ...widget.branches.map((branch) {
              final checked = selected.contains(branch.id);
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: checked,
                title: Text(branch.name),
                subtitle: branch.isMain
                    ? Text(widget.isAr ? 'الفرع الرئيسي' : 'Main branch')
                    : null,
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(branch.id);
                          } else if (selected.length > 1) {
                            selected.remove(branch.id);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(widget.isAr
                                    ? 'يجب أن يبقى فرع واحد على الأقل.'
                                    : 'At least one branch must remain assigned.'),
                              ),
                            );
                          }
                        });
                      },
              );
            }),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(widget.isAr ? 'حفظ الفروع' : 'Save branches'),
            ),
          ],
        ),
      ),
    );
  }
}
