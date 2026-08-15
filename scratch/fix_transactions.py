import os

tx_path = 'lib/features/accounting_notebook/presentation/notebook_transactions_screen.dart'

new_filters = '''          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(l10n.notebookFilterType, style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.filter_list),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // TYPE FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedType,
                          decoration: InputDecoration(labelText: l10n.notebookFilterType, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'income', child: Text(l10n.income, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'expense', child: Text(l10n.expense, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'receivable', child: Text(l10n.moneyOwedToMe, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'payable', child: Text(l10n.moneyIOwe, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'receivable_payment', child: Text(l10n.notebookReceivePayment, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'payable_payment', child: Text(l10n.notebookPayPayment, overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'account_transfer', child: Text(l10n.notebookTransfer, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setState(() => _selectedType = val),
                        ),
                      ),
                      // BOOK FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedBookId,
                          decoration: InputDecoration(labelText: l10n.notebookFilterBook, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...booksAsync.maybeWhen(
                              data: (books) => books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )
                          ],
                          onChanged: (val) => setState(() => _selectedBookId = val),
                        ),
                      ),
                      // ACCOUNT FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedAccountId,
                          decoration: InputDecoration(labelText: l10n.notebookFilterAccount, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...accountsAsync.maybeWhen(
                              data: (accs) => accs.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )
                          ],
                          onChanged: (val) => setState(() => _selectedAccountId = val),
                        ),
                      ),
                      // PERSON FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedPersonId,
                          decoration: InputDecoration(labelText: l10n.notebookPerson, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...peopleAsync.maybeWhen(
                              data: (pep) => pep.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )
                          ],
                          onChanged: (val) => setState(() => _selectedPersonId = val),
                        ),
                      ),
                      // CATEGORY FILTER
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(labelText: l10n.notebookCategory, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(l10n.notebookAll, overflow: TextOverflow.ellipsis)),
                            ...categoriesAsync.maybeWhen(
                              data: (cats) => cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )
                          ],
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                      // ACTIONS
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.42,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.date_range, color: Colors.blue),
                              tooltip: l10n.notebookDateRange,
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDateRange: _startDate != null && _endDate != null
                                      ? DateTimeRange(start: _startDate!, end: _endDate!)
                                      : null,
                                );
                                if (range != null) {
                                  setState(() {
                                    _startDate = range.start;
                                    _endDate = range.end.add(const Duration(days: 1)); // inclusive
                                  });
                                }
                              },
                            ),
                            if (_selectedType != null || _startDate != null || _selectedPersonId != null || _selectedAccountId != null || _selectedBookId != null || _selectedCategoryId != null)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                tooltip: l10n.notebookClearFilters,
                                onPressed: () => setState(() {
                                  _selectedType = null;
                                  _startDate = null;
                                  _endDate = null;
                                  _selectedPersonId = null;
                                  _selectedAccountId = null;
                                  _selectedBookId = null;
                                  _selectedCategoryId = null;
                                }),
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),'''

with open(tx_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the exact block
idx_start = content.find('          Padding(')
idx_end = content.find('            ),\n          ),')
if idx_start != -1 and idx_end != -1:
    idx_end += len('            ),\\n          ),')
    new_content = content[:idx_start] + new_filters + content[idx_end:]
    with open(tx_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
else:
    print("Could not find the block to replace")
