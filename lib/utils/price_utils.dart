import 'package:flutter/material.dart';

class PriceInfo {
  final double salePrice;
  final double campaignPrice;
  final bool hasCampaign;

  const PriceInfo({
    required this.salePrice,
    required this.campaignPrice,
    required this.hasCampaign,
  });

  double get effectivePrice => hasCampaign ? campaignPrice : salePrice;

  bool get hasAnyPrice => salePrice > 0 || (hasCampaign && campaignPrice > 0);

  static PriceInfo fromRaw(dynamic saleRaw, dynamic campaignRaw) {
    return PriceInfo(
      salePrice: _parsePrice(saleRaw),
      campaignPrice: _parsePrice(campaignRaw),
      hasCampaign: _hasValue(campaignRaw),
    );
  }

  static double _parsePrice(dynamic value) {
    return double.tryParse(value?.toString() ?? "") ?? 0;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    return value.toString().trim().isNotEmpty;
  }
}

String formatPrice(double value) => value > 0 ? "₺${value.toStringAsFixed(2)}" : "Ücretsiz";

Widget buildPriceText({
  required PriceInfo info,
  TextStyle? saleStyle,
  TextStyle? campaignStyle,
  String emptyText = "-",
  double gap = 2,
  bool vertical = true,
}) {
  final hasCampaign = info.hasCampaign && info.campaignPrice > 0;
  final hasSale = info.salePrice > 0;
  
  // If either price is 0 (Free), we should show "Ücretsiz" or the discounted price
  if (info.hasCampaign && info.campaignPrice == 0) {
    return Text("Ücretsiz", style: campaignStyle ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
  }
  if (!info.hasCampaign && info.salePrice == 0) {
    return Text("Ücretsiz", style: saleStyle ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
  }

  if (!hasSale && !hasCampaign) {
    return Text(emptyText, style: saleStyle ?? const TextStyle(color: Colors.black54));
  }

  if (hasCampaign && hasSale) {
    final baseSale = saleStyle ?? const TextStyle(color: Colors.black54);
    final saleText = baseSale.copyWith(decoration: TextDecoration.lineThrough);
    final campText = campaignStyle ??
        const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w700,
        );
    if (!vertical) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatPrice(info.salePrice), style: saleText),
          SizedBox(width: gap),
          Text(formatPrice(info.campaignPrice), style: campText),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatPrice(info.salePrice), style: saleText),
        SizedBox(height: gap),
        Text(formatPrice(info.campaignPrice), style: campText),
      ],
    );
  }

  final activePrice = hasCampaign ? info.campaignPrice : info.salePrice;
  final activeStyle = campaignStyle ?? saleStyle ?? const TextStyle(color: Colors.red, fontWeight: FontWeight.w700);
  return Text(formatPrice(activePrice), style: activeStyle);
}
