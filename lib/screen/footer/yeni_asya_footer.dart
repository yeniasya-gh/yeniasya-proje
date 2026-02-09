import 'package:flutter/material.dart';
import '../contact/contact_form.dart';

const String kCorporateContactInfo = '''
YENİ ASYA AŞ. — İLETİŞİM BİLGİLERİ

Yeni Asya AŞ.
Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul
E-posta: bilgiislem@yeniasya.com.tr
KEP: yeniasya@kep.gov.tr
''';

const String kPrivacyPolicyContent = '''
YENİ ASYA AŞ. — GİZLİLİK POLİTİKASI (KURUMSAL SON SÜRÜM)
Son Güncelleme Tarihi: …/…/2026
Yayınlayan: Yeni Asya AŞ.

1. Giriş ve Amaç
Bu Gizlilik Politikası, Yeni Asya AŞ. ("Şirket") tarafından işletilen yeniasya.com.tr internet sitesi ile Yeni Asya eGazete mobil uygulaması üzerinden elde edilen kişisel verilerin işlenmesine ilişkin usul ve esasları açıklamak amacıyla hazırlanmıştır.
Şirket, kullanıcıların kişisel verilerinin gizliliğine ve güvenliğine önem verir; tüm veri işleme faaliyetleri KVKK, 5651, 6563, Türk Borçlar Kanunu ve ilgili ikincil düzenlemelere uygun şekilde yürütülür.

2. Veri Sorumlusu Bilgileri
Yeni Asya AŞ.
Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul
E-posta: bilgiislem@yeniasya.com.tr
KEP: yeniasya@kep.gov.tr

3. İşlenen Kişisel Veri Kategorileri
- Kimlik Bilgileri: Ad, soyad
- İletişim Bilgileri: E-posta, telefon
- Üyelik ve İşlem Bilgileri: Üyelik kayıtları, abonelik işlemleri
- Cihaz ve Teknik Veriler: IP adresi, tarayıcı bilgisi, log kayıtları
- Çerez Verileri: Zorunlu, performans, reklam çerezleri
- Talep/Şikayet Verileri

4. Kişisel Verilerin İşlenme Amaçları
- Üyelik oluşturma ve hizmet sunumu
- Egazete erişimi ve dijital içerik sağlama
- Güvenlik, log kaydı ve dolandırıcılık önleme
- Kullanıcı deneyiminin iyileştirilmesi
- Pazarlama ve kampanya bilgilendirmeleri (açık rıza ile)
- Yasal yükümlülüklerin yerine getirilmesi

5. Kişisel Verilerin İşlenme Hukuki Sebepleri
Veriler;
- KVKK m.5/2 (a), (c), (ç), (e), (f)
- Açık rıza (KVKK m.5/1)
- 5651 sayılı Kanun
- 6563 sayılı Kanun
kapsamında işlenmektedir.

6. Kişisel Verilerin Aktarılması
Veriler;
- Sunucu ve altyapı hizmeti sağlayıcıları
- Tedarikçiler
- Yetkili kamu kurumları
ile paylaşılabilir.

7. Saklama Süreleri
- Log kayıtları: 5651 gereği 2 yıl
- Üyelik verileri: üyelik devam ettiği sürece
- Çerezler: türüne göre 1 gün - 2 yıl

8. KVKK Kapsamındaki Haklarınız
KVKK m.11 uyarınca;
- Bilgi talep etme
- Silme/düzeltme
- İşlemeyi kısıtlama
- İtiraz
- Veri taşınabilirliği
haklarına sahipsiniz.
Başvuru: bilgiislem@yeniasya.com.tr
''';

const String kTermsOfUseContent = '''
YENİ ASYA AŞ. — KULLANIM KOŞULLARI (KURUMSAL SON SÜRÜM)
Son Güncelleme Tarihi: …/…/2026

1. Taraflar ve Sözleşmenin Konusu
Bu Kullanım Koşulları, Yeni Asya AŞ. tarafından işletilen yeniasya.com.tr ve Yeni Asya eGazete uygulamasının kullanımına ilişkin şartları düzenler.

2. Hizmet Tanımı
Şirket; haber, analiz, yorum, egazete, video ve dijital içerik hizmetleri sunar.

3. Kullanıcı Yükümlülükleri
Kullanıcı;
- Doğru bilgi vermek
- Siteyi hukuka aykırı amaçlarla kullanmamak
- Telif haklarına riayet etmek
- Hesap güvenliğini sağlamak
ile yükümlüdür.

4. Fikri Mülkiyet Hakları
Sitede yer alan tüm içeriklerin telif hakkı Yeni Asya AŞ.'ye aittir.
İzinsiz kopyalanamaz, çoğaltılamaz, dağıtılamaz.

5. Sorumluluk Reddi
Şirket; teknik aksaklıklar, kesintiler, veri kayıpları ve üçüncü taraf saldırılarından doğan zararlardan sorumlu tutulamaz.

6. Üyeliğin Askıya Alınması veya Sonlandırılması
Kullanıcı kurallara aykırı davranırsa üyelik durdurulabilir veya sonlandırılabilir.

7. Uygulanacak Hukuk ve Yetkili Mahkeme
İşbu sözleşme Türk Hukuku'na tabidir.
Yetkili mahkeme: İstanbul Merkez Mahkemeleri ve İcra Daireleri
''';

const String kCookiePolicyContent = '''
YENİ ASYA AŞ. — ÇEREZ POLİTİKASI (KURUMSAL SON SÜRÜM)

1. Çerez Nedir?
Çerezler, ziyaretiniz sırasında cihazınıza kaydedilen küçük metin dosyalarıdır.

2. Kullanılan Çerez Türleri
- Zorunlu Çerezler: Güvenlik, oturum yönetimi (Oturum / 1 yıl)
- İşlevsel Çerezler: Tercih hatırlama (6 ay)
- Performans Çerezleri: Trafik analizi (1 yıl)
- Reklam Çerezleri: Kişiselleştirilmiş reklam (açık rıza ile)

3. Çerez Kullanım Amaçları
- Site performansını artırmak
- Kullanıcı deneyimini geliştirmek
- Reklam ve analiz faaliyetleri yürütmek

4. Çerez Yönetimi
Tarayıcı ayarlarından çerezleri engelleyebilir veya silebilirsiniz.
''';

const String kKvkkDisclosureContent = '''
YENİ ASYA AŞ. — KVKK AYDINLATMA METNİ (KURUMSAL SON SÜRÜM)

1. Veri Sorumlusu Bilgileri
Yeni Asya AŞ.
Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul
E-posta: bilgiislem@yeniasya.com.tr
KEP: yeniasya@kep.gov.tr

2. İşlenen Kişisel Veriler
- Kimlik
- İletişim
- İşlem güvenliği
- Pazarlama verileri
- Çerez verileri
- Üyelik ve işlem bilgileri

3. İşleme Amaçları
- Üyelik ve egazete hizmeti sunumu
- Dijital içerik erişimi
- Güvenlik ve log kayıtları tutulması
- Pazarlama faaliyetleri (açık rıza ile)
- Yasal yükümlülüklerin yerine getirilmesi

4. Hukuki Sebepler
- KVKK m.5/2 (a), (c), (ç), (e), (f)
- Açık rıza (m.5/1)

5. Veri Aktarımı
Veriler;
- Tedarikçiler
- Sunucu hizmeti sağlayıcıları
- Yetkili kamu kurumları
ile paylaşılabilir.

6. Haklarınız
KVKK m.11 kapsamındaki tüm haklara sahipsiniz.
Başvuru: bilgiislem@yeniasya.com.tr
''';

const Map<String, String> footerPageContentMap = {
  "Dergiler":
      "Dergiler sayfası için örnek içerik. Tüm dergi ve abonelik paketlerini burada bulabilirsiniz.",
  "Kitaplar":
      "Kitaplar sayfası için örnek içerik. Popüler ve yeni çıkan kitaplar listesi.",
  "Gazeteler":
      "Gazeteler sayfası için örnek içerik. Günlük gazetelere ve abonelik planlarına buradan erişin.",
  "Abonelikler":
      "Abonelikler sayfası için örnek içerik. Tüm abonelik paketlerini ve avantajlarını inceleyin.",
  "Yardım Merkezi":
      "Yardım Merkezi için örnek içerik. Sık karşılaşılan sorunlar ve çözümler.",
  "İletişim": kCorporateContactInfo,
  "SSS": "Sıkça Sorulan Sorular. Üyelik, ödeme ve içerik hakkında sık sorular.",
  "Geri Bildirim":
      "Geri bildirimlerinizi bizimle paylaşın. İyileştirmeler için her zaman açığız.",
  "Gizlilik Politikası": kPrivacyPolicyContent,
  "Kullanım Koşulları": kTermsOfUseContent,
  "Çerez Politikası": kCookiePolicyContent,
  "KVKK": kKvkkDisclosureContent,
};

class YeniAsyaFooter extends StatelessWidget {
  const YeniAsyaFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isWebWide = MediaQuery.of(context).size.width > 900;
    final isTablet =
        MediaQuery.of(context).size.width > 600 &&
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
                        Icon(
                          Icons.newspaper_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
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
                        Icon(
                          Icons.facebook_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.alternate_email,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20, width: 20),

              Flexible(
                flex: 1,
                child: _footerSection("Kategoriler", [
                  "Dergiler",
                  "Kitaplar",
                  "Gazeteler",
                  "Abonelikler",
                ], context),
              ),

              const SizedBox(height: 20, width: 20),

              // Destek
              Flexible(
                flex: 1,
                child: _footerSection("Destek", [
                  "Yardım Merkezi",
                  "İletişim",
                  "SSS",
                  "Geri Bildirim",
                  "Bize Ulaşın",
                ], context),
              ),

              const SizedBox(height: 20, width: 20),

              // Yasal
              Flexible(
                flex: 1,
                child: _footerSection("Yasal", [
                  "Gizlilik Politikası",
                  "Kullanım Koşulları",
                  "Çerez Politikası",
                  "KVKK",
                ], context),
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

  Widget _footerSection(
    String title,
    List<String> items,
    BuildContext context,
  ) {
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
                if (item == "Bize Ulaşın") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          title: const Text("Bize Ulaşın"),
                          elevation: 1,
                        ),
                        body: const SafeArea(
                          child: ContactForm(
                            popOnSuccess: true,
                            showCompanyInfo: true,
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  final content =
                      footerPageContentMap[item] ??
                      "Bu sayfa için içerik yakında eklenecek.";
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StaticInfoPage(title: item, content: content),
                    ),
                  );
                }
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
          child: SelectableText(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
      ),
    );
  }
}
