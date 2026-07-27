import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String name;
  final String pin;
  final String role; // 'admin', 'cashier'
  final DateTime createdAt;

  Employee({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    required this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      pin: json['pin'] as String,
      role: json['role'] as String? ?? 'cashier',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pin': pin,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
