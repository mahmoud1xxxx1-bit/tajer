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

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  factory NotebookPerson.fromMap(Map<String, dynamic> data, String documentId) {
    return NotebookPerson(
      id: documentId,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString(),
      notes: data['notes']?.toString(),
      amountOwedToMe: _asDouble(data['amountOwedToMe']),
      amountIOwe: _asDouble(data['amountIOwe']),
      bookId: data['bookId']?.toString() ?? '',
      createdAt: safeParseDate(data['createdAt']),
      isArchived: _asBool(data['isArchived']),
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
      'isArchived': isArchived,
    };
  }
}
