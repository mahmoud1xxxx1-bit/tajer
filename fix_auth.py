import os
import re

file_path = 'lib/features/authentication/data/auth_repository.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r"'permissions': permissions,\s*'permissions': permissions,",
    r"'permissions': permissions,",
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed duplicate permissions')
