import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class NotebookAccount {
  final String id;
  final String name;
  final String type; // cash, bank, card, wallet
  final double balance;
  final String bookId;
  final DateTime createdAt;

  const NotebookAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.bookId,
    required this.createdAt,
  });

  factory NotebookAccount.fromMap(Map<String, dynamic> data, String documentId) {
    return NotebookAccount(
      id: documentId,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? 'cash',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      bookId: data['bookId']?.toString() ?? '',
      createdAt: safeParseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'bookId': bookId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
