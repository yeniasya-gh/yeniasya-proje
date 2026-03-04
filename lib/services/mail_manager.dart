import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth/auth_token_store.dart';
import '../config/mail_config.dart';

class MailDeliveryException implements Exception {
  final String userMessage;
  final String debugMessage;
  final int? statusCode;
  final bool retryable;

  const MailDeliveryException({
    required this.userMessage,
    required this.debugMessage,
    this.statusCode,
    this.retryable = false,
  });

  @override
  String toString() {
    final code = statusCode == null ? "-" : statusCode.toString();
    return "MailDeliveryException(status=$code, retryable=$retryable, message=$debugMessage)";
  }
}

class MailManager {
  MailManager._() {
    mailApiUrl = MailConfig.mailApiUrl;
    mailOrderSummaryApiUrl = MailConfig.mailOrderSummaryApiUrl;
    mailWelcomeApiUrl = MailConfig.mailWelcomeApiUrl;
    mailToken = MailConfig.mailToken;
    fromName = MailConfig.fromName;
  }

  static final MailManager instance = MailManager._();

  String mailApiUrl = "";
  String mailOrderSummaryApiUrl = "";
  String mailWelcomeApiUrl = "";
  String mailToken = "";
  String fromName = "Yeni Asya";

  bool get _isConfigured => mailApiUrl.isNotEmpty && mailToken.isNotEmpty;

  static const int _maxAttempts = 3;

  Future<void> sendWelcomeEmail({
    required String to,
    required String name,
  }) async {
    await _sendWelcomeMailOnce(expectedEmail: to, expectedName: name);
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
    final token = AuthTokenStore.token?.trim();
    if (mailOrderSummaryApiUrl.isEmpty) {
      throw const MailDeliveryException(
        userMessage: "E-posta servisi yapılandırılamadı.",
        debugMessage: "Order summary endpoint is not configured.",
      );
    }
    if (token == null || token.isEmpty) {
      throw const MailDeliveryException(
        userMessage: "Oturum süresi dolduğu için e-posta gönderilemedi.",
        debugMessage: "Auth token missing for order summary mail.",
      );
    }

    final normalizedItems = items
        .map(
          (item) => <String, dynamic>{
            "title": (item["title"] ?? "").toString(),
            "quantity": item["quantity"],
            "line_total": item["line_total"] ?? item["unit_price"] ?? 0,
          },
        )
        .toList(growable: false);

    final body = jsonEncode({
      "orderId": orderId,
      "total": total,
      "items": normalizedItems,
      // Sunucu bu iki alanı zorunlu kullanmaz; log/debug için gönderiyoruz.
      "expectedEmail": to,
      "expectedName": name,
    });

    // ignore: avoid_print
    print("📧 [Mail] Sipariş özeti gönderim isteği -> orderId=$orderId");
    await _postWithRetry(
      uri: Uri.parse(mailOrderSummaryApiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
      operationLabel: "order_summary",
    );
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
      throw const MailDeliveryException(
        userMessage: "E-posta servisi yapılandırılamadı.",
        debugMessage: "Mail API URL veya token eksik.",
      );
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
    print("📧 [Mail] Gönderim başlıyor -> $to | $subject");
    await _postWithRetry(
      uri: Uri.parse(mailApiUrl),
      headers: {
        "Content-Type": "application/json",
        "x-mail-token": mailToken,
        if (AuthTokenStore.token != null && AuthTokenStore.token!.isNotEmpty)
          "Authorization": "Bearer ${AuthTokenStore.token}",
      },
      body: jsonEncode(payload),
      operationLabel: "generic_mail",
    );
  }

  Future<void> _sendWelcomeMailOnce({
    required String expectedEmail,
    required String expectedName,
  }) async {
    final token = AuthTokenStore.token?.trim();
    if (mailWelcomeApiUrl.isEmpty) {
      throw const MailDeliveryException(
        userMessage: "E-posta servisi yapılandırılamadı.",
        debugMessage: "Welcome mail endpoint is not configured.",
      );
    }
    if (token == null || token.isEmpty) {
      throw const MailDeliveryException(
        userMessage: "Oturum süresi dolduğu için e-posta gönderilemedi.",
        debugMessage: "Auth token missing for welcome mail.",
      );
    }

    // ignore: avoid_print
    print(
      "📧 [Mail] Welcome gönderim isteği -> $expectedEmail | $expectedName",
    );
    await _postWithRetry(
      uri: Uri.parse(mailWelcomeApiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: "{}",
      operationLabel: "welcome_mail",
    );
  }

  Future<void> _postWithRetry({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    required String operationLabel,
  }) async {
    MailDeliveryException? lastFailure;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await http.post(uri, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // ignore: avoid_print
          print("✅ [Mail] $operationLabel başarılı (attempt=$attempt)");
          return;
        }

        final retryable = _isRetryableStatus(response.statusCode);
        final failure = _mailFailureFromHttp(
          response: response,
          operationLabel: operationLabel,
          retryable: retryable,
        );
        lastFailure = failure;
        if (!retryable || attempt == _maxAttempts) {
          throw failure;
        }
      } catch (e) {
        final failure = e is MailDeliveryException
            ? e
            : _mailFailureFromException(
                error: e,
                operationLabel: operationLabel,
              );
        lastFailure = failure;
        if (!failure.retryable || attempt == _maxAttempts) {
          throw failure;
        }
      }

      final delayMs = 300 * attempt;
      // ignore: avoid_print
      print(
        "🟨 [Mail] $operationLabel başarısız (attempt=$attempt), ${delayMs}ms sonra tekrar denenecek...",
      );
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    throw lastFailure ??
        const MailDeliveryException(
          userMessage: "E-posta gönderimi tamamlanamadı.",
          debugMessage: "Unknown mail delivery error.",
        );
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 409 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  MailDeliveryException _mailFailureFromHttp({
    required http.Response response,
    required String operationLabel,
    required bool retryable,
  }) {
    final status = response.statusCode;
    final body = _truncateBody(_extractErrorBody(response.body));
    String userMessage;
    if (status == 400 || status == 422) {
      userMessage =
          "E-posta isteği geçersiz olduğu için gönderim tamamlanamadı.";
    } else if (status == 401 || status == 403) {
      userMessage =
          "E-posta yetkilendirmesi başarısız olduğu için gönderim tamamlanamadı.";
    } else if (status == 404) {
      userMessage = "E-posta servisine erişilemedi.";
    } else if (status >= 500) {
      userMessage =
          "E-posta servisine şu an ulaşılamıyor. Lütfen daha sonra tekrar deneyin.";
    } else {
      userMessage = "E-posta gönderimi tamamlanamadı. Lütfen tekrar deneyin.";
    }

    return MailDeliveryException(
      userMessage: userMessage,
      debugMessage:
          "[$operationLabel] HTTP $status response received. body=$body",
      statusCode: status,
      retryable: retryable,
    );
  }

  MailDeliveryException _mailFailureFromException({
    required Object error,
    required String operationLabel,
  }) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    final retryable =
        lower.contains("socketexception") ||
        lower.contains("connection closed") ||
        lower.contains("failed host lookup") ||
        lower.contains("timed out") ||
        lower.contains("timeout") ||
        lower.contains("network");

    return MailDeliveryException(
      userMessage: retryable
          ? "İnternet bağlantısı nedeniyle e-posta gönderimi tamamlanamadı. Lütfen tekrar deneyin."
          : "E-posta gönderimi sırasında beklenmeyen bir hata oluştu.",
      debugMessage: "[$operationLabel] request failed: $raw",
      retryable: retryable,
    );
  }

  String _extractErrorBody(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) return "";
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final errorText = decoded["error"]?.toString().trim();
        if (errorText != null && errorText.isNotEmpty) return errorText;
        final messageText = decoded["message"]?.toString().trim();
        if (messageText != null && messageText.isNotEmpty) return messageText;
      }
      return decoded.toString();
    } catch (_) {
      return trimmed;
    }
  }

  String _truncateBody(String value) {
    if (value.length <= 300) return value;
    return "${value.substring(0, 300)}...";
  }

  String _htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), " ")
        .replaceAll(RegExp(r'\s+'), " ")
        .trim();
  }
}
