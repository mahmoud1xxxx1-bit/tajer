import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StoreProfile {
  final String storeName;
  final String phone;
  final String address;
  final String logoBase64;

  StoreProfile({
    this.storeName = '',
    this.phone = '',
    this.address = '',
    this.logoBase64 = '',
  });

  StoreProfile copyWith({
    String? storeName,
    String? phone,
    String? address,
    String? logoBase64,
  }) {
    return StoreProfile(
      storeName: storeName ?? this.storeName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoBase64: logoBase64 ?? this.logoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'phone': phone,
    'address': address,
    'logoBase64': logoBase64,
  };

  factory StoreProfile.fromJson(Map<String, dynamic> json) => StoreProfile(
    storeName: json['storeName'] ?? '',
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    logoBase64: json['logoBase64'] ?? '',
  );
}

class StoreProfileNotifier extends StateNotifier<AsyncValue<StoreProfile>> {
  StoreProfileNotifier() : super(const AsyncValue.loading()) {
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
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(StoreProfile profile) async {
    state = AsyncValue.data(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('store_profile', jsonEncode(profile.toJson()));
  }
}

final storeProfileProvider = StateNotifierProvider<StoreProfileNotifier, AsyncValue<StoreProfile>>((ref) {
  return StoreProfileNotifier();
});
