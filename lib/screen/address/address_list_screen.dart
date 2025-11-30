import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/address_service.dart';
import '../../services/error/error_manager.dart';
import '../../services/auth/auth_provider.dart';
import 'address_form_screen.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final _addressService = AddressService();
  bool _loading = true;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) throw Exception("Kullanıcı bulunamadı");
      final list = await _addressService.getAddresses(userId.toString());
      setState(() => _addresses = list);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parsed)),
        );
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Adresi Sil"),
        content: const Text("Bu adresi silmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _addressService.deleteAddress(id);
      await _load();
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
    }
  }

  Future<void> _openForm({Map<String, dynamic>? address}) async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(userId: userId.toString(), address: address),
      ),
    );
    if (result == true) {
      await _load();
      if (mounted) {
        Future.microtask(() => Scrollable.ensureVisible(context));
      }
    }
  }

  Widget _addressCard(Map<String, dynamic> a) {
    final typeLabel = (a["address_type"] ?? "").toString().toLowerCase() == "kurumsal" ? "Kurumsal" : "Bireysel";
    final isCorporate = typeLabel == "Kurumsal";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Text(
                typeLabel,
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == "edit") _openForm(address: a);
                  if (v == "delete") _delete(a["id"] as int);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: "edit", child: Text("Düzenle")),
                  PopupMenuItem(value: "delete", child: Text("Sil")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a["address_name"] ?? "",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "${a["district"] ?? ""} / ${a["city"] ?? ""} - ${a["country"] ?? ""}",
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(a["full_address"] ?? "", style: const TextStyle(color: Colors.black87)),
          if ((a["postal_code"] ?? "").toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("Posta Kodu: ${a["postal_code"]}", style: const TextStyle(color: Colors.black54)),
          ],
          if (isCorporate && ((a["company_name"] ?? "").toString().isNotEmpty || (a["tax_or_tc_no"] ?? "").toString().isNotEmpty)) ...[
            const SizedBox(height: 12),
            if ((a["company_name"] ?? "").toString().isNotEmpty)
              Text("Firma: ${a["company_name"]}", style: const TextStyle(color: Colors.black87)),
            if ((a["tax_or_tc_no"] ?? "").toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Vergi No / TC: ${a["tax_or_tc_no"]}", style: const TextStyle(color: Colors.black87)),
              ),
            if ((a["tax_address"] ?? "").toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Vergi Adresi: ${a["tax_address"]}", style: const TextStyle(color: Colors.black87)),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openForm(address: a),
                  child: const Text("Düzenle"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _delete(a["id"] as int),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Sil"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Adreslerim"),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _addresses.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.location_off_outlined, size: 48, color: Colors.black45),
                                  SizedBox(height: 12),
                                  Text(
                                    "Adres bulunamadı.",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 6),
                                  Text("Yeni bir adres ekleyebilirsiniz."),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _addresses.length,
                          itemBuilder: (_, i) => _addressCard(_addresses[i]),
                        ),
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text("Yeni Adres Ekle"),
            onPressed: () => _openForm(),
          ),
        ),
      ),
    );
  }
}
