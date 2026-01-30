import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/payment_service.dart';
import '../../services/auth/auth_provider.dart';

class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  final _paymentService = PaymentService();
  bool _loading = true;
  List<SavedCard> _cards = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    final user = context.read<AuthProvider>().user;
    final customerId = user?.payUniqe?.trim();

    if (customerId == null || customerId.isEmpty) {
      setState(() {
        _loading = false;
        _cards = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cards = await _paymentService.queryCards(customer: customerId);
      if (mounted) {
        setState(() {
          _cards = cards;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst("Exception: ", "");
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteCard(SavedCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kartı Sil"),
        content: Text("${card.cardName ?? card.panMasked ?? "Bu kart"} silinecek. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _paymentService.deleteCard(cardToken: card.cardToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kart başarıyla silindi.")));
        _fetchCards();
      }
    } catch (e) {
      if (mounted) {
        _showAlert("Hata", e.toString().replaceFirst("Exception: ", ""));
      }
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text("Kayıtlı Kartlarım", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchCards, child: const Text("Tekrar Dene")),
                      ],
                    ),
                  ),
                )
              : _cards.isEmpty
                  ? const Center(child: Text("Kayıtlı kartınız bulunmamaktadır."))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final card = _cards[i];
                        final brand = (card.cardBrand ?? "").trim();
                        final last4 = (card.panLast4 ?? "").trim();
                        final expiry = (card.cardExpiry ?? "").trim();
                        final title = (card.cardName ?? "").trim();
                        final subtitle = [
                          if (brand.isNotEmpty) brand,
                          if (last4.isNotEmpty) "•••• $last4",
                          if (expiry.isNotEmpty) "SKT $expiry",
                        ].join(" · ");

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.credit_card, color: Colors.red.shade700),
                            ),
                            title: Text(
                              title.isNotEmpty && title != "-" ? title : (card.cardOwner ?? "Kayıtlı Kart"),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteCard(card),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
