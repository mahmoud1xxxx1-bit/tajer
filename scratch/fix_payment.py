import os

def replace_in_file(path, from_str, to_str):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if from_str in content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content.replace(from_str, to_str))

payment_path = 'lib/features/accounting_notebook/presentation/notebook_payment_screen.dart'
replace_in_file(payment_path,
'''          if (accounts.isEmpty) {
            return Center(child: Text(l10n.notebookAccountsCreateFirst));
          }''',
'''          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyAccounts, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/accounts'),
                    child: Text(l10n.notebookCreateAccountCTA),
                  )
                ],
              ),
            );
          }''')

replace_in_file(payment_path,
'''              if (books.isEmpty) {
                return Center(child: Text(l10n.notebookCreateBookFirst));
              }''',
'''              if (books.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/notebook/books'),
                        child: Text(l10n.notebookCreateBookCTA),
                      )
                    ],
                  ),
                );
              }''')

replace_in_file(payment_path,
'''                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _amountController.clear();
                                  },
                                  child: Text(l10n.notebookPartialPayment ),
                                ),
                              ),''',
'''                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _amountController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.notebookPartialPaymentHint)));
                                  },
                                  child: Text(l10n.notebookPartialPayment ),
                                ),
                              ),''')

replace_in_file(payment_path,
'''                              if (double.parse(val) > maxAmount) return l10n.notebookAmountExceedsDebt;''',
'''                              if (double.parse(val) > maxAmount) return l10n.notebookOverpaymentError;''')

transfer_path = 'lib/features/accounting_notebook/presentation/notebook_transfer_screen.dart'

replace_in_file(transfer_path,
'''          if (accounts.isEmpty) {
            return Center(child: Text(l10n.notebookAccountsCreateFirst));
          }''',
'''          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyAccounts, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/accounts'),
                    child: Text(l10n.notebookCreateAccountCTA),
                  )
                ],
              ),
            );
          }''')

replace_in_file(transfer_path,
'''              if (books.isEmpty) {
                return Center(child: Text(l10n.notebookNoData));
              }''',
'''              if (books.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/notebook/books'),
                        child: Text(l10n.notebookCreateBookCTA),
                      )
                    ],
                  ),
                );
              }''')

replace_in_file(transfer_path,
'''                                  if (fromId == toId) return l10n.notebookInvalidAmount;''',
'''                                  if (fromId == toId) return l10n.notebookSameAccountError;''')
