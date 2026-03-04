import 'package:flutter/material.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String total;
  final String? mailWarning;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.total,
    this.mailWarning,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Sipariş Tamamlandı",
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 1,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 72),
                const SizedBox(height: 12),
                const Text(
                  "Siparişiniz oluşturuldu!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Sipariş No: $orderId"),
                const SizedBox(height: 4),
                Text(
                  "Ödenen Tutar: ₺$total",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (mailWarning != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mailWarning!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Anasayfaya Dön"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
