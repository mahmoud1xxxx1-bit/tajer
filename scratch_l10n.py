import json
import os

ar_path = 'lib/l10n/app_ar.arb'
en_path = 'lib/l10n/app_en.arb'

def add_keys(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    for k, v in new_keys.items():
        data[k] = v
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

ar_keys = {
    "notebookGuideAccounts": "الحساب هو المكان الذي تحتفظ فيه بالمال، مثل: الصندوق أو البنك.",
    "notebookGuidePeople": "الأشخاص هم العملاء أو الموردون الذين تتعامل معهم بالآجل (دين).",
    "notebookGuideCategories": "التصنيفات تساعدك في ترتيب وتنظيم حركاتك المالية مثل (رواتب، إيجار، مبيعات).",
    "notebookGuideIncomeExpense": "الدخل هو أي مبلغ يدخل لحسابك. المصروف هو أي مبلغ يخرج من حسابك.",
    "notebookGuideReceivablePayable": "لي: مبالغ تطالب بها الآخرين. عليّ: مبالغ يطالبك بها الآخرون.",
    "notebookGuideTransferPayment": "التحويل لنقل المال بين حساباتك. السداد لتسديد الديون للأشخاص.",
    "notebookArchived": "مؤرشف",
    "notebookRestore": "استرجاع",
    "notebookInsufficientBalance": "الرصيد غير كافٍ. الرصيد الحالي: {balance} والمطلوب: {amount}"
}

en_keys = {
    "notebookGuideAccounts": "An account is where you keep money, like: Cash or Bank.",
    "notebookGuidePeople": "People are customers or suppliers you deal with on credit.",
    "notebookGuideCategories": "Categories help you organize your financial transactions like (Salaries, Rent, Sales).",
    "notebookGuideIncomeExpense": "Income is any money entering your account. Expense is any money leaving.",
    "notebookGuideReceivablePayable": "Owed to me: Money you claim from others. I owe: Money others claim from you.",
    "notebookGuideTransferPayment": "Transfer moves money between your accounts. Payment settles debts with people.",
    "notebookArchived": "Archived",
    "notebookRestore": "Restore",
    "notebookInsufficientBalance": "Insufficient balance. Current balance: {balance}, Required: {amount}"
}

add_keys(ar_path, ar_keys)
add_keys(en_path, en_keys)
print("Localization keys added.")
