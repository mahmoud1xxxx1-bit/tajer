with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Find the build method
build_pattern = r'Widget build\(BuildContext context\) \{.*?(?=final List<Widget> screens = \[)'
# We know appUserProvider is available because it's in DashboardScreen
# Wait, is ppUserProvider read in _DashboardScreenState? Let's check.
