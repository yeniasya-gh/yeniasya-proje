import 'package:flutter/widgets.dart';

class PaymentWeb3dsScreen extends StatelessWidget {
  final String? initialUrl;
  final String? htmlContent;
  final String returnUrl;

  const PaymentWeb3dsScreen({
    super.key,
    this.initialUrl,
    this.htmlContent,
    required this.returnUrl,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
