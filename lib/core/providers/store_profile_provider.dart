import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../features/authentication/data/auth_repository.dart';

class StoreProfile {
  final String storeName;
  final String phone;
  final String address;
  final String logoBase64;
  final double? defaultTaxPercentage;
  final bool defaultIsTaxInclusive;
  final String? vatNumber;
  final String? crNumber;

  StoreProfile({
    this.storeName = '',
    this.phone = '',
    this.address = '',
    this.logoBase64 = '',
    this.defaultTaxPercentage,
    this.defaultIsTaxInclusive = false,
    this.vatNumber,
    this.crNumber,
  });

  StoreProfile copyWith({
    String? storeName,
    String? phone,
    String? address,
    String? logoBase64,
    double? defaultTaxPercentage,
    bool? defaultIsTaxInclusive,
    String? vatNumber,
    String? crNumber,
  }) {
    return StoreProfile(
      storeName: storeName ?? this.storeName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoBase64: logoBase64 ?? this.logoBase64,
      defaultTaxPercentage: defaultTaxPercentage ?? this.defaultTaxPercentage,
      defaultIsTaxInclusive: defaultIsTaxInclusive ?? this.defaultIsTaxInclusive,
      vatNumber: vatNumber ?? this.vatNumber,
      crNumber: crNumber ?? this.crNumber,
    );
  }

  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'phone': phone,
    'address': address,
    'logoBase64': logoBase64,
    'defaultTaxPercentage': defaultTaxPercentage,
    'defaultIsTaxInclusive': defaultIsTaxInclusive,
    'vatNumber': vatNumber,
    'crNumber': crNumber,
  };

  factory StoreProfile.fromJson(Map<String, dynamic> json) => StoreProfile(
    storeName: json['storeName'] ?? '',
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    logoBase64: json['logoBase64'] ?? '',
    defaultTaxPercentage: json['defaultTaxPercentage'] != null ? (json['defaultTaxPercentage'] as num).toDouble() : null,
    defaultIsTaxInclusive: json['defaultIsTaxInclusive'] ?? false,
    vatNumber: json['vatNumber'],
    crNumber: json['crNumber'],
  );
}

class StoreProfileNotifier extends StateNotifier<AsyncValue<StoreProfile>> {
  final String? _merchantId;

  StoreProfileNotifier(this._merchantId) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('store_profile');
      if (dataStr != null) {
        final data = jsonDecode(dataStr);
        state = AsyncValue.data(StoreProfile.fromJson(data));
      } else {
        state = AsyncValue.data(StoreProfile());
      }

      if (_merchantId != null && _merchantId!.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('merchants')
              .doc(_merchantId)
              .collection('inventory_logs')
              .doc('store_profile_doc')
              .get();
          if (doc.exists && doc.data() != null) {
            final remoteProfile = StoreProfile.fromJson(doc.data()!);
            state = AsyncValue.data(remoteProfile);
            await prefs.setString('store_profile', jsonEncode(remoteProfile.toJson()));
          }
        } catch (_) {}
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(StoreProfile profile) async {
    state = AsyncValue.data(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_profile', jsonEncode(profile.toJson()));

    if (_merchantId != null && _merchantId!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('merchants')
            .doc(_merchantId)
            .collection('inventory_logs')
            .doc('store_profile_doc')
            .set(profile.toJson());
      } catch (_) {}
    }
  }
}

final storeProfileProvider = StateNotifierProvider<StoreProfileNotifier, AsyncValue<StoreProfile>>((ref) {
  final user = ref.watch(appUserProvider).value;
  final merchantId = user?.merchantId ?? user?.id;
  return StoreProfileNotifier(merchantId);
});
