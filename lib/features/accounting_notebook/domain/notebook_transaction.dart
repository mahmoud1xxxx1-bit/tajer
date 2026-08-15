import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class NotebookTransaction {
  final String id;
  final String
      type; // income, expense, receivable, payable, receivable_payment, payable_payment, account_transfer
  final double amount;
  final String bookId;
  final String? accountId; // null for pure debt creation
  final String? toAccountId; // only for account_transfer
  final String? categoryId; // for income/expense
  final String? personId; // for receivable/payable/payments
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const NotebookTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.bookId,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.personId,
    this.note,
    required this.date,
    required this.createdAt,
  });

  factory NotebookTransaction.fromMap(
      Map<String, dynamic> data, String documentId) {
    return NotebookTransaction(
      id: documentId,
      type: data['type']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      bookId: data['bookId']?.toString() ?? '',
      accountId: data['accountId']?.toString(),
      toAccountId: data['toAccountId']?.toString(),
      categoryId: data['categoryId']?.toString(),
      personId: data['personId']?.toString(),
      note: data['note']?.toString(),
      date: safeParseDate(data['date']),
      createdAt: safeParseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'bookId': bookId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'categoryId': categoryId,
      'personId': personId,
      'note': note,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
