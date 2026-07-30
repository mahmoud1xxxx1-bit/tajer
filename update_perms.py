import re

with open('lib/features/employees/presentation/employees_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add to permissions map
content = content.replace(
    "'can_manage_expenses': false,",
    "'can_manage_expenses': false,\n    'can_view_reports': true,\n    'can_view_all_orders': true,"
)

# Add to _getPermissionLabels map
content = content.replace(
    "'can_manage_expenses': l10n.permCanManageExpenses,",
    "'can_manage_expenses': l10n.permCanManageExpenses,\n      'can_view_reports': '??? ??? ????????' if false else '??????? ??? ??? ????????',\n      'can_view_all_orders': '????? ??????? ???? 7 ????' if false else '??????? ??? ???? ???????',"
)

with open('lib/features/employees/presentation/employees_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated permissions UI')
