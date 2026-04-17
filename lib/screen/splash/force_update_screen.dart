import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_version_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  final AppVersionGate gate;

  const ForceUpdateScreen({super.key, required this.gate});

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(gate.storeUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Güncelleme sayfası açılamadı.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB71C1C);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBEAEA),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFECC0C0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      "assets/images/logo.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Güncelleme Gerekli",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Color(0xFF111111),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Uygulamanın bu sürümü artık desteklenmiyor. Devam etmek için son sürümü yüklemeniz gerekiyor.",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6D6D6D),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7E7E7)),
                    ),
                    child: Column(
                      children: [
                        _infoRow("Mevcut sürüm", _formatCurrentVersion()),
                        const SizedBox(height: 8),
                        _infoRow("Gerekli sürüm", gate.requiredVersion ?? "-"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _openStore(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Güncelle",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Web sürümünde güncelleme için sayfayı yenileyin.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrentVersion() {
    final build = gate.currentBuildNumber.trim();
    return build.isEmpty
        ? gate.currentVersion
        : "${gate.currentVersion}+${gate.currentBuildNumber}";
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6D6D6D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF222222),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
