import os

def replace_in_file(path, from_str, to_str):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if from_str in content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content.replace(from_str, to_str))

# 1. Income/Expense Screen
income_expense_path = 'lib/features/accounting_notebook/presentation/income_expense_screen.dart'
replace_in_file(income_expense_path,
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

replace_in_file(income_expense_path,
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

replace_in_file(income_expense_path,
'''                  if (cats.isEmpty) {
                    return Center(child: Text(l10n.notebookNoData));
                  }''',
'''                  if (cats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.notebookNoCategoriesFound, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push('/notebook/categories'),
                            child: Text(l10n.add),
                          )
                        ],
                      ),
                    );
                  }''')

replace_in_file(income_expense_path,
'''                          DropdownButtonFormField<String>(initialValue: _selectedBookId,''',
'''                          Text(widget.isIncome ? l10n.notebookIncomeHint : l10n.notebookExpenseHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(initialValue: _selectedBookId,''')

# 2. Debt Screen
debt_path = 'lib/features/accounting_notebook/presentation/debt_screen.dart'
replace_in_file(debt_path,
'''          if (people.isEmpty) {
            return Center(child: Text(l10n.notebookNoData));
          }''',
'''          if (people.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.notebookEmptyPeople, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/notebook/people'),
                    child: Text(l10n.notebookAddPersonCTA),
                  )
                ],
              ),
            );
          }''')

replace_in_file(debt_path,
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

replace_in_file(debt_path,
'''                          DropdownButtonFormField<String>(initialValue: _selectedBookId,''',
'''                          Text(widget.isOwedToMe ? l10n.notebookReceivableHint : l10n.notebookPayableHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(initialValue: _selectedBookId,''')
