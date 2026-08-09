import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/providers/effective_merchant.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';

AppUser _user({
  required String id,
  required String role,
  String? merchantId,
}) {
  return AppUser(
    id: id,
    role: role,
    merchantId: merchantId,
    createdAt: DateTime(2026),
    isAnonymous: false,
  );
}

void main() {
  test('owner-like users use auth uid instead of legacy merchantId field', () {
    final user = _user(
      id: 'owner-auth-uid',
      role: 'merchant',
      merchantId: 'legacy-merchant-id',
    );

    expect(
      effectiveMerchantIdFor(user, authUid: 'owner-auth-uid'),
      'owner-auth-uid',
    );
  });

  test('admin and owner roles also use auth uid', () {
    expect(
      effectiveMerchantIdFor(
        _user(id: 'admin-auth-uid', role: 'admin', merchantId: 'legacy'),
        authUid: 'admin-auth-uid',
      ),
      'admin-auth-uid',
    );
    expect(
      effectiveMerchantIdFor(
        _user(id: 'owner-auth-uid', role: 'owner', merchantId: 'legacy'),
        authUid: 'owner-auth-uid',
      ),
      'owner-auth-uid',
    );
  });

  test('employees use app user merchantId', () {
    final user = _user(
      id: 'employee-auth-uid',
      role: 'employee',
      merchantId: 'merchant-owner-uid',
    );

    expect(
      effectiveMerchantIdFor(user, authUid: 'employee-auth-uid'),
      'merchant-owner-uid',
    );
  });
}
