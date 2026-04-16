import 'package:flutter_test/flutter_test.dart';
import 'package:YeniAsya/models/app_user.dart';

void main() {
  test('RevenueCat ids are anchored to the account id', () {
    final user = AppUser(
      id: 876,
      name: 'Aykut',
      email: 'ayktbyz@gmail.com',
      roleId: 2,
      roleName: 'admin',
      payUniqe: r'$RCAnonymousID:1aa96580a15a4e55afaadcc8c6d29f1b',
    );

    expect(user.revenueCatUserId, '876');
    expect(
      user.legacyRevenueCatUserId,
      r'$RCAnonymousID:1aa96580a15a4e55afaadcc8c6d29f1b',
    );
  });

  test('legacy RevenueCat ids remain available for fallback lookup', () {
    final user = AppUser(
      id: 876,
      name: 'Aykut',
      email: 'ayktbyz@gmail.com',
      roleId: 2,
      roleName: 'admin',
      payUniqe: 'stable-account-id-123',
    );

    expect(user.revenueCatUserId, '876');
    expect(user.legacyRevenueCatUserId, 'stable-account-id-123');
  });

  test('numeric legacy RevenueCat ids still resolve to the account id', () {
    final user = AppUser(
      id: 876,
      name: 'Aykut',
      email: 'ayktbyz@gmail.com',
      roleId: 2,
      roleName: 'admin',
      payUniqe: '876',
    );

    expect(user.revenueCatUserId, '876');
    expect(user.legacyRevenueCatUserId, '876');
  });
}
