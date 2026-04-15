import 'package:flutter_test/flutter_test.dart';
import 'package:YeniAsya/models/app_user.dart';

void main() {
  test('anonymous RevenueCat ids fall back to user id', () {
    final user = AppUser(
      id: 876,
      name: 'Aykut',
      email: 'ayktbyz@gmail.com',
      roleId: 2,
      roleName: 'admin',
      payUniqe: r'$RCAnonymousID:1aa96580a15a4e55afaadcc8c6d29f1b',
    );

    expect(user.revenueCatUserId, '876');
  });

  test('RevenueCat user id follows the stable account id', () {
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
}
