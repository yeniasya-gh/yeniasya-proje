import 'package:flutter/material.dart';
import '../../services/address_service.dart';
import '../../services/error/error_manager.dart';

class AddressFormScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? address;

  const AddressFormScreen({super.key, required this.userId, this.address});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressService = AddressService();

  String addressType = "bireysel";
  String addressName = "";
  String country = "Türkiye";
  String city = "";
  String district = "";
  String fullAddress = "";
  String? postalCode;
  String? taxOrTcNo;
  String? taxAddress;
  String? companyName;

  bool get _isCorporate => addressType == "kurumsal";

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    if (a != null) {
      addressType = a["address_type"] ?? addressType;
      addressName = a["address_name"] ?? "";
      country = a["country"] ?? country;
      city = a["city"] ?? "";
      district = a["district"] ?? "";
      fullAddress = a["full_address"] ?? "";
      postalCode = a["postal_code"];
      taxOrTcNo = a["tax_or_tc_no"];
      taxAddress = a["tax_address"];
      companyName = a["company_name"];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      if (widget.address == null) {
        await _addressService.addAddress(
          userId: widget.userId,
          addressType: addressType,
          addressName: addressName,
          country: country,
          city: city,
          district: district,
          fullAddress: fullAddress,
          postalCode: postalCode,
          taxOrTcNo: taxOrTcNo,
          taxAddress: taxAddress,
          companyName: companyName,
        );
      } else {
        await _addressService.updateAddress(
          id: widget.address!["id"],
          addressType: addressType,
          addressName: addressName,
          country: country,
          city: city,
          district: district,
          fullAddress: fullAddress,
          postalCode: postalCode,
          taxOrTcNo: taxOrTcNo,
          taxAddress: taxAddress,
          companyName: companyName,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final parsed = ErrorManager.parseGraphQLError(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parsed)));
    }
  }

  Widget _typeChip(String label, String value, IconData icon) {
    final active = addressType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          addressType = value;
          if (value == "bireysel") {
            companyName = null;
            taxOrTcNo = null;
            taxAddress = null;
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E6CF6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? const Color(0xFF2E6CF6) : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : Colors.black54),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(widget.address == null ? "Yeni Adres Ekle" : "Adresi Düzenle"),
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Fatura Tipi", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _typeChip("Bireysel", "bireysel", Icons.person_outline),
                    const SizedBox(width: 8),
                    _typeChip("Kurumsal", "kurumsal", Icons.business_center_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text("Adres Başlığı", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: addressName,
                  decoration: const InputDecoration(labelText: "Adres Adı *"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                  onSaved: (v) => addressName = v!.trim(),
                ),
                const SizedBox(height: 16),
                const Text("Adres Bilgileri", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: country,
                  decoration: const InputDecoration(labelText: "Ülke *"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                  onSaved: (v) => country = v!.trim(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: city,
                        decoration: const InputDecoration(labelText: "İl *"),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                        onSaved: (v) => city = v!.trim(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: district,
                        decoration: const InputDecoration(labelText: "İlçe *"),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                        onSaved: (v) => district = v!.trim(),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: fullAddress,
                  decoration: const InputDecoration(labelText: "Adres *"),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Zorunlu" : null,
                  onSaved: (v) => fullAddress = v!.trim(),
                ),
                TextFormField(
                  initialValue: postalCode,
                  decoration: const InputDecoration(labelText: "Posta Kodu"),
                  onSaved: (v) => postalCode = v?.trim().isEmpty == true ? null : v?.trim(),
                ),
                if (_isCorporate) ...[
                  const SizedBox(height: 16),
                  const Text("Fatura Bilgileri", style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: companyName,
                    decoration: const InputDecoration(labelText: "Firma Adı *"),
                    validator: (v) {
                      if (!_isCorporate) return null;
                      return (v == null || v.trim().isEmpty) ? "Zorunlu" : null;
                    },
                    onSaved: (v) => companyName = v?.trim(),
                  ),
                  TextFormField(
                    initialValue: taxOrTcNo,
                    decoration: const InputDecoration(labelText: "Vergi No / TC Kimlik *"),
                    validator: (v) {
                      if (!_isCorporate) return null;
                      return (v == null || v.trim().isEmpty) ? "Zorunlu" : null;
                    },
                    onSaved: (v) => taxOrTcNo = v?.trim(),
                  ),
                  TextFormField(
                    initialValue: taxAddress,
                    decoration: const InputDecoration(labelText: "Vergi Adresi *"),
                    maxLines: 2,
                    validator: (v) {
                      if (!_isCorporate) return null;
                      return (v == null || v.trim().isEmpty) ? "Zorunlu" : null;
                    },
                    onSaved: (v) => taxAddress = v?.trim(),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Adresi Kaydet"),
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
