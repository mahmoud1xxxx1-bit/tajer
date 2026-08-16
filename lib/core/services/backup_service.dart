import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_service.g.dart';

class BackupService {
  final FirebaseFirestore _firestore;

  BackupService(this._firestore);

  static const int _schemaVersion = 2;
  static const int _batchSize = 400;
  static const String _typeKey = '__tajer_type';
  static const String _timestampType = 'timestamp';

  static const List<String> _rootCollections = [
    'products',
    'orders',
    'customers',
    'raw_materials',
    'shifts',
  ];

  static const List<String> _merchantSubcollections = [
    'categories',
    'expenses',
    'inventory_logs',
    'suppliers',
    'payments',
    'notebook_books',
    'notebook_accounts',
    'notebook_categories',
    'notebook_people',
    'notebook_transactions',
  ];

  static const List<String> _userSubcollections = [
    'employees',
    'notifications',
  ];

  static const Set<String> _legacyTimestampKeys = {
    'createdAt',
    'updatedAt',
    'date',
    'startTime',
    'endTime',
    'scheduledTime',
    'timestamp',
    'closedAt',
    'firstUsedAt',
  };

  /// Collects the complete current Tajer merchant workspace into a JSON file.
  /// Firestore-specific values are encoded with explicit type markers so they
  /// can be restored with the same Firestore type later.
  Future<String> exportDataToJson(String merchantId) async {
    final Map<String, dynamic> backupData = {
      'schemaVersion': _schemaVersion,
      'backupDate': DateTime.now().toIso8601String(),
      'merchantId': merchantId,
    };

    for (final collection in _rootCollections) {
      final snapshot = await _firestore
          .collection(collection)
          .where('merchantId', isEqualTo: merchantId)
          .get();
      backupData[collection] = snapshot.docs
          .map((doc) => _encodeDocument(doc.id, doc.data()))
          .toList();
    }

    for (final sub in _merchantSubcollections) {
      final snapshot = await _firestore
          .collection('merchants')
          .doc(merchantId)
          .collection(sub)
          .get();
      backupData[sub] = snapshot.docs
          .map((doc) => _encodeDocument(doc.id, doc.data()))
          .toList();
    }

    for (final sub in _userSubcollections) {
      final snapshot = await _firestore
          .collection('users')
          .doc(merchantId)
          .collection(sub)
          .get();
      backupData[sub] = snapshot.docs
          .map((doc) => _encodeDocument(doc.id, doc.data()))
          .toList();
    }

    // Supplier transactions are nested under every supplier document.
    final supplierTransactions = <String, dynamic>{};
    final suppliersSnapshot = await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('suppliers')
        .get();
    for (final supplier in suppliersSnapshot.docs) {
      final transactions = await supplier.reference.collection('transactions').get();
      if (transactions.docs.isNotEmpty) {
        supplierTransactions[supplier.id] = transactions.docs
            .map((doc) => _encodeDocument(doc.id, doc.data()))
            .toList();
      }
    }
    backupData['supplier_transactions'] = supplierTransactions;

    return jsonEncode(backupData);
  }

  /// Restores a Tajer backup. Version 2 preserves Firestore Timestamp values.
  /// Version 1 backups remain supported by converting known historical date
  /// fields from their old ISO-string representation back to Timestamp.
  Future<void> importDataFromJson(String merchantId, String jsonString) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Tajer backup format.');
    }

    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
    final isLegacy = schemaVersion < 2;
    final writes = <_RestoreWrite>[];

    for (final collection in _rootCollections) {
      final items = decoded[collection] as List<dynamic>? ?? const [];
      for (final rawItem in items) {
        final parsed = _decodeBackupItem(rawItem, isLegacy: isLegacy);
        if (parsed == null) continue;
        final data = parsed.data;
        data['merchantId'] = merchantId;
        writes.add(_RestoreWrite(
          _firestore.collection(collection).doc(parsed.id),
          data,
        ));
      }
    }

    for (final sub in _merchantSubcollections) {
      final items = decoded[sub] as List<dynamic>? ?? const [];
      for (final rawItem in items) {
        final parsed = _decodeBackupItem(rawItem, isLegacy: isLegacy);
        if (parsed == null) continue;
        final data = parsed.data;
        if (data.containsKey('merchantId')) {
          data['merchantId'] = merchantId;
        }
        writes.add(_RestoreWrite(
          _firestore
              .collection('merchants')
              .doc(merchantId)
              .collection(sub)
              .doc(parsed.id),
          data,
        ));
      }
    }

    for (final sub in _userSubcollections) {
      final items = decoded[sub] as List<dynamic>? ?? const [];
      for (final rawItem in items) {
        final parsed = _decodeBackupItem(rawItem, isLegacy: isLegacy);
        if (parsed == null) continue;
        final data = parsed.data;
        if (data.containsKey('merchantId')) {
          data['merchantId'] = merchantId;
        }
        if (data.containsKey('merchantUid')) {
          data['merchantUid'] = merchantId;
        }
        writes.add(_RestoreWrite(
          _firestore
              .collection('users')
              .doc(merchantId)
              .collection(sub)
              .doc(parsed.id),
          data,
        ));
      }
    }

    final supplierTransactions = decoded['supplier_transactions'];
    if (supplierTransactions is Map<String, dynamic>) {
      for (final entry in supplierTransactions.entries) {
        final supplierId = entry.key;
        final items = entry.value as List<dynamic>? ?? const [];
        for (final rawItem in items) {
          final parsed = _decodeBackupItem(rawItem, isLegacy: isLegacy);
          if (parsed == null) continue;
          final data = parsed.data;
          if (data.containsKey('merchantId')) {
            data['merchantId'] = merchantId;
          }
          writes.add(_RestoreWrite(
            _firestore
                .collection('merchants')
                .doc(merchantId)
                .collection('suppliers')
                .doc(supplierId)
                .collection('transactions')
                .doc(parsed.id),
            data,
          ));
        }
      }
    }

    await _commitInChunks(writes);
  }

  Future<void> _commitInChunks(List<_RestoreWrite> writes) async {
    for (var start = 0; start < writes.length; start += _batchSize) {
      final end = (start + _batchSize < writes.length)
          ? start + _batchSize
          : writes.length;
      final batch = _firestore.batch();
      for (var i = start; i < end; i++) {
        batch.set(writes[i].reference, writes[i].data);
      }
      await batch.commit();
    }
  }

  Map<String, dynamic> _encodeDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    return {
      'id': id,
      ..._encodeMap(data),
    };
  }

  Map<String, dynamic> _encodeMap(Map<String, dynamic> source) {
    return source.map((key, value) => MapEntry(key, _encodeValue(value)));
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        _typeKey: _timestampType,
        'value': value.toDate().toIso8601String(),
      };
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _encodeValue(nestedValue),
        ),
      );
    }
    if (value is Iterable) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  _DecodedBackupItem? _decodeBackupItem(
    dynamic rawItem, {
    required bool isLegacy,
  }) {
    if (rawItem is! Map) return null;
    final rawMap = Map<String, dynamic>.from(rawItem);
    final id = rawMap.remove('id')?.toString();
    if (id == null || id.isEmpty) return null;

    final decoded = _decodeValue(rawMap, isLegacy: isLegacy);
    if (decoded is! Map<String, dynamic>) return null;
    return _DecodedBackupItem(id, decoded);
  }

  dynamic _decodeValue(
    dynamic value, {
    required bool isLegacy,
    String? fieldName,
  }) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (map[_typeKey] == _timestampType) {
        final encodedValue = map['value']?.toString();
        final date = encodedValue == null ? null : DateTime.tryParse(encodedValue);
        if (date == null) {
          throw const FormatException('Invalid timestamp in Tajer backup.');
        }
        return Timestamp.fromDate(date);
      }

      return map.map(
        (key, nestedValue) => MapEntry(
          key,
          _decodeValue(
            nestedValue,
            isLegacy: isLegacy,
            fieldName: key,
          ),
        ),
      );
    }

    if (value is List) {
      return value
          .map((item) => _decodeValue(item, isLegacy: isLegacy))
          .toList();
    }

    if (isLegacy &&
        value is String &&
        fieldName != null &&
        _legacyTimestampKeys.contains(fieldName)) {
      final date = DateTime.tryParse(value);
      if (date != null) return Timestamp.fromDate(date);
    }

    return value;
  }

  /// Manual local export.
  Future<void> exportToLocalDevice(String merchantId) async {
    final jsonString = await exportDataToJson(merchantId);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/tajer_backup_$merchantId.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(file.path)], text: 'Tajer Backup');
  }

  /// Manual local import.
  Future<bool> importFromLocalDevice(String merchantId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      await importDataFromJson(merchantId, jsonString);
      return true;
    }
    return false;
  }
}

class _RestoreWrite {
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> data;

  const _RestoreWrite(this.reference, this.data);
}

class _DecodedBackupItem {
  final String id;
  final Map<String, dynamic> data;

  const _DecodedBackupItem(this.id, this.data);
}

@riverpod
BackupService backupService(BackupServiceRef ref) {
  return BackupService(FirebaseFirestore.instance);
}
