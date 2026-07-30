with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.strip() == 'dependencies:':
        lines.insert(i+1, '  wakelock_plus: ^1.2.8\n')
        break

with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Added wakelock_plus')
