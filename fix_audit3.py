import re

file = 'lib/features/settings/presentation/audit_log_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the signature
content = re.sub(
    r"Widget _buildLogItem\(AuditLogItem item, ThemeData theme, String currency, bool isAr\)",
    "Widget _buildLogItem(AuditLogItem item, ThemeData theme, dynamic currency, bool isAr)",
    content
)

# Replace the text mapping
content = content.replace("'\ \'", "'\ \'")

with open(file, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done audit again!')
