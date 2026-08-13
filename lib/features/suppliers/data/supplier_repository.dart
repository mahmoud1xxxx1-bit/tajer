import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/data/auth_repository.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  final FirebaseFirestore _firestore;
  final String _merchantId;

  SupplierRepository(this._firestore, this._merchantId);

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection('merchants').doc(_merchantId).collection('suppliers');

  Query<Supplier> querySuppliers({
    String? searchQuery,
    String? folderName,
    bool? hasDebt,
    String sortBy = 'newest', // newest, alpha, debt
  }) {
    Query<Map<String, dynamic>> query = _suppliersRef;

    if (folderName != null && folderName.isNotEmpty && folderName != 'موردين عامون' && folderName != 'General Suppliers') {
      query = query.where('folderName', isEqualTo: folderName);
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThan: searchQuery + '\uf8ff')
          .orderBy('name');
    } else {
      if (hasDebt == true) {
        query = query.where('totalDebt', isGreaterThan: 0);
        query = query.orderBy('totalDebt', descending: true);
      } else {
        if (sortBy == 'debt') {
          query = query.orderBy('totalDebt', descending: true);
        } else if (sortBy == 'alpha') {
          query = query.orderBy('name', descending: false);
        } else {
          query = query.orderBy('createdAt', descending: true);
        }
      }
    }

    return query.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['merchantId'] = data['merchantId']?.toString() ?? '';
        data['name'] = data['name']?.toString() ?? '';
        data['phone'] = data['phone']?.toString() ?? '';
        data['totalDebt'] = (data['totalDebt'] ?? 0.0).toDouble();
        if (data['createdAt'] == null) {
          data['createdAt'] = Timestamp.now();
        }
        return Supplier.fromJson(data);
      },
      toFirestore: (supplier, _) => supplier.toJson(),
    );
  }

  Stream<List<Supplier>> watchSuppliers() {
    return _suppliersRef.withConverter(
      fromFirestore: (snapshot, _) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        data['merchantId'] = data['merchantId']?.toString() ?? '';
        data['name'] = data['name']?.toString() ?? '';
        data['phone'] = data['phone']?.toString() ?? '';
        data['totalDebt'] = (data['totalDebt'] ?? 0.0).toDouble();
        if (data['createdAt'] == null) {
          data['createdAt'] = Timestamp.now();
        }
        return Supplier.fromJson(data);
      },
      toFirestore: (supplier, _) => supplier.toJson(),
    ).orderBy('createdAt', descending: true).limit(1000).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _suppliersRef.doc(supplier.id).set(supplier.toJson());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _suppliersRef.doc(supplier.id).update(supplier.toJson());
  }

  Future<void> paySupplierDebt({
    required String supplierId,
    required double amountPaid,
  }) async {
    if (amountPaid <= 0) return;

    final supplierDocRef = _suppliersRef.doc(supplierId);
    
    // Using a direct update allows offline persistence instead of runTransaction which fails offline.
    await supplierDocRef.update({
      'totalDebt': FieldValue.increment(-amountPaid),
    });
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _suppliersRef.doc(supplierId).delete();
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return null;
  return SupplierRepository(FirebaseFirestore.instance, appUser.merchantId ?? appUser.id);
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  if (repo == null) return Stream.value([]);
  return repo.watchSuppliers();
});

