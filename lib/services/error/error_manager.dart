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
      "kullanıcı bulunamadı",
      "fcm token",
      "bildirim gönderilemedi",
      "geçerli fcm token",
    ];

    if (passThroughMarkers.any((marker) => msg.contains(marker))) {
      return cleaned;
    }

    // 🔥 Eğer zaten kullanıcıya gösterilebilir bir hata ise → direkt döndür
    if (msg.contains("zaten kayıtlı")) {
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

    // 📌 Promo code / campaign scope failures
    if (msg.contains("promosyon kodu") &&
        (msg.contains("geçerli değil") ||
            msg.contains("uygun değil") ||
            msg.contains("kullanılamaz"))) {
      return "Bu promosyon kodu seçili ürün için kullanılamaz.";
    }
    if (msg.contains("promosyon kodu") &&
        (msg.contains("bulunamadı") || msg.contains("geçersiz"))) {
      return "Promosyon kodu bulunamadı veya geçersiz.";
    }
    if (msg.contains("kod kullanım limiti dolmuş") ||
        msg.contains("kullanım limiti dolmuş")) {
      return "Bu promosyon kodunun kullanım limiti doldu.";
    }
    if (msg.contains("kod henüz aktif değil") ||
        msg.contains("henüz aktif değil")) {
      return "Bu promosyon kodu henüz aktif değil.";
    }

    // 📌 Payment / 3D secure failures
    if (msg.contains("err30002") ||
        msg.contains("responsecode\": \"99") ||
        msg.contains("response code: 99") ||
        msg.contains("declined")) {
      return "Kart onaylanmadı. Lütfen farklı bir kart deneyin.";
    }

    // 📌 Default fallback
    return "Bir hata oluştu. Lütfen tekrar deneyin.";
  }
}
