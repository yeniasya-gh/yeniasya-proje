import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_token_store.dart';
import '../config/mail_config.dart';

class MailManager {
  MailManager._() {
    mailApiUrl = MailConfig.mailApiUrl;
    mailToken = MailConfig.mailToken;
    fromName = MailConfig.fromName;
  }

  static final MailManager instance = MailManager._();

  /// CDN mail servisi yapılandırması
  String mailApiUrl = "";
  String mailToken = "";
  String fromName = "Yeni Asya";

  bool get _isConfigured => mailApiUrl.isNotEmpty && mailToken.isNotEmpty;

  Future<void> sendWelcomeEmail({
    required String to,
    required String name,
  }) async {
    final subject = "Yeni Asya’ya hoş geldiniz, $name";
    final html = _wrapTemplate("""
      <h2>Merhaba $name,</h2>
      <p>Aramıza katıldığınız için teşekkürler. Yeni Asya uygulamasında dijital içeriklerinize hemen ulaşabilirsiniz.</p>
      <p>Keyifli okumalar!</p>
    """);
    await _sendMail(to: to, subject: subject, html: html);
  }

  Future<void> sendResetPassword({
    required String to,
    required String name,
    required String resetLink,
  }) async {
    final subject = "Şifre sıfırlama talebiniz";
    final html = _wrapTemplate("""
      <h2>Merhaba $name,</h2>
      <p>Şifrenizi sıfırlamak için aşağıdaki butona tıklayın:</p>
      <p style="margin:16px 0;">
        <a href="$resetLink" style="background:#d32f2f;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;">Şifreyi Sıfırla</a>
      </p>
      <p>Bağlantı çalışmazsa şu adresi kopyalayın: <br><small>$resetLink</small></p>
    """);
    await _sendMail(to: to, subject: subject, html: html);
  }

  Future<void> sendOrderSummary({
    required String to,
    required String name,
    required String orderId,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    final subject = "Sipariş #$orderId alındı";
    final itemsHtml = items.map((i) {
      final title = i["title"] ?? "-";
      final qty = i["quantity"] ?? 1;
      final price = i["line_total"] ?? i["unit_price"] ?? 0;
      return "<tr><td>$title</td><td align='center'>$qty</td><td align='right'>₺${price.toString()}</td></tr>";
    }).join();

    final html = _wrapTemplate("""
      <h2>Teşekkürler $name,</h2>
      <p>Siparişiniz alındı. Detaylar aşağıda:</p>
      <table width="100%" cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
        <thead>
          <tr style="background:#f5f5f5;">
            <th align="left">Ürün</th>
            <th align="center">Adet</th>
            <th align="right">Tutar</th>
          </tr>
        </thead>
        <tbody>
          $itemsHtml
        </tbody>
      </table>
      <p style="text-align:right;font-weight:bold;margin-top:12px;">Toplam: ₺${total.toStringAsFixed(2)}</p>
      <p>İyi okumalar dileriz.</p>
    """);

    await _sendMail(to: to, subject: subject, html: html);
  }

  String _wrapTemplate(String body) {
    final brand = fromName;
    return """
    <div style="font-family:Arial, sans-serif; background:#fafafa; padding:16px;">
      <div style="max-width:640px;margin:0 auto;background:#fff;border-radius:10px;box-shadow:0 6px 20px rgba(0,0,0,0.05);padding:20px;">
        <div style="text-align:center;margin-bottom:16px;">
          <h1 style="color:#d32f2f;margin:0;">$brand</h1>
        </div>
        $body
        <hr style="margin:20px 0;border:none;border-top:1px solid #eee;">
        <p style="font-size:12px;color:#777;text-align:center;">Bu e-posta otomatik gönderilmiştir.</p>
      </div>
    </div>
    """;
  }

  Future<void> _sendMail({
    required String to,
    required String subject,
    required String html,
  }) async {
    if (!_isConfigured) {
      // ignore: avoid_print
      print("🔴 [Mail] Mail servisi yapılandırması eksik, mail gönderilmedi.");
      return;
    }

    final payload = {
      "to": to,
      "fromName": fromName,
      "from_name": fromName,
      "subject": subject,
      "text": _htmlToText(html),
      "html": html,
    };

    // ignore: avoid_print
    print("📧 [Mail] Gönderim başlıyor -> $to | $subject | ${payload["text"]}");
    try {
      await _postJson(payload);
      // ignore: avoid_print
      print("✅ [Mail] Gönderildi -> $to");
    } catch (e) {
      // ignore: avoid_print
      print("🔴 [Mail] Gönderilemedi -> $to | Hata: $e");
      rethrow;
    }
  }

  Future<void> _postJson(Map<String, dynamic> payload) async {
    final headers = {
      "Content-Type": "application/json",
      "x-mail-token": mailToken,
      if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
        "Authorization": "Bearer ${AuthTokenStore.token}",
    };
    final response = await http.post(
      Uri.parse(mailApiUrl),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("Status: ${response.statusCode} Body: ${response.body}");
    }
  }

  /// Çok basit bir HTML temizleyici; CDNe text alanı göndermek için kullanılıyor.
  String _htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), " ")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();
  }
}
