class MailConfig {
  /// CDN mail servis endpointleri (dart-define ile override edilebilir).
  static const mailApiUrl = String.fromEnvironment(
    "MAIL_API_URL",
    defaultValue: "https://cdn.yeniasyadigital.com/mail/send",
  );
  static const mailOrderSummaryApiUrl = String.fromEnvironment(
    "MAIL_ORDER_SUMMARY_API_URL",
    defaultValue: "https://cdn.yeniasyadigital.com/mail/order-summary",
  );
  static const mailWelcomeApiUrl = String.fromEnvironment(
    "MAIL_WELCOME_API_URL",
    defaultValue: "https://cdn.yeniasyadigital.com/mail/welcome",
  );
  static const mailToken = String.fromEnvironment(
    "MAIL_API_TOKEN",
    defaultValue: "",
  );
  static const fromName = String.fromEnvironment(
    "MAIL_FROM_NAME",
    defaultValue: "Yeni Asya Dijital",
  );
}
