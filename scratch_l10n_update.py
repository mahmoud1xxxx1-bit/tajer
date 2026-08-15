import json

def update_arb(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
    d.update(new_keys)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, ensure_ascii=False, indent=2)

ar_keys = {
    "notebookReportTitle": "تقرير دفتر المحاسبة",
    "notebookDate": "التاريخ",
    "notebookType": "النوع",
    "notebookTotalIncome": "إجمالي الدخل",
    "notebookTotalExpenses": "إجمالي المصروفات",
    "notebookTransactionsHeader": "المعاملات:",
    "notebookNoData": "لا توجد بيانات",
    "notebookOpeningBalance": "رصيد افتتاحي"
}

en_keys = {
    "notebookReportTitle": "Accounting Report",
    "notebookDate": "Date",
    "notebookType": "Type",
    "notebookTotalIncome": "Total Income",
    "notebookTotalExpenses": "Total Expenses",
    "notebookTransactionsHeader": "Transactions:",
    "notebookNoData": "No data",
    "notebookOpeningBalance": "Opening Balance"
}

update_arb('lib/l10n/app_ar.arb', ar_keys)
update_arb('lib/l10n/app_en.arb', en_keys)
