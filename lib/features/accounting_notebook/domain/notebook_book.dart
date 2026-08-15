import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class NotebookBook {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isArchived;

  const NotebookBook({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isArchived = false,
  });

  factory NotebookBook.fromMap(Map<String, dynamic> data, String documentId) {
    return NotebookBook(
      id: documentId,
      name: data['name']?.toString() ?? '',
      createdAt: safeParseDate(data['createdAt']),
      isArchived: data['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
    };
  }
}
