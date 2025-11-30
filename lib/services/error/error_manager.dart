class ErrorManager {
  static String parseGraphQLError(String errorMessage) {
    final msg = errorMessage.toLowerCase();

    // 🔥 Eğer zaten kullanıcıya gösterilebilir bir hata ise → direkt döndür
    if (msg.contains("zaten kayıtlı") || msg.contains("telefon")) {
      return errorMessage.replaceFirst("Exception: ", "").trim();
    }

    // 📌 Unique violation - phone
    if (msg.contains("users_phone_key") ||
        msg.contains("duplicate key value violates unique constraint \"users_phone_key\"")) {
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
    if (msg.contains("null value") && msg.contains("violates not-null constraint")) {
      return "Zorunlu alanlardan biri boş bırakılamaz.";
    }

    // 📌 Connection / network issues
    if (msg.contains("failed host lookup") ||
        msg.contains("socketexception") ||
        msg.contains("network")) {
      return "Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.";
    }

    // 📌 Default fallback
    return "Bir hata oluştu. Lütfen tekrar deneyin.";
  }
}