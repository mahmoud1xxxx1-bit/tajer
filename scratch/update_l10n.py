import json

def add_keys(filepath, keys_dict):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for k, v in keys_dict.items():
        if k not in data:
            data[k] = v
            
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

add_keys('lib/l10n/app_ar.arb', {
    'notebookEmptyBooks': 'ابدأ بإنشاء دفتر لتنظيم حسابات نشاطك.',
    'notebookEmptyAccounts': 'يرجى إنشاء حساب مالي أولاً لتسجيل العمليات.',
    'notebookEmptyPeople': 'أضف شخصًا أولاً (عميل أو مورد) لتسجيل المبالغ.',
    'notebookCreateBookCTA': 'إنشاء دفتر',
    'notebookCreateAccountCTA': 'إنشاء حساب مالي',
    'notebookAddPersonCTA': 'إضافة شخص',
    'notebookIncomeHint': 'سجل هنا الأموال التي دخلت إلى أحد حساباتك. (مثال: مبيعات نقدية، دخل إضافي، إيداع)',
    'notebookExpenseHint': 'سجل هنا الأموال التي خرجت من أحد حساباتك. (مثال: إيجار، مشتريات، صيانة)',
    'notebookReceivableHint': 'استخدم (لي) عندما يكون لك مبلغ عند عميل أو شخص آخر.',
    'notebookPayableHint': 'استخدم (علي) عندما يكون عليك مبلغ لمورد أو شخص آخر.',
    'notebookFilterType': 'نوع الحركة',
    'notebookFilterBook': 'الدفتر',
    'notebookFilterAccount': 'الحساب',
    'notebookReceivePayment': 'استلام دفعة',
    'notebookPayPayment': 'دفع مبلغ',
    'notebookOverpaymentError': 'المبلغ المدخل أكبر من الرصيد المتبقي',
    'notebookSameAccountError': 'لا يمكن التحويل لنفس الحساب',
    'notebookPartialPaymentHint': 'المبلغ المراد سداده'
})

add_keys('lib/l10n/app_en.arb', {
    'notebookEmptyBooks': 'Start by creating a book to organize your accounts.',
    'notebookEmptyAccounts': 'Please create a financial account first to record transactions.',
    'notebookEmptyPeople': 'Add a person first (customer or supplier) to record amounts.',
    'notebookCreateBookCTA': 'Create Book',
    'notebookCreateAccountCTA': 'Create Account',
    'notebookAddPersonCTA': 'Add Person',
    'notebookIncomeHint': 'Record money entering your accounts. (e.g., cash sales, deposit)',
    'notebookExpenseHint': 'Record money leaving your accounts. (e.g., rent, purchases, maintenance)',
    'notebookReceivableHint': 'Use (Receivable) when someone owes you money.',
    'notebookPayableHint': 'Use (Payable) when you owe someone money.',
    'notebookFilterType': 'Transaction Type',
    'notebookFilterBook': 'Book',
    'notebookFilterAccount': 'Account',
    'notebookReceivePayment': 'Receive Payment',
    'notebookPayPayment': 'Pay Amount',
    'notebookOverpaymentError': 'Amount entered exceeds the remaining balance',
    'notebookSameAccountError': 'Cannot transfer to the same account',
    'notebookPartialPaymentHint': 'Amount to pay'
})
