import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_service.g.dart';

class BackupService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  BackupService(this._firestore, this._storage);

  /// 1. Collect all data into a JSON string
  Future<String> exportDataToJson(String merchantId) async {
    final Map<String, dynamic> backupData = {};
    backupData['backupDate'] = DateTime.now().toIso8601String();
    backupData['merchantId'] = merchantId;

    // Root collections
    final rootCollections = ['products', 'orders', 'customers'];
    for (final collection in rootCollections) {
      final snapshot = await _firestore.collection(collection).where('merchantId', isEqualTo: merchantId).get();
      backupData[collection] = snapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
    }

    // Subcollections
    final subcollections = ['categories', 'expenses', 'inventory_logs', 'suppliers', 'employees', 'notifications'];
    for (final sub in subcollections) {
      final basePath = ['employees', 'notifications'].contains(sub) ? 'users' : 'merchants';
      final snapshot = await _firestore.collection(basePath).doc(merchantId).collection(sub).get();
      backupData[sub] = snapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
    }

    return jsonEncode(backupData);
  }

  /// 2. Import data from JSON string
  Future<void> importDataFromJson(String merchantId, String jsonString) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonString);
    
    final batch = _firestore.batch();

    // Root collections
    final rootCollections = ['products', 'orders', 'customers'];
    for (final collection in rootCollections) {
      final items = backupData[collection] as List<dynamic>? ?? [];
      for (final item in items) {
        final docId = item['id'] as String?;
        if (docId != null) {
          final data = Map<String, dynamic>.from(item);
          data.remove('id');
          data['merchantId'] = merchantId; // Ensure it belongs to current merchant
          final docRef = _firestore.collection(collection).doc(docId);
          batch.set(docRef, data);
        }
      }
    }

    // Subcollections
    final subcollections = ['categories', 'expenses', 'inventory_logs', 'suppliers', 'employees', 'notifications'];
    for (final sub in subcollections) {
      final items = backupData[sub] as List<dynamic>? ?? [];
      final basePath = ['employees', 'notifications'].contains(sub) ? 'users' : 'merchants';
      for (final item in items) {
        final docId = item['id'] as String?;
        if (docId != null) {
          final data = Map<String, dynamic>.from(item);
          data.remove('id');
          final docRef = _firestore.collection(basePath).doc(merchantId).collection(sub).doc(docId);
          batch.set(docRef, data);
        }
      }
    }

    await batch.commit();
  }

  /// 3. Manual Local Export
  Future<void> exportToLocalDevice(String merchantId) async {
    final jsonString = await exportDataToJson(merchantId);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/tajer_backup_$merchantId.json');
    await file.writeAsString(jsonString);
    
    // Allow user to save it to their preferred location
    await Share.shareXFiles([XFile(file.path)], text: 'Tajer Backup');
  }

  /// 4. Manual Local Import
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

  /// 5. Cloud Export (Firebase Storage)
  Future<void> exportToCloud(String merchantId) async {
    final jsonString = await exportDataToJson(merchantId);
    final ref = _storage.ref().child('backups/$merchantId/latest_backup.json');
    
    try {
      await ref.putString(
        jsonString,
        format: PutStringFormat.raw,
        metadata: SettableMetadata(contentType: 'application/json'),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized') {
        throw Exception("غير مصرح لك برفع النسخة. يرجى تعديل قواعد أمان التخزين (Storage Rules) في Firebase كما ذكرنا.");
      } else if (e.code == 'bucket-not-found' || e.code == 'unknown') {
        throw Exception("خدمة التخزين (Storage) غير مفعلة أو غير متوفرة. يرجى تفعيلها من Firebase Console.");
      }
      throw Exception(e.message ?? "حدث خطأ غير معروف في التخزين");
    } catch (e) {
      throw Exception("فشل في تجهيز البيانات للنسخ السحابي: $e");
    }
  }

  /// 6. Cloud Import
  Future<bool> importFromCloud(String merchantId) async {
    final ref = _storage.ref().child('backups/$merchantId/latest_backup.json');
    try {
      final data = await ref.getData();
      if (data != null) {
        final jsonString = utf8.decode(data);
        await importDataFromJson(merchantId, jsonString);
        return true;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        throw Exception("لم يتم العثور على نسخة سحابية سابقة لحسابك.");
      } else if (e.code == 'unauthorized') {
        throw Exception("غير مصرح لك باسترجاع النسخة. يرجى تعديل قواعد الأمان (Storage Rules).");
      }
      return false;
    } catch (e) {
      return false; // Not found or error
    }
    return false;
  }

  /// 7. Get Last Cloud Backup Date
  Future<DateTime?> getLastCloudBackupDate(String merchantId) async {
    try {
      final ref = _storage.ref().child('backups/$merchantId/latest_backup.json');
      final metadata = await ref.getMetadata();
      return metadata.updated;
    } catch (e) {
      return null;
    }
  }
}

@riverpod
BackupService backupService(BackupServiceRef ref) {
  return BackupService(FirebaseFirestore.instance, FirebaseStorage.instance);
}
