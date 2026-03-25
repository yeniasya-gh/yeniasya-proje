import 'package:flutter_test/flutter_test.dart';

import 'package:YeniAsya/utils/purchase_channel_labels.dart';

void main() {
  group('PurchaseChannelLabels', () {
    test('maps subscription platforms to human labels', () {
      expect(
        PurchaseChannelLabels.purchasePlatformLabel('google_play'),
        'Google Play',
      );
      expect(PurchaseChannelLabels.purchasePlatformLabel('appStore'), 'Apple');
      expect(
        PurchaseChannelLabels.purchasePlatformLabel('paratika'),
        'Paratika (Sanal POS)',
      );
    });

    test('prefers purchase platform then grant source', () {
      final google = {
        'purchase_platform': 'google_play',
        'grant_source': 'revenuecat',
      };
      final apple = {
        'purchase_platform': 'apple',
        'grant_source': 'revenuecat',
      };
      final paratika = {
        'purchase_platform': 'paratika',
        'grant_source': 'checkout',
      };
      final manual = {'source': 'manual_newspaper'};

      expect(PurchaseChannelLabels.accessChannelLabel(google), 'Google Play');
      expect(PurchaseChannelLabels.accessChannelLabel(apple), 'Apple');
      expect(
        PurchaseChannelLabels.accessChannelLabel(paratika),
        'Paratika (Sanal POS)',
      );
      expect(PurchaseChannelLabels.accessChannelLabel(manual), 'Manuel');
    });

    test('maps payment provider labels', () {
      expect(
        PurchaseChannelLabels.paymentProviderLabel('paratika'),
        'Paratika (Sanal POS)',
      );
      expect(
        PurchaseChannelLabels.paymentProviderLabel('google_play'),
        'Google Play',
      );
      expect(PurchaseChannelLabels.paymentProviderLabel('apple'), 'Apple');
    });
  });
}
