import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/date_parser.dart';

class Employee {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin', 'cashier'
  final DateTime createdAt;
  final List<String> assignedBranchIds;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.assignedBranchIds = const ['main'],
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['assignedBranchIds'];
    final branches = rawBranches is List
        ? rawBranches.map((value) => value.toString()).where((id) => id.isNotEmpty).toList()
        : <String>['main'];

    return Employee(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'cashier',
      createdAt: safeParseDate(json['createdAt']),
      assignedBranchIds: branches.isEmpty ? const ['main'] : branches,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'assignedBranchIds': assignedBranchIds.isEmpty ? const ['main'] : assignedBranchIds,
    };
  }
}
