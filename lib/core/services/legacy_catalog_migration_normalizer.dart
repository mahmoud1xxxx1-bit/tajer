import 'package:cloud_firestore/cloud_firestore.dart';

class LegacyCatalogMigrationDataException implements Exception {
  final String merchantId;
  final String documentPath;
  final String field;
  final String reason;

  const LegacyCatalogMigrationDataException({
    required this.merchantId,
    required this.documentPath,
    required this.field,
    required this.reason,
  });

  @override
  String toString() =>
      'LegacyCatalogMigrationDataException(merchantId: $merchantId, '
      'documentPath: $documentPath, field: $field, reason: $reason)';
}

Map<String, dynamic> normalizeLegacyProductForBranch({
  required DocumentSnapshot<Map<String, dynamic>> document,
  required String merchantId,
  required String branchId,
}) {
  final data = Map<String, dynamic>.from(document.data() ?? const {});
  _requireMerchant(data, merchantId, document.reference.path);
  data['id'] = document.id;
  data['merchantId'] = merchantId;
  data['branchId'] = branchId;
  data['name'] =
      _requiredString(data, 'name', merchantId, document.reference.path);
  data['price'] =
      _requiredNumber(data, 'price', merchantId, document.reference.path)
          .toDouble();
  data['quantity'] = 0;
  data['categoryId'] = _optionalString(data['categoryId']);
  data['barcode'] = _optionalString(data['barcode']);
  data['modifiers'] = _stringList(data['modifiers']);
  data['recipe'] = _recipe(data['recipe'], merchantId, document.reference.path);
  data['isTaxInclusive'] =
      data['isTaxInclusive'] is bool ? data['isTaxInclusive'] : null;
  data['taxPercentage'] =
      data['taxPercentage'] is num ? data['taxPercentage'] : null;
  data['isManufacturedOnDemand'] = data['isManufacturedOnDemand'] == true;
  data['isArchived'] = data['isArchived'] == true;
  data['taxMode'] =
      const {'store', 'custom', 'exempt'}.contains(data['taxMode'])
          ? data['taxMode']
          : 'store';
  data['createdAt'] = _timestamp(data['createdAt']);
  data['updatedAt'] = _timestamp(data['updatedAt']);
  data.remove('costPrice');
  return data;
}

Map<String, dynamic> normalizeLegacyRawMaterialForBranch({
  required DocumentSnapshot<Map<String, dynamic>> document,
  required String merchantId,
  required String branchId,
}) {
  final data = Map<String, dynamic>.from(document.data() ?? const {});
  _requireMerchant(data, merchantId, document.reference.path);
  data['id'] = document.id;
  data['merchantId'] = merchantId;
  data['branchId'] = branchId;
  data['name'] =
      _requiredString(data, 'name', merchantId, document.reference.path);
  data['unit'] =
      _requiredString(data, 'unit', merchantId, document.reference.path);
  data['quantity'] = 0.0;
  data['initialQuantity'] = 0.0;
  data['isArchived'] = data['isArchived'] == true;
  data['createdAt'] = _timestamp(data['createdAt']);
  data['updatedAt'] = _timestamp(data['updatedAt']);
  return data;
}

Map<String, dynamic> normalizeLegacyCategoryForBranch({
  required DocumentSnapshot<Map<String, dynamic>> document,
  required String merchantId,
  required String branchId,
}) {
  final data = Map<String, dynamic>.from(document.data() ?? const {});
  final storedMerchantId = _optionalString(data['merchantId']);
  if (storedMerchantId != null && storedMerchantId != merchantId) {
    throw LegacyCatalogMigrationDataException(
      merchantId: merchantId,
      documentPath: document.reference.path,
      field: 'merchantId',
      reason: 'does not match the parent merchant',
    );
  }
  data['id'] = document.id;
  data['merchantId'] = merchantId;
  data['branchId'] = branchId;
  data['name'] =
      _requiredString(data, 'name', merchantId, document.reference.path);
  data['createdAt'] = _timestamp(data['createdAt']);
  return data;
}

void _requireMerchant(
  Map<String, dynamic> data,
  String merchantId,
  String path,
) {
  final storedMerchantId = _optionalString(data['merchantId']);
  if (storedMerchantId != merchantId) {
    throw LegacyCatalogMigrationDataException(
      merchantId: merchantId,
      documentPath: path,
      field: 'merchantId',
      reason: storedMerchantId == null ? 'is missing' : 'does not match',
    );
  }
}

String _requiredString(
  Map<String, dynamic> data,
  String field,
  String merchantId,
  String path,
) {
  final value = _optionalString(data[field]);
  if (value == null || value.isEmpty) {
    throw LegacyCatalogMigrationDataException(
      merchantId: merchantId,
      documentPath: path,
      field: field,
      reason: 'is missing or empty',
    );
  }
  return value;
}

num _requiredNumber(
  Map<String, dynamic> data,
  String field,
  String merchantId,
  String path,
) {
  final value = data[field];
  if (value is! num) {
    throw LegacyCatalogMigrationDataException(
      merchantId: merchantId,
      documentPath: path,
      field: field,
      reason: 'must be numeric',
    );
  }
  return value;
}

String? _optionalString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, dynamic>> _recipe(
  dynamic value,
  String merchantId,
  String path,
) {
  if (value == null) return const [];
  if (value is! List) {
    throw LegacyCatalogMigrationDataException(
      merchantId: merchantId,
      documentPath: path,
      field: 'recipe',
      reason: 'must be a list',
    );
  }
  return value.map((item) {
    if (item is! Map) {
      throw LegacyCatalogMigrationDataException(
        merchantId: merchantId,
        documentPath: path,
        field: 'recipe',
        reason: 'contains a non-map item',
      );
    }
    final recipeItem = Map<String, dynamic>.from(item);
    final rawMaterialId = _optionalString(recipeItem['rawMaterialId']);
    final amountRequired = recipeItem['amountRequired'];
    if (rawMaterialId == null ||
        rawMaterialId.isEmpty ||
        amountRequired is! num) {
      throw LegacyCatalogMigrationDataException(
        merchantId: merchantId,
        documentPath: path,
        field: 'recipe',
        reason: 'contains an invalid raw material identity or amount',
      );
    }
    return {
      'rawMaterialId': rawMaterialId,
      'amountRequired': amountRequired.toDouble(),
    };
  }).toList(growable: false);
}

Timestamp _timestamp(dynamic value) {
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return Timestamp.fromDate(parsed);
  }
  return Timestamp.fromMillisecondsSinceEpoch(0);
}
