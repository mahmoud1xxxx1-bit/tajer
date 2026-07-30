import re

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

pop_scope_start = '''    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('????? ??????', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
            content: Text('?? ??? ????? ??? ???? ?????? ?? ????????', style: TextStyle(fontFamily: 'Tajawal')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('?????', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                child: Text('????', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          ),
        );
        if (shouldPop ?? false) {
          import('package:flutter/services.dart').then((value) => value.SystemNavigator.pop());
        }
      },
      child: Scaffold(
'''

content = content.replace('    return Scaffold(\n', pop_scope_start)
content = content.replace('      );\n  }\n}\n\nclass DashboardHome', '      ),\n    );\n  }\n}\n\nclass DashboardHome')

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated dashboard screen")
