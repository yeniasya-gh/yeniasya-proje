import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:YeniAsya/services/auth/auth_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('session revoked logout forces login screen', () async {
    final provider = AuthProvider();
    AuthLogoutReason? capturedReason;

    provider.onLogout = (reason) async {
      capturedReason = reason;
    };

    await provider.logout(
      bootstrapGuest: false,
      reason: AuthLogoutReason.sessionRevoked,
      message: 'Oturumunuz sonlandırıldı. Lütfen tekrar giriş yapın.',
    );

    expect(capturedReason, AuthLogoutReason.sessionRevoked);
    expect(provider.shouldForceLoginScreen, isTrue);
    expect(provider.errorMessage, contains('Oturumunuz sonlandırıldı'));
    expect(provider.isLoggedIn, isFalse);
  });
}
