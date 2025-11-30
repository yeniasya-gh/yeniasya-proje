import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/address_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/cart/cart_provider.dart';
import '../../models/cart_item.dart';
import '../address/address_form_screen.dart';
import 'payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressService = AddressService();
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;
  int? _deliveryId;
  int? _billingId;
  bool _sameBilling = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) throw Exception("Kullanıcı bulunamadı");
      final list = await _addressService.getAddresses(userId.toString());
      setState(() {
        _addresses = list;
        if (list.isNotEmpty) {
          _deliveryId = list.first["id"] as int;
          _billingId = list.first["id"] as int;
        }
      });
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _addAddress() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(userId: userId.toString()),
      ),
    );
    if (result == true) {
      await _loadAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ödeme", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 1,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _orderSummary(cart.items, cart.totalPrice),
                    const SizedBox(height: 16),
                    _addressSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: (_deliveryId != null && (_sameBilling || _billingId != null))
                ? () {
                    final userId = context.read<AuthProvider>().user?.id?.toString();
                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Kullanıcı bulunamadı.")),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          deliveryAddressId: _deliveryId!,
                          billingAddressId: _sameBilling ? _deliveryId! : _billingId!,
                          userId: userId,
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Ödemeye Geç"),
          ),
        ),
      ),
    );
  }

  Widget _orderSummary(List<CartItem> items, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sipariş Özeti", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${i.title} x${i.quantity}",
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  Text("₺${(i.price * i.quantity).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Toplam", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("₺${total.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addressSection() {
    if (_addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Adresler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text("Kayıtlı adres bulunamadı."),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addAddress,
              icon: const Icon(Icons.add),
              label: const Text("Adres Ekle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6CF6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Teslimat Adresi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _deliveryId,
            items: _addresses
                .map(
                  (a) => DropdownMenuItem<int>(
                    value: a["id"] as int,
                    child: Text(a["address_name"] ?? "Adres"),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _deliveryId = v),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _sameBilling,
            onChanged: (v) => setState(() => _sameBilling = v ?? true),
            title: const Text("Fatura adresi teslimat adresi ile aynı"),
          ),
          if (!_sameBilling) ...[
            const SizedBox(height: 8),
            const Text("Fatura Adresi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _billingId,
              items: _addresses
                  .map(
                    (a) => DropdownMenuItem<int>(
                      value: a["id"] as int,
                      child: Text(a["address_name"] ?? "Adres"),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _billingId = v),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _addAddress,
            icon: const Icon(Icons.add),
            label: const Text("Yeni adres ekle"),
          ),
        ],
      ),
    );
  }
}
