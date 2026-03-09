import 'package:flutter/material.dart';
import '../contact/contact_form.dart';
import 'faq_page.dart';

const String kCorporateContactInfo = '''
YENİ ASYA AŞ. — İLETİŞİM BİLGİLERİ

Yeni Asya AŞ.
Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul
E-posta: bilgiislem@yeniasya.com.tr
KEP: yeniasya@kep.gov.tr
''';

const String kPrivacyPolicyContent = '''
YENİ ASYA AŞ. — GİZLİLİK POLİTİKASI
Son Güncelleme Tarihi: …/…/2026
Yayınlayan: Yeni Asya AŞ.

1. Giriş ve Amaç
Bu Gizlilik Politikası, Yeni Asya AŞ. (“Şirket”) tarafından işletilen yeniasya.com.tr internet sitesi ile Yeni Asya eGazete mobil uygulaması (birlikte “Platform”) üzerinden elde edilen kişisel verilerin işlenmesine ilişkin usul ve esasları açıklamak amacıyla hazırlanmıştır.
Şirket, kullanıcıların kişisel verilerinin gizliliğine ve güvenliğine önem verir; veri işleme faaliyetleri KVKK, 5651, 6563, Türk Borçlar Kanunu ve ilgili ikincil düzenlemelere uygun şekilde yürütülür.
Platform’un indirilmesi, erişilmesi veya kullanılması halinde işbu Gizlilik Politikası’nda belirtilen veri işleme faaliyetleri kapsamında kişisel verilerinizin işlenmesini kabul etmiş sayılırsınız.

2. Veri Sorumlusu Bilgileri
Yeni Asya AŞ.
Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul
E-posta: bilgiislem@yeniasya.com.tr
KEP: yeniasya@kep.gov.tr

3. İşlenen Kişisel Veri Kategorileri
- Kimlik Bilgileri: Ad, soyad
- İletişim Bilgileri: E-posta, telefon
- Üyelik ve İşlem Bilgileri: Üyelik kayıtları, abonelik işlemleri, erişim geçmişi
- Cihaz ve Teknik Veriler: IP adresi, cihaz türü, işletim sistemi, uygulama sürümü, tarayıcı bilgisi, hata kayıtları, log kayıtları
- Kullanım/Analitik Veriler: Platform’da ziyaret edilen sayfalar/ekranlar, ziyaret tarihi ve saati, sayfada/ekranda geçirilen süre, uygulamada geçirilen toplam süre
- Çerez Verileri (Web için): Zorunlu, performans/analitik, işlevsel, reklam/pazarlama çerezleri
- Talep/Şikayet Verileri: İletişim formları, destek talepleri, geri bildirimler
Konum Verileri: Platform, mobil cihazınızın kesin (precise) konum bilgisini toplamaz. (Bazı cihaz ayarları veya üçüncü taraf servisler yaklaşık konum üretebilir; Şirket, kesin konumu talep etmez.)

4. Kişisel Verilerin Toplanma Yöntemi
Kişisel verileriniz;
- Platform üzerinden üyelik oluşturmanız, form doldurmanız, abonelik işlemi yapmanız,
- Siteyi/uygulamayı kullanmanız sırasında otomatik olarak oluşan log ve analitik kayıtları,
- Çerezler (web) ve benzeri teknolojiler,
kanallarıyla otomatik veya kısmen otomatik olmayan yöntemlerle toplanabilir.

5. Kişisel Verilerin İşlenme Amaçları
Kişisel verileriniz aşağıdaki amaçlarla işlenebilir:
- Üyelik oluşturma, hesap yönetimi ve hizmet sunumu
- eGazete erişimi ve dijital içerik sağlama
- Platform’un güvenliğinin sağlanması, log kaydı tutulması, dolandırıcılık ve kötüye kullanımın önlenmesi
- Kullanıcı deneyiminin iyileştirilmesi, performans/analitik çalışmalar
- Hata tespiti, uygulama geliştirme, bakım ve destek süreçleri
- Yasal yükümlülüklerin yerine getirilmesi ve yetkili kurum taleplerinin yanıtlanması
- Bilgilendirme mesajları (önemli duyurular, zorunlu bildirimler)
- Pazarlama ve kampanya bilgilendirmeleri (yalnızca gerekli hallerde ve açık rıza bulunması halinde)
Şirket, kullanıcı tarafından sağlanan iletişim bilgilerini, zaman zaman önemli bilgilendirmeler, zorunlu bildirimler ve (varsa) açık rıza kapsamındaki kampanya duyuruları için kullanabilir.

6. Kişisel Verilerin İşlenme Hukuki Sebepleri
Kişisel verileriniz;
- KVKK m.5/2 (a), (c), (ç), (e), (f) kapsamındaki şartlara dayanarak,
- Gerekli hallerde açık rıza (KVKK m.5/1),
- 5651 sayılı Kanun ve ikincil mevzuat kapsamında loglama yükümlülükleri,
- 6563 sayılı Kanun kapsamındaki yükümlülükler,
doğrultusunda işlenmektedir.

7. Üçüncü Taraf Hizmetler ve Üçüncü Taraflara Aktarım
Platform, bazı özelliklerin sunulması ve hizmet kalitesinin artırılması amacıyla üçüncü taraf servislerden yararlanabilir. Bu servisler kendi gizlilik politikalarına tabidir.
Platform’da kullanılabilecek üçüncü taraf servis örnekleri (zaman içinde değişebilir):
- Google Play Services
- Google Analytics for Firebase
- RevenueCat (abonelik/ödeme altyapısı)

7.1. Hangi veriler aktarılabilir?
Şirket, hizmetin geliştirilmesi amacıyla yalnızca gerekli olduğu ölçüde, anonimleştirilmiş veya toplulaştırılmış (aggregated) verileri periyodik olarak dış servislerle paylaşabilir. Ayrıca, uygulamanın çalışması için zorunlu teknik veriler (ör. cihaz/uygulama ölçümleri) ilgili servisler tarafından işlenebilir.

7.2. Paylaşım/ifşa halleri
Şirket, kullanıcı tarafından sağlanan ve otomatik toplanan verileri şu hallerde üçüncü kişilerle paylaşabilir/ifşa edebilir:
- Kanunen zorunlu olması halinde (mahkeme kararı, savcılık talebi, resmi yazı vb. hukuki süreçlere uyum),
- Şirket’in iyi niyetli değerlendirmesine göre; haklarını korumak, kullanıcı güvenliğini veya başkalarının güvenliğini sağlamak, dolandırıcılığı soruşturmak veya kamu otoritesi taleplerine yanıt vermek için gerekli olması halinde,
- Şirket adına hizmet veren ve verileri bağımsız amaçlarla kullanmayan; yalnızca talimatla işleyen güvenilir hizmet sağlayıcılarla (barındırma, altyapı, analiz, müşteri destek vb.) ve bu sağlayıcıların işbu politikaya uygun hareket etmeyi kabul etmesi kaydıyla.

8. Çerezler ve Benzeri Teknolojiler (Web)
Web sitesi üzerinde çerezler kullanılabilir. Çerez türleri:
- Zorunlu çerezler
- Performans/analitik çerezler
- Reklam/pazarlama çerezleri (varsa ve açık rıza gerektiriyorsa rıza ile)
Çerez tercihlerinizi tarayıcı ayarlarınızdan yönetebilirsiniz.

9. Kullanıcı Tercihleri ve Vazgeçme (Opt-Out) Hakları
Kullanıcı, Platform’un veri toplamasını durdurmak için Uygulama’yı cihazından kaldırabilir. Bu işlem, mobil cihazınızın standart kaldırma yöntemleri veya uygulama mağazası üzerinden yapılabilir.
Pazarlama iletişimleri (varsa) için sağlanan izinler, kullanıcı tarafından her zaman geri alınabilir.

10. Veri Saklama Süreleri (Data Retention)
Kişisel verileriniz, işleme amaçları için gerekli süre boyunca ve ilgili mevzuatta öngörülen asgari süreler kadar saklanır:
- Log kayıtları: 5651 gereği 2 yıl
- Üyelik verileri: Üyelik devam ettiği sürece + makul süre
- Talep/şikayet kayıtları: İlgili talep sonuçlandıktan sonra makul süre
- Çerezler: Türüne göre 1 gün - 2 yıl
Kullanıcı, Uygulama üzerinden sağladığı kişisel verilerin silinmesini talep etmek isterse bilgiislem@yeniasya.com.tr adresi üzerinden başvurabilir. Şirket, talebi makul süre içinde ve mevzuat çerçevesinde değerlendirir.

11. Veri Güvenliği
Şirket, işlenen kişisel verilerin gizliliğini korumak ve güvenliğini sağlamak amacıyla fiziksel, elektronik ve idari tedbirler uygular. Buna rağmen internet üzerinden yapılan veri iletimlerinin %100 güvenli olduğu garanti edilemez; kullanıcı da kendi cihaz güvenliğinden sorumludur.

12. KVKK Kapsamındaki Haklarınız
KVKK m.11 uyarınca;
- Kişisel verilerinizin işlenip işlenmediğini öğrenme,
- İşlenmişse bilgi talep etme,
- İşleme amacını ve bunların amacına uygun kullanılıp kullanılmadığını öğrenme,
- Yurt içinde/yurt dışında aktarıldığı üçüncü kişileri bilme,
- Eksik/yanlış işlenmişse düzeltilmesini isteme,
- KVKK’da öngörülen şartlar çerçevesinde silinmesini/yok edilmesini isteme,
- Yapılan işlemlerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
- İşlenen verilerin münhasıran otomatik sistemler ile analiz edilmesi suretiyle aleyhe bir sonucun ortaya çıkmasına itiraz etme,
- Kanuna aykırı işleme nedeniyle zarara uğranması hâlinde zararın giderilmesini talep etme,
haklarına sahipsiniz.
Başvuru: bilgiislem@yeniasya.com.tr

13. Değişiklikler
İşbu Gizlilik Politikası, herhangi bir nedenle zaman zaman güncellenebilir. Güncellemeler bu sayfada yayımlanır ve yayımlandığı tarihte yürürlüğe girer. Platform’u kullanmaya devam etmeniz, değişiklikleri kabul ettiğiniz anlamına gelir. Değişiklikler için bu sayfayı düzenli olarak kontrol etmeniz önerilir.

14. Açık Rıza ve Onay (Your Consent)
Platform’u kullanarak, kişisel verilerinizin işbu Gizlilik Politikası’nda belirtilen şekilde işlenmesine onay vermiş olursunuz. Açık rıza gerektiren hallerde (ör. pazarlama çerezleri/pazarlama iletişimi) ayrıca rızanız alınır.

15. İletişim
Gizlilik uygulamalarımız hakkında sorularınız veya talepleriniz için bizimle iletişime geçebilirsiniz:
E-posta: bilgiislem@yeniasya.com.tr
KEP: yeniasya@kep.gov.tr
''';

const String kTermsOfUseContent = '''
YENİ ASYA AŞ. — KULLANIM KOŞULLARI
Son Güncelleme Tarihi: …/…/2026

1. Taraflar ve Sözleşmenin Konusu
İşbu Kullanım Koşulları (“Sözleşme”), Yeni Asya AŞ. (“Şirket” veya “Hizmet Sağlayıcı”) tarafından işletilen yeniasya.com.tr internet sitesi ile Yeni Asya eGazete mobil uygulamasının (bundan böyle birlikte “Platform” veya “Uygulama”) kullanımına ilişkin şart ve kuralları düzenler.

Platform’u indirmeniz, erişmeniz veya kullanmanız halinde işbu Sözleşme hükümlerini okuduğunuzu, anladığınızı ve kabul ettiğinizi beyan etmiş sayılırsınız. Bu şartları kabul etmiyorsanız Platform’u kullanmamalısınız.

2. Hizmet Tanımı
Şirket; haber, analiz, yorum, e-gazete, video ve diğer dijital içerik hizmetleri sunar. Şirket, Platform’u daha faydalı ve verimli hale getirmek amacıyla içerikleri, özellikleri ve hizmet kapsamını dilediği zaman değiştirme, güncelleme veya yeni özellik ekleme hakkını saklı tutar.

Platform, freemium (ücretsiz + ücretli) model kapsamında sunulabilir. Ücretli hizmet, abonelik veya uygulama içi satın alma olması halinde, ilgili ücretlendirme koşulları kullanıcıya açıkça bildirilecektir.

3. Kullanıcı Yükümlülükleri
Kullanıcı;
- Platform’a kayıt olurken veya kullanırken doğru ve güncel bilgi vermeyi,
- Platform’u hukuka, kamu düzenine ve genel ahlaka aykırı amaçlarla kullanmamayı,
- Platform üzerinden sunulan içerik ve hizmetlerde telif haklarına riayet etmeyi,
- Hesap bilgilerini gizli tutmayı ve üçüncü kişilerle paylaşmamayı,
- Kendi cihazının güvenliğini sağlamayı,
kabul eder.

Kullanıcı, cihazının güvenliğinden bizzat sorumludur. Şirket, cihazınızın jailbreak/root yapılması (resmî işletim sistemi kısıtlarının kaldırılması) durumunda ortaya çıkabilecek güvenlik açıkları, kötü amaçlı yazılımlar, veri kaybı ve Platform’un çalışmaması gibi sonuçlardan sorumlu değildir. Root/jailbreak işlemleri Platform’un doğru çalışmasını engelleyebilir.

4. Fikri Mülkiyet Hakları
Platform’da yer alan tüm içerikler (metin, görsel, video, tasarım, logo, marka, arayüz, yazılım, veri tabanı vb.) üzerindeki telif, marka ve diğer fikrî mülkiyet hakları Yeni Asya AŞ.’ye veya ilgili hak sahibine aittir.

İçerikler; Şirket’in yazılı izni olmadan kopyalanamaz, çoğaltılamaz, dağıtılamaz, yayımlanamaz, işlenemez, kaynak kodu çıkarılamaz, tercüme edilemez veya türev eser oluşturulamaz. Şirket markaları ve logoları izinsiz kullanılamaz.

5. Kişisel Veriler ve Gizlilik
Platform, hizmetin sunulabilmesi amacıyla kullanıcıların sağladığı bazı kişisel verileri saklayabilir ve işleyebilir. Kullanıcı, kişisel verilerin işlenmesine ilişkin detayların Gizlilik Politikası ve ilgili aydınlatma metinlerinde yer aldığını kabul eder.

Kullanıcı, cihazına yetkisiz erişimi engellemek, şifrelerini korumak ve güvenli kullanım için gerekli tedbirleri almakla yükümlüdür.

6. Üçüncü Taraf Hizmetler
Platform, belirli özelliklerin sağlanması için üçüncü taraf servislerden faydalanabilir. Bu servislerin kendi kullanım koşulları ve gizlilik politikaları bulunur. Kullanıcı, bu hizmetleri kullanırken ilgili üçüncü tarafların şartlarının da geçerli olabileceğini kabul eder.

Platform’da kullanılabilecek üçüncü taraf servis örnekleri (listelenenler değişebilir):
- Google Play Services
- Google Analytics for Firebase
- RevenueCat (abonelik/ödeme altyapısı)

Şirket, üçüncü taraf servislerin erişilebilirliği, kesintisiz çalışması veya bu servislerden doğabilecek sonuçlardan sınırlı ölçüde sorumludur.

7. İnternet Bağlantısı, Veri Kullanımı ve Cihaz Sorumluluğu
Platform’un bazı işlevleri aktif internet bağlantısı gerektirir (Wi-Fi veya mobil veri). Wi-Fi erişiminizin olmaması veya mobil veri paketinizin bitmesi nedeniyle Platform’un tam kapasitede çalışmamasından Şirket sorumlu tutulamaz.

Platform’u Wi-Fi dışında kullanmanız halinde mobil operatörünüzün şartları geçerli olur; veri kullanım ücretleri ve dolaşım (roaming) ücretleri gibi maliyetlerden kullanıcı sorumludur. Cihazın faturasını ödeyen kişi siz değilseniz gerekli izni aldığınızı kabul edersiniz.

Kullanıcı, cihazının şarjı ve çalışır durumda olmasından sorumludur. Cihazın şarjının bitmesi veya donanımsal/yazılımsal sorunlar nedeniyle hizmete erişememekten Şirket sorumlu değildir.

8. Sorumluluk Reddi ve Sınırlamalar
Şirket, Platform’un her zaman güncel ve doğru olması için makul çabayı gösterir; ancak bazı bilgiler üçüncü taraf kaynaklardan sağlanabilir. Kullanıcı, Platform’daki içerik ve işlevleri kendi sorumluluğu altında kullandığını kabul eder.

Şirket; teknik aksaklıklar, bakım çalışmaları, kesintiler, veri kaybı, gecikmeler, üçüncü taraf saldırıları, üçüncü taraf servis kesintileri veya mücbir sebepler nedeniyle ortaya çıkabilecek doğrudan veya dolaylı zararlardan, yürürlükteki mevzuatın izin verdiği ölçüde sorumlu tutulamaz.

9. Üyeliğin Askıya Alınması veya Sonlandırılması
Kullanıcının işbu Sözleşme’ye aykırı davranması, hukuka aykırı kullanım, güvenlik ihlali veya Şirket’in meşru menfaatlerini zedeleyebilecek hareketlerde bulunması halinde Şirket, kullanıcı hesabını geçici olarak askıya alma veya kalıcı olarak sonlandırma hakkını saklı tutar.

Şirket, Platform’u dilediği zaman güncelleyebilir, kullanımını durdurabilir veya sona erdirebilir. Platform’un kullanımının sona ermesi halinde:
(a) Kullanıcıya tanınan haklar ve lisanslar sona erer,
(b) Kullanıcı Platform’u kullanmayı bırakmalı ve gerekirse cihazından kaldırmalıdır.

10. Değişiklikler
Şirket, işbu Kullanım Koşulları’nı dönemsel olarak güncelleyebilir. Güncellemeler Platform’da yayımlandığı tarihte yürürlüğe girer. Kullanıcı, bu sayfayı düzenli olarak kontrol etmekle sorumludur. Şirket, değişiklikleri Platform üzerinden yayımlayarak veya uygun gördüğü yöntemlerle kullanıcıya duyurabilir.

11. Uygulanacak Hukuk ve Yetkili Mahkeme
İşbu Sözleşme Türk Hukuku’na tabidir. Uyuşmazlıkların çözümünde İstanbul Merkez Mahkemeleri ve İcra Daireleri yetkilidir.

12. İletişim
İşbu Kullanım Koşulları ile ilgili soru ve önerileriniz için Şirket ile aşağıdaki kanallardan iletişime geçebilirsiniz:
E-posta: app@yeniasya.com.tr
Adres: 15 Temmuz Mah., 1508 Sk., No: 3, 34212, Güneşli, İstanbul
Telefon: 0 (212) 655 88 59
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
  "E-Dergiler":
      "E-Dergiler sayfası için örnek içerik. Tüm dergi ve abonelik paketlerini burada bulabilirsiniz.",
  "E-Kitaplar":
      "E-Kitaplar sayfası için örnek içerik. Popüler ve yeni çıkan kitaplar listesi.",
  "E-Gazete":
      "E-Gazete sayfası için örnek içerik. Günlük gazetelere ve abonelik planlarına buradan erişin.",
  "E-Ekler":
      "E-Ekler sayfası için örnek içerik. Tüm e-ek içeriklerine buradan erişebilirsiniz.",
  "Abonelikler":
      "Abonelikler sayfası için örnek içerik. Tüm abonelik paketlerini ve avantajlarını inceleyin.",
  "İletişim": kCorporateContactInfo,
  "Gizlilik Politikası": kPrivacyPolicyContent,
  "Kullanım Koşulları": kTermsOfUseContent,
  "Çerez Politikası": kCookiePolicyContent,
  "KVKK": kKvkkDisclosureContent,
};

class YeniAsyaFooter extends StatelessWidget {
  final ValueChanged<String>? onCategoryTap;

  const YeniAsyaFooter({super.key, this.onCategoryTap});

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
                    Image.asset(
                      "assets/images/logo.png",
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "İnsanı ve kâinatı okumak için...",
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
                  "E-Dergiler",
                  "E-Kitaplar",
                  "E-Gazete",
                  "E-Ekler",
                ], context),
              ),

              const SizedBox(height: 20, width: 20),

              // Destek
              Flexible(
                flex: 1,
                child: _footerSection("Destek", [
                  "İletişim",
                  "SSS",
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
              onTap: () async {
                final isCategoryItem = const {
                  "E-Dergiler",
                  "E-Kitaplar",
                  "E-Gazete",
                  "E-Ekler",
                }.contains(item);
                if (isCategoryItem && onCategoryTap != null) {
                  onCategoryTap!(item);
                  return;
                }
                if (item == "Bize Ulaşın") {
                  final sent = await Navigator.push<bool>(
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
                  if (sent == true && context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text("Mesajınız iletildi, teşekkür ederiz."),
                      ),
                    );
                  }
                } else if (item == "SSS") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaqPage()),
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
