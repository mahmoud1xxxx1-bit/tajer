import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class NotebookCategory {
  final String id;
  final String name;
  final String type; // income, expense
  final String bookId;
  final DateTime createdAt;

  const NotebookCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.bookId,
    required this.createdAt,
  });

  factory NotebookCategory.fromMap(Map<String, dynamic> data, String documentId) {
    return NotebookCategory(
      id: documentId,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? 'expense',
      bookId: data['bookId']?.toString() ?? '',
      createdAt: safeParseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'bookId': bookId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
