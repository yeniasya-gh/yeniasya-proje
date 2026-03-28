import 'dart:async';

import 'app_error_reporter.dart';

class ErrorManager {
  static String parseGraphQLError(String errorMessage) {
    final msg = errorMessage.toLowerCase();
    final cleaned = errorMessage.replaceFirst("Exception: ", "").trim();

    unawaited(
      AppErrorReporter.instance.reportMessage(
        service: "App/ErrorManager",
        operation: "parseGraphQLError",
        message: cleaned,
        payload: {"raw": errorMessage},
      ),
    );

    const passThroughMarkers = [
      "yükleme başarısız",
      "yükleme zaman aşımına uğradı",
      "çok fazla yükleme denemesi",
      "oturum doğrulanamadı",
      "cdn yükleme servisi",
      "dosya 50mb sınırını aşıyor",
      "izin verilmeyen dosya tipi",
      "kapak görseli oluşturulamadı",
    ];

    if (passThroughMarkers.any((marker) => msg.contains(marker))) {
      return cleaned;
    }

    // 🔥 Eğer zaten kullanıcıya gösterilebilir bir hata ise → direkt döndür
    if (msg.contains("zaten kayıtlı") || msg.contains("telefon")) {
      return cleaned;
    }

    // 📌 Unique violation - phone
    if (msg.contains("users_phone_key") ||
        msg.contains(
          "duplicate key value violates unique constraint \"users_phone_key\"",
        )) {
      return "Bu telefon numarası zaten kayıtlı.";
    }

    // 📌 Unique violation - email
    if (msg.contains("users_email_key")) {
      return "Bu e-posta adresi zaten kayıtlı.";
    }

    // 📌 Unique violation - generic
    if (msg.contains("duplicate key value")) {
      return "Bu bilgi zaten kayıtlı.";
    }

    // 📌 NOT NULL violation
    if (msg.contains("null value") &&
        msg.contains("violates not-null constraint")) {
      return "Zorunlu alanlardan biri boş bırakılamaz.";
    }

    // 📌 Connection / network issues
    if (msg.contains("failed host lookup") ||
        msg.contains("socketexception") ||
        msg.contains("network")) {
      return "Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.";
    }

    if (msg.contains("timeoutexception") ||
        msg.contains("future not completed") ||
        msg.contains("zaman aşımı")) {
      return "Sunucu yanıt vermedi. Lütfen tekrar deneyin.";
    }

    // 📌 Default fallback
    return "Bir hata oluştu. Lütfen tekrar deneyin.";
  }
}
