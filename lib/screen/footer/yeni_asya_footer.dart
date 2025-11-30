import 'package:flutter/material.dart';

class YeniAsyaFooter extends StatelessWidget {
  const YeniAsyaFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isWebWide = MediaQuery.of(context).size.width > 900;
    final isTablet = MediaQuery.of(context).size.width > 600 &&
        MediaQuery.of(context).size.width <= 900;

    return Container(
      width: double.infinity,
      color: const Color(0xFF0F111A),
      padding: EdgeInsets.symmetric(
        horizontal: isWebWide ? 48 : (isTablet ? 32 : 16),
        vertical: isWebWide ? 28 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isWebWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isWebWide
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.newspaper_rounded,
                            color: Colors.red, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "Yeni Asya",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Dijital yayın dünyasının öncü platformu. Binlerce içeriğe anında erişim.",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: const [
                        Icon(Icons.facebook_rounded,
                            color: Colors.white70, size: 20),
                        SizedBox(width: 12),
                        Icon(Icons.alternate_email,
                            color: Colors.white70, size: 20),
                        SizedBox(width: 12),
                        Icon(Icons.camera_alt_outlined,
                            color: Colors.white70, size: 20),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20, width: 20),

              Flexible(
                flex: 1,
                child: _footerSection(
                  "Kategoriler",
                  [
                    "Dergiler",
                    "Kitaplar",
                    "Gazeteler",
                    "Abonelikler",
                  ],
                  context,
                ),
              ),

              const SizedBox(height: 20, width: 20),

              // Destek
              Flexible(
                flex: 1,
                child: _footerSection(
                  "Destek",
                  [
                    "Yardım Merkezi",
                    "İletişim",
                    "SSS",
                    "Geri Bildirim",
                  ],
                  context,
                ),
              ),

              const SizedBox(height: 20, width: 20),

              // Yasal
              Flexible(
                flex: 1,
                child: _footerSection(
                  "Yasal",
                  [
                    "Gizlilik Politikası",
                    "Kullanım Koşulları",
                    "Çerez Politikası",
                    "KVKK",
                  ],
                  context,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Alt çizgi
          Divider(color: Colors.white24, thickness: 0.3),

          const SizedBox(height: 16),

          // Copyright
          const Center(
            child: Text(
              "© 2024 Yeni Asya. Tüm hakları saklıdır.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerSection(String title, List<String> items, BuildContext context) {
    final contentMap = <String, String>{
      "Dergiler": "Dergiler sayfası için örnek içerik. Tüm dergi ve abonelik paketlerini burada bulabilirsiniz.",
      "Kitaplar": "Kitaplar sayfası için örnek içerik. Popüler ve yeni çıkan kitaplar listesi.",
      "Gazeteler": "Gazeteler sayfası için örnek içerik. Günlük gazetelere ve abonelik planlarına buradan erişin.",
      "Abonelikler": "Abonelikler sayfası için örnek içerik. Tüm abonelik paketlerini ve avantajlarını inceleyin.",
      "Yardım Merkezi": "Yardım Merkezi için örnek içerik. Sık karşılaşılan sorunlar ve çözümler.",
      "İletişim": "İletişim sayfası için örnek içerik. Bize ulaşın: destek@yeniasya.com",
      "SSS": "Sıkça Sorulan Sorular. Üyelik, ödeme ve içerik hakkında sık sorular.",
      "Geri Bildirim": "Geri bildirimlerinizi bizimle paylaşın. İyileştirmeler için her zaman açığız.",
      "Gizlilik Politikası":
          "Yeni Asya olarak kişisel verilerinizi 6698 sayılı KVKK ve ilgili mevzuata uygun olarak işleriz. Hizmet sunumu, güvenlik, istatistik ve geliştirme amaçlarıyla gerekli olduğu ölçüde veri toplar, saklar ve üçüncü taraflarla yalnızca zorunlu hallerde (barındırma, analitik, ödeme vb.) ve gizlilik yükümlülükleri altında paylaşırız. Verilerinize erişim, düzeltme, silme ve itiraz haklarınızı destek@yeniasya.com üzerinden kullanabilirsiniz.",
      "Kullanım Koşulları":
          "Yeni Asya platformunu kullanarak, üyelik sırasında verdiğiniz bilgilerin doğru olduğunu, telif haklarına saygı göstereceğinizi, hesabınızı güvenli tutacağınızı ve içerikleri ticari olmayan kişisel kullanım sınırları içinde kullanacağınızı kabul edersiniz. Hizmetler önceden haber vermeksizin güncellenebilir, fiyatlar değişebilir, suistimal tespitinde hesaplar kısıtlanabilir. Yerel hukuk ve mevzuat geçerlidir.",
      "Çerez Politikası":
          "Yeni Asya; oturumunuzu korumak, tercihlerinizi hatırlamak, performansı ve kullanım istatistiklerini ölçmek için zorunlu ve analitik çerezler kullanır. Üçüncü taraf çerezler yalnızca analitik ve iyileştirme amaçlıdır. Tarayıcınızdan çerez ayarlarınızı değiştirebilir veya silebilirsiniz; çerezleri kapatmanız bazı özelliklerin kısıtlanmasına yol açabilir.",
      "KVKK":
          "Veri Sorumlusu: Yeni Asya. İşleme Amaçları: Üyelik yönetimi, ödeme ve faturalama, güvenlik, hukuki yükümlülüklerin yerine getirilmesi, istatistik ve geliştirme. Toplama Yöntemi ve Hukuki Sebep: Elektronik kanallar (web/mobil) üzerinden açık rıza, sözleşme kurulumu/ifası, meşru menfaat ve hukuki yükümlülükler. Haklarınız: KVKK md.11 kapsamında bilgilendirme, düzeltme, silme, itiraz ve veri taşınabilirliği taleplerinizi destek@yeniasya.com adresine iletebilirsiniz.",
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: InkWell(
              onTap: () {
                final content = contentMap[item] ?? "Bu sayfa için içerik yakında eklenecek.";
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StaticInfoPage(title: item, content: content),
                  ),
                );
              },
              child: Text(
                item,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StaticInfoPage extends StatelessWidget {
  final String title;
  final String content;

  const StaticInfoPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(title),
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ),
      ),
    );
  }
}
