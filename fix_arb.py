import json

ar_file = 'lib/l10n/app_ar.arb'
with open(ar_file, 'r', encoding='utf-8') as f:
    ar_data = json.load(f)

ar_data['aboutApp'] = '?? ???????'
ar_data['databaseBackupText'] = '????? ?????????'
ar_data['thermalPrinterText'] = '??????? ????????'

with open(ar_file, 'w', encoding='utf-8') as f:
    json.dump(ar_data, f, ensure_ascii=False, indent=2)

en_file = 'lib/l10n/app_en.arb'
with open(en_file, 'r', encoding='utf-8') as f:
    en_data = json.load(f)

en_data['aboutApp'] = 'About App'
en_data['databaseBackupText'] = 'Database Backup'
en_data['thermalPrinterText'] = 'Thermal Printer'

with open(en_file, 'w', encoding='utf-8') as f:
    json.dump(en_data, f, ensure_ascii=False, indent=2)

print('ARB files fixed!')
