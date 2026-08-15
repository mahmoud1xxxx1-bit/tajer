import json

def update_arb(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
    d.update(new_keys)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, ensure_ascii=False, indent=2)

ar_keys = {
  "notebookAccountTypeCash": "صندوق",
  "notebookAccountTypeBank": "بنك",
  "notebookAccountTypeCustody": "عهدة"
}

en_keys = {
  "notebookAccountTypeCash": "Cash",
  "notebookAccountTypeBank": "Bank",
  "notebookAccountTypeCustody": "Custody"
}

update_arb('lib/l10n/app_ar.arb', ar_keys)
update_arb('lib/l10n/app_en.arb', en_keys)
