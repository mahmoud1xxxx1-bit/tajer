import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/employee.dart';

// null means the owner is using the app
final activeEmployeeProvider = StateProvider<Employee?>((ref) => null);
