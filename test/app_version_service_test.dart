import 'package:flutter_test/flutter_test.dart';
import 'package:YeniAsya/services/app_version_service.dart';

void main() {
  test('compareVersions compares build-aware versions correctly', () {
    expect(
      AppVersionService.compareVersions(
        currentVersion: '2.7.0',
        currentBuildNumber: '17',
        requiredVersion: '2.7.0+16',
      ),
      greaterThan(0),
    );

    expect(
      AppVersionService.compareVersions(
        currentVersion: '2.7.0',
        currentBuildNumber: '17',
        requiredVersion: '2.7.0+17',
      ),
      equals(0),
    );

    expect(
      AppVersionService.compareVersions(
        currentVersion: '2.7.0',
        currentBuildNumber: '17',
        requiredVersion: '2.7.1',
      ),
      lessThan(0),
    );
  });

  test('isForceUpdateRequired ignores same or newer versions', () {
    expect(
      AppVersionService.isForceUpdateRequired(
        currentVersion: '2.7.0',
        currentBuildNumber: '17',
        requiredVersion: '2.7.0',
      ),
      isFalse,
    );

    expect(
      AppVersionService.isForceUpdateRequired(
        currentVersion: '2.7.0',
        currentBuildNumber: '17',
        requiredVersion: '2.7.0+18',
      ),
      isTrue,
    );
  });
}
