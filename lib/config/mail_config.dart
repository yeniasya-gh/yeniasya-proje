class MailConfig {
  /// SMTP bilgilerini doldurmalısınız. Gmail için:
  /// host: smtp.gmail.com, port: 587 (STARTTLS, useSsl=false) veya 465 (SSL, useSsl=true)
  /// username: gmail adresi veya gönderen hesap
  /// password: uygulama şifresi
  static const smtpHost = "smtp.gmail.com";
  static const smtpPort = 465;
  static const useSsl = false;
  static const smtpUsername = "aykut@coqode.com";
  static const smtpPassword = "Amasya.05";
  static const fromEmail = "aykut@coqode.com";
  static const fromName = "Yeni Asya";
}
