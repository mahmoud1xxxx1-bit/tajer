import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/data/branch_inventory_repository.dart';
import '../domain/stocktake.dart';

class StocktakeException implements Exception {
  final String message;
  final List<String> conflictingItems;
  StocktakeException(this.message, [this.conflictingItems = const []]);
  @override
  String toString() => message;
}

class StocktakeRepository {
  final FirebaseFirestore _firestore;

  StocktakeRepository(this._firestore);
  
  Future<StocktakeSession?> getSession(String merchantId, String sessionId) async {
    final doc = await _firestore
      .collection('merchants')
      .doc(merchantId)
      .collection('stocktakes')
      .doc(sessionId)
      .get();
      
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return StocktakeSession.fromJson(data);
  }

  Stream<List<StocktakeSession>> watchSessions(String merchantId, String branchId) {
    return _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('stocktakes')
        .where('branchId', isEqualTo: branchId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return StocktakeSession.fromJson(data);
            }).toList());
  }

  Stream<List<StocktakeLine>> watchLines(String merchantId, String sessionId) {
    return _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('stocktakes')
        .doc(sessionId)
        .collection('lines')
        .orderBy('countedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return StocktakeLine.fromJson(data);
            }).toList());
  }

  Future<StocktakeSession> createSession({
    required String merchantId,
    required String branchId,
    required String createdByUid,
    required String createdByName,
  }) async {
    final ref = _firestore.collection('merchants').doc(merchantId).collection('stocktakes').doc();
    final session = StocktakeSession(
      id: ref.id,
      merchantId: merchantId,
      branchId: branchId,
      status: 'counting',
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
      createdByUid: createdByUid,
      createdByName: createdByName,
    );
    await ref.set(session.toJson());
    return session;
  }

  Future<void> saveLine({
    required String merchantId,
    required String sessionId,
    required StocktakeLine line,
  }) async {
    final lineRef = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('stocktakes')
        .doc(sessionId)
        .collection('lines')
        .doc(line.id);

    final sessionRef = _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('stocktakes')
        .doc(sessionId);

    await _firestore.runTransaction((tx) async {
      final lineDoc = await tx.get(lineRef);
      final isNew = !lineDoc.exists;
      
      tx.set(lineRef, line.toJson());

      if (isNew) {
        tx.update(sessionRef, {
          'countedLines': FieldValue.increment(1),
          if (line.difference != 0) 'varianceLines': FieldValue.increment(1),
        });
      } else {
        final oldLine = StocktakeLine.fromJson(lineDoc.data()!..['id'] = lineDoc.id);
        if (oldLine.difference == 0 && line.difference != 0) {
          tx.update(sessionRef, {'varianceLines': FieldValue.increment(1)});
        } else if (oldLine.difference != 0 && line.difference == 0) {
          tx.update(sessionRef, {'varianceLines': FieldValue.increment(-1)});
        }
      }
    });
  }
  
  Future<void> updateStatus(String merchantId, String sessionId, String status) async {
    await _firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('stocktakes')
        .doc(sessionId)
        .update({'status': status});
  }

  Future<void> finalizeStocktake({
    required String merchantId,
    required StocktakeSession session,
    required List<StocktakeLine> lines,
    required String actorUid,
    required String actorName,
  }) async {
    if (session.status == 'completed') return;
    
    final sessionRef = _firestore.collection('merchants').doc(merchantId).collection('stocktakes').doc(session.id);
    final invRepo = BranchInventoryRepository(_firestore, merchantId);

    final List<String> conflicts = [];

    await _firestore.runTransaction((tx) async {
      final sDoc = await tx.get(sessionRef);
      if (!sDoc.exists) throw Exception('Session not found');
      if (sDoc.data()!['status'] == 'completed') return;

      final now = DateTime.now();
      
      for (final line in lines) {
        if (line.difference == 0 || line.applied) continue;

        final invRef = invRepo.ref.doc(invRepo.docId(session.branchId, line.itemType, line.itemId));
        final invDoc = await tx.get(invRef);
        final currentQty = invDoc.exists ? ((invDoc.data() as Map<String, dynamic>)['quantity'] as num).toDouble() : 0.0;

        if (currentQty != line.expectedQuantityAtStart) {
          conflicts.add('${line.itemNameSnapshot} (Expected: ${line.expectedQuantityAtStart}, Found: $currentQty)');
          continue;
        }

        tx.set(invRef, {'quantity': line.countedQuantity}, SetOptions(merge: true));

        final lineRef = sessionRef.collection('lines').doc(line.id);
        tx.update(lineRef, {
          'applied': true,
          'appliedAt': Timestamp.fromDate(now),
        });

        final logRef = _firestore.collection('merchants').doc(merchantId).collection('inventory_logs').doc();
        tx.set(logRef, {
          'branchId': session.branchId,
          'itemType': line.itemType,
          'itemId': line.itemId,
          'itemName': line.itemNameSnapshot,
          'previousQuantity': line.expectedQuantityAtStart,
          'newQuantity': line.countedQuantity,
          'difference': line.difference,
          'reason': 'Stocktake adjustment: ${line.reason ?? "Counting"}',
          'type': line.difference < 0 ? 'deduction' : 'addition',
          'source': 'stocktake',
          'sourceId': session.id,
          'timestamp': Timestamp.fromDate(now),
          'performedBy': actorUid,
          'performedByName': actorName,
        });
      }

      if (conflicts.isNotEmpty) {
        throw StocktakeException(
            'Concurrency Conflict: Inventory has changed since counting started for some items. Please review.', conflicts);
      }

      tx.update(sessionRef, {
        'status': 'completed',
        'completedAt': Timestamp.fromDate(now),
      });
    });
  }
}

final stocktakeRepositoryProvider = Provider((ref) {
  return StocktakeRepository(FirebaseFirestore.instance);
});

final stocktakeSessionsProvider = StreamProvider.family<List<StocktakeSession>, String>((ref, branchId) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return Stream.value([]);
  final merchantId = currentEffectiveMerchantId(appUser);
  return ref.watch(stocktakeRepositoryProvider).watchSessions(merchantId, branchId);
});

final stocktakeLinesProvider = StreamProvider.family<List<StocktakeLine>, String>((ref, sessionId) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser == null) return Stream.value([]);
  final merchantId = currentEffectiveMerchantId(appUser);
  return ref.watch(stocktakeRepositoryProvider).watchLines(merchantId, sessionId);
});
