import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EC),
      appBar: AppBar(
        title: const Text("Gizlilik Politikası"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: _PrivacyContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFFC1452F),
    );
    const bodyStyle = TextStyle(fontSize: 15, height: 1.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Veri Sorumlusu",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Bu gizlilik politikası Yeni Asya uygulaması için hazırlanmıştır.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Toplanan Veriler",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Uygulama, hizmeti sunmak ve geliştirmek için gerekli olabilecek temel "
          "bilgileri işleyebilir. Bu kapsamda uygulama içi etkileşimler, cihaz ve "
          "kullanım verileri ile kullanıcı tarafından paylaşılan bilgiler "
          "değerlendirilebilir.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Verilerin İşlenme Amaçları",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "1) Uygulamanın çalıştırılması ve temel fonksiyonların sağlanması.\n"
          "2) Hata tespiti, performans iyileştirmeleri ve kullanıcı deneyiminin "
          "geliştirilmesi.\n"
          "3) Destek taleplerinin yönetimi ve iletişim süreçlerinin yürütülmesi.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Hukuki Sebep",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Kişisel veriler, yürürlükteki mevzuata uygun olarak; sözleşmenin "
          "kurulması veya ifası, hukuki yükümlülüklerin yerine getirilmesi ve "
          "meşru menfaat kapsamında işlenebilir.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Verilerin Aktarımı",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Veriler, hizmetin sunulması için gerekli olması halinde ve ilgili "
          "mevzuata uygun şekilde sınırlı olarak iş ortakları veya teknik hizmet "
          "sağlayıcılarla paylaşılabilir.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Veri Güvenliği",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Kişisel verilerin güvenliği için uygun teknik ve idari tedbirler "
          "uygulanır. Buna rağmen, internet üzerinden yapılan veri aktarımının "
          "tamamen güvenli olduğu garanti edilemez.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Saklama Süresi",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Veriler, işleme amaçları için gerekli olan süre boyunca ve ilgili "
          "mevzuatta öngörülen saklama sürelerine uygun şekilde muhafaza edilir.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Kullanıcı Hakları",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Kişisel verilerinizle ilgili olarak bilgi talep etme, düzeltme, silme "
          "ve itiraz etme gibi haklara sahipsiniz. Taleplerinizi aşağıdaki "
          "iletişim kanallarından iletebilirsiniz.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Değişiklikler",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "Bu politika zaman zaman güncellenebilir. Güncellemeler bu sayfada "
          "yayımlanır.",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "İletişim",
          style: titleStyle,
        ),
        SizedBox(height: 8),
        Text(
          "E-posta: app@yeniasya.com.tr\n"
          "Telefon: 0 (212) 655 88 59\n"
          "Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul",
          style: bodyStyle,
        ),
        SizedBox(height: 20),
        Text(
          "Son güncelleme: 3 Şubat 2026",
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
