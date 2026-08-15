import 'dart:io';

void main() {
  final file = File('lib/features/accounting_notebook/data/accounting_notebook_provider.dart');
  var content = file.readAsStringSync();

  // 1. Fix createIncome
  final incomeSearch = '''
    // In a real app, this should use a transaction/batch to update account balance
    // For V1 baseline, we will do it sequentially or via batch
    final batch = _repository.accountsRef.firestore.batch();
    
    // 1. Add transaction
    batch.set(_repository.transactionsRef.doc(txId), tx.toMap());
    
    // 2. Update account balance
    final accountRef = _repository.accountsRef.doc(accountId);
    batch.update(accountRef, {
      \\'balance\\': FieldValue.increment(amount)
    });
    
    await batch.commit();''';
  final incomeReplace = '''
    final accountRef = _repository.accountsRef.doc(accountId);
    final categoryRef = _repository.categoriesRef.doc(categoryId);
    final txRef = _repository.transactionsRef.doc(txId);

    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      if (!accountSnap.exists) throw Exception('Account not found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('Account bookId mismatch');

      final categorySnap = await transaction.get(categoryRef);
      if (!categorySnap.exists) throw Exception('Category not found');
      if (categorySnap.data()?['bookId'] != bookId) throw Exception('Category bookId mismatch');

      final currentBalance = accountSnap.data()?['balance'] as double? ?? 0.0;
      
      transaction.set(txRef, tx.toMap());
      transaction.update(accountRef, {'balance': currentBalance + amount});
    });''';
    
  // The original has 'batch.set(_repository.transactionsRef.doc(txId), tx.toMap());' etc. I will use string replace using exact matched.

  content = content.replaceFirst('''
    // In a real app, this should use a transaction/batch to update account balance
    // For V1 baseline, we will do it sequentially or via batch
    final batch = _repository.accountsRef.firestore.batch();
    
    // 1. Add transaction
    batch.set(_repository.transactionsRef.doc(txId), tx.toMap());
    
    // 2. Update account balance
    final accountRef = _repository.accountsRef.doc(accountId);
    batch.update(accountRef, {
      'balance': FieldValue.increment(amount)
    });
    
    await batch.commit();''', incomeReplace);

  // 2. Fix createExpense
  content = content.replaceFirst('''
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      if (!accountSnap.exists) throw Exception('Account not found');
      
      final currentBalance = accountSnap.data()?['balance'] as double? ?? 0.0;''',
  '''
    await _repository.accountsRef.firestore.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      if (!accountSnap.exists) throw Exception('Account not found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('Account bookId mismatch');
      
      final categorySnap = await transaction.get(_repository.categoriesRef.doc(categoryId));
      if (!categorySnap.exists) throw Exception('Category not found');
      if (categorySnap.data()?['bookId'] != bookId) throw Exception('Category bookId mismatch');

      final currentBalance = accountSnap.data()?['balance'] as double? ?? 0.0;''');

  // 3. Fix createDebt
  content = content.replaceFirst('''
    final batch = _repository.accountsRef.firestore.batch();
    batch.set(_repository.transactionsRef.doc(txId), tx.toMap());
    
    final personRef = _repository.peopleRef.doc(personId);
    if (isOwedToMe) {
      batch.update(personRef, {'amountOwedToMe': FieldValue.increment(amount)});
    } else {
      batch.update(personRef, {'amountIOwe': FieldValue.increment(amount)});
    }
    
    await batch.commit();''',
  '''
    final personRef = _repository.peopleRef.doc(personId);
    
    await _repository.peopleRef.firestore.runTransaction((transaction) async {
      final personSnap = await transaction.get(personRef);
      if (!personSnap.exists) throw Exception('Person not found');
      if (personSnap.data()?['bookId'] != bookId) throw Exception('Person bookId mismatch');

      final owedToMe = personSnap.data()?['amountOwedToMe'] as double? ?? 0.0;
      final iOwe = personSnap.data()?['amountIOwe'] as double? ?? 0.0;
      
      transaction.set(_repository.transactionsRef.doc(txId), tx.toMap());
      
      if (isOwedToMe) {
        transaction.update(personRef, {'amountOwedToMe': owedToMe + amount});
      } else {
        transaction.update(personRef, {'amountIOwe': iOwe + amount});
      }
    });''');

  // 4. Fix recordDebtPayment
  content = content.replaceFirst('''
      if (!personSnap.exists) throw Exception('Person not found');
      if (!accountSnap.exists) throw Exception('Account not found');''',
  '''
      if (!personSnap.exists) throw Exception('Person not found');
      if (personSnap.data()?['bookId'] != bookId) throw Exception('Person bookId mismatch');

      if (!accountSnap.exists) throw Exception('Account not found');
      if (accountSnap.data()?['bookId'] != bookId) throw Exception('Account bookId mismatch');''');

  file.writeAsStringSync(content);
}
