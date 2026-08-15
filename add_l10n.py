import json
import os

ar_path = r"C:\Users\loved\gamex1\tajer\lib\l10n\app_ar.arb"
en_path = r"C:\Users\loved\gamex1\tajer\lib\l10n\app_en.arb"

ar_keys = {
    "notebookGuideBooks": "💡 دليل الدفاتر: قم بإنشاء دفتر لكل فرع أو نشاط (مثال: بوفية، كافتيريا).",
    "notebookGuideAccounts": "💡 دليل الحسابات: أضف صناديق الكاش أو الحسابات البنكية لهذا الدفتر لضبط الأرصدة.",
    "notebookGuidePeople": "💡 دليل الأشخاص: أضف العملاء أو الموردين أو الموظفين لتسجيل ديونهم أو ما لهم.",
    "notebookGuideCategories": "💡 دليل التصنيفات: أضف بنود المصروفات أو الإيرادات (مثال: رواتب، مشتريات) لتنظيم التقارير.",
    "notebookGuideTransactions": "💡 سجل الحركات: يعرض جميع عمليات الدفتر الحالي بالتاريخ والمبلغ والحساب.",
    "notebookInsufficientBalance": "الرصيد غير كافٍ.",
    "notebookArchived": "مؤرشف",
    "notebookRestore": "استرجاع",
    "notebookArchiveWarning": "هل أنت متأكد من أرشفة هذا العنصر؟ لن تتمكن من إجراء عمليات جديدة عليه. سيتطلب تأكيد أمان.",
    "notebookTypeCash": "نقدي",
    "notebookTypeBank": "بنك",
    "notebookTypeWallet": "محفظة",
    "notebookTypeCard": "بطاقة",
    "notebookTypeOther": "أخرى",
    "notebookOpeningBalanceTitle": "رصيد افتتاحي",
}

en_keys = {
    "notebookGuideBooks": "💡 Books Guide: Create a book for each branch or activity (e.g. Branch A, Delivery).",
    "notebookGuideAccounts": "💡 Accounts Guide: Add cash boxes or bank accounts to track your balances.",
    "notebookGuidePeople": "💡 People Guide: Add customers, suppliers, or employees to track debts.",
    "notebookGuideCategories": "💡 Categories Guide: Add expense or income categories (e.g. Salaries, Utilities) for reports.",
    "notebookGuideTransactions": "💡 Transactions Guide: View all operations for the selected book with date and amount.",
    "notebookInsufficientBalance": "Insufficient balance.",
    "notebookArchived": "Archived",
    "notebookRestore": "Restore",
    "notebookArchiveWarning": "Are you sure you want to archive this item? You won't be able to use it in new operations. Requires security PIN.",
    "notebookTypeCash": "Cash",
    "notebookTypeBank": "Bank",
    "notebookTypeWallet": "Wallet",
    "notebookTypeCard": "Card",
    "notebookTypeOther": "Other",
    "notebookOpeningBalanceTitle": "Opening Balance",
}

def update_arb(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    data.update(new_keys)
    
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

update_arb(ar_path, ar_keys)
update_arb(en_path, en_keys)
