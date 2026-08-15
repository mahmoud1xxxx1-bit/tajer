import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class NotebookPerson {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final double amountOwedToMe; // receivables
  final double amountIOwe; // payables
  final String bookId;
  final DateTime createdAt;
  final bool isArchived;

  const NotebookPerson({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.amountOwedToMe,
    required this.amountIOwe,
    required this.bookId,
    required this.createdAt,
    this.isArchived = false,
  });

  double get netBalance => amountOwedToMe - amountIOwe;

  factory NotebookPerson.fromMap(Map<String, dynamic> data, String documentId) {
    return NotebookPerson(
      id: documentId,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString(),
      notes: data['notes']?.toString(),
      amountOwedToMe: (data['amountOwedToMe'] as num?)?.toDouble() ?? 0.0,
      amountIOwe: (data['amountIOwe'] as num?)?.toDouble() ?? 0.0,
      bookId: data['bookId']?.toString() ?? '',
      createdAt: safeParseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'notes': notes,
      'amountOwedToMe': amountOwedToMe,
      'amountIOwe': amountIOwe,
      'bookId': bookId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
