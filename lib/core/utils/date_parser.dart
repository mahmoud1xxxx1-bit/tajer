import 'package:cloud_firestore/cloud_firestore.dart';

DateTime safeParseDate(dynamic value, {DateTime? fallback}) {
  return safeParseNullableDate(value) ?? fallback ?? DateTime.now();
}

DateTime? safeParseNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
