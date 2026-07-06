import "dart:async";

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin/admin_book_service.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/access_provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/revenuecat_service.dart';
import '../../services/user_content_access_service.dart';
import '../../utils/app_user_avatar.dart';
import '../../utils/pdf_open_helper.dart';
import '../../utils/route_guard.dart';
import '../../utils/purchase_channel_labels.dart';
import '../address/address_list_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../order/order_list_screen.dart';
import '../contact/contact_form.dart';
import '../footer/faq_page.dart';
import '../notification/notification_list_screen.dart';
import 'personal_info_screen.dart';
import 'saved_cards_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _accessService = UserContentAccessService();
  final _bookService = AdminBookService();
  final _magService = AdminMagazineService();

  bool _loadingAccess = false;
  bool _deletingAccount = false;
  bool _loggingOut = false;

  Future<void> _openPersonalInfo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
    );
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rc = context.watch<RevenueCatService>();
    final displayName = auth.user?.name ?? "Kullanıcı Adı";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          "Profil",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    AppUserAvatar(
                      radius: 45,
                      imageUrl: auth.user?.avatarUrl,
                      onEditTap: _openPersonalInfo,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      auth.user?.email ?? "",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _openPersonalInfo,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text("Fotoğrafı Düzenle"),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        auth.user?.isAdmin == true ? "Admin" : "Üye",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Abonelik Durumu",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _membershipStatusCard(auth, rc),
              const SizedBox(height: 16),
              if (kIsWeb) ...[
                const Text(
                  "Abonelikler / İçerikler",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _subscriptionCard(auth),
              ],
              if (kIsWeb && auth.user?.isAdmin == true) ...[
                const SizedBox(height: 20),
                _menuCard(
                  items: [
                    _menuTile(
                      Icons.admin_panel_settings,
                      "Yönetim Paneli",
                      onTap: () {
                        Navigator.push(
                          context,
                          RouteGuard.guard(
                            context: context,
                            routeName: "/admin",
                            builder: (_) => const AdminPanelScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
              SizedBox(height: kIsWeb ? 30 : 0),
              _menuCard(
                items: [
                  _menuTile(
                    Icons.person_outline,
                    "Kişisel Bilgiler",
                    onTap: _openPersonalInfo,
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    Icons.credit_card,
                    "Kayıtlı Kartlarım",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedCardsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    Icons.receipt_long,
                    "Sipariş Geçmişi",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderListScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    Icons.location_on_outlined,
                    "Adreslerim",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddressListScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    Icons.notifications_outlined,
                    "Bildirimler",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationListScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    Icons.help_center_outlined,
                    "Yardım Merkezi",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const FaqPage(title: "Yardım Merkezi"),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _menuTile(
                    Icons.support_agent,
                    "Bize Ulaşın",
                    onTap: () async {
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
                              child: ContactForm(popOnSuccess: true),
                            ),
                          ),
                        ),
                      );
                      if (sent == true && context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Mesajınız iletildi, teşekkür ederiz.",
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loggingOut
                        ? null
                        : () async {
                            setState(() => _loggingOut = true);
                            try {
                              await auth.logout();
                            } finally {
                              if (mounted) {
                                setState(() => _loggingOut = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.logout),
                    label: Text(
                      _loggingOut ? "Çıkış Yapılıyor..." : "Çıkış Yap",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _deletingAccount
                      ? null
                      : () => _confirmDeleteAccount(auth),
                  child: Text(
                    _deletingAccount ? "Hesap siliniyor..." : "Hesabımı Sil",
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _membershipStatusCard(AuthProvider auth, RevenueCatService rc) {
    final access = context.watch<AccessProvider>();
    final hasRevenueCatSubscription = rc.isYeniasyaProActive;
    final hasBackendAccess = access.hasAccess("newspaper_subscription");
    final hasAnyAccess = hasRevenueCatSubscription || hasBackendAccess;
    final hasActiveSubscription = hasAnyAccess;
    final statusColor = hasAnyAccess ? const Color(0xFF0F9D58) : Colors.black54;
    final user = auth.user;
    final busy = rc.isPaywallInProgress || rc.isRestoreInProgress;
    final revenueCatMessage = _revenueCatMessage(rc);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "E-Gazete",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                hasAnyAccess ? "Abonelik Var" : "Abonelik Yok",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (revenueCatMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              revenueCatMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!rc.supportsNativePurchaseUi)
            const Text(
              "Web'de e-gazete aboneliği için ürünü sepete ekleyip ödeme adımından satın alabilirsiniz.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          if (rc.supportsNativePurchaseUi) ...[
            Row(
              children: [
                Expanded(
                  flex: hasActiveSubscription ? 9 : 1,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () => _onSubscribePressed(auth: auth, rc: rc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            hasActiveSubscription
                                ? "Abonelik Aktif"
                                : "Abonelik Al",
                          ),
                  ),
                ),
                if (hasActiveSubscription) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 11,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: busy
                          ? null
                          : () => _onOpenCustomerCenter(auth: auth, rc: rc),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Aboneliği Yönet",
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (!hasActiveSubscription)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => _onRestorePressed(auth: auth, rc: rc),
                  child: const Text("Satın Alımları Geri Yükle"),
                ),
              ),
          ],
          if (user == null)
            const Text(
              "Abonelik yönetimi için giriş yapmalısınız.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          if (kDebugMode && rc.supportsNativePurchaseUi)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _backendChecklistCard(rc),
            ),
        ],
      ),
    );
  }

  Future<void> _onSubscribePressed({
    required AuthProvider auth,
    required RevenueCatService rc,
  }) async {
    final user = auth.user;
    if (user == null) {
      _showInfo("Abonelik satın almak için giriş yapmalısınız.");
      return;
    }
    await rc.syncWithAuthUser(user);
    final result = await rc.presentYeniasyaProPaywall(userId: user.id);
    if (!mounted) return;

    if (result.name == "purchased" || result.name == "restored") {
      _showInfo("Abonelik başarıyla aktif edildi.");
      unawaited(context.read<AccessProvider>().load(user.id, force: true));
      return;
    }
    if (result.name == "notPresented" && rc.isYeniasyaProActive) {
      _showInfo("Aboneliğiniz zaten aktif.");
      return;
    }
    if (result.name == "cancelled") {
      _showInfo("İşlem iptal edildi.");
      return;
    }
    _showInfo(_revenueCatMessage(rc) ?? "Abonelik işlemi tamamlanamadı.");
  }

  Future<void> _onRestorePressed({
    required AuthProvider auth,
    required RevenueCatService rc,
  }) async {
    final user = auth.user;
    if (user == null) {
      _showInfo("Önce giriş yapmalısınız.");
      return;
    }
    await rc.syncWithAuthUser(user);
    await rc.restorePurchases(userId: user.id);
    if (!mounted) return;
    final conflictMessage = _revenueCatMessage(rc);
    if (conflictMessage != null && conflictMessage.isNotEmpty) {
      _showInfo(conflictMessage);
      return;
    }
    if (rc.isYeniasyaProActive) {
      _showInfo("Abonelik geri yüklendi.");
      unawaited(context.read<AccessProvider>().load(user.id, force: true));
    } else {
      _showInfo(
        _revenueCatMessage(rc) ?? "Geri yüklenecek aktif abonelik bulunamadı.",
      );
    }
  }

  Future<void> _onOpenCustomerCenter({
    required AuthProvider auth,
    required RevenueCatService rc,
  }) async {
    final user = auth.user;
    if (user == null) {
      _showInfo("Önce giriş yapmalısınız.");
      return;
    }
    await rc.syncWithAuthUser(user);
    await rc.presentCustomerCenter(userId: user.id);
    if (!mounted) return;
    final message = _revenueCatMessage(rc);
    if (message != null && message.isNotEmpty) {
      _showInfo(message);
    }
  }

  Future<void> _confirmDeleteAccount(AuthProvider auth) async {
    final user = auth.user;
    if (user == null || _deletingAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Hesabı Sil"),
          content: const Text(
            "Hesabınızı ve ilişkili verilerinizi kalıcı olarak silmek üzeresiniz. Bu işlem geri alınamaz.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Vazgeç"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Hesabı Sil"),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    final deleted = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _deletingAccount = false);

    if (deleted) {
      _showInfo("Hesabınız başarıyla silindi.");
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    _showInfo(
      auth.errorMessage ??
          "Hesap silme işlemi tamamlanamadı. Lütfen tekrar deneyin.",
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _revenueCatMessage(RevenueCatService rc) {
    final conflict = rc.revenueCatOwnershipConflictMessage;
    if (conflict != null && conflict.isNotEmpty) return conflict;
    return null;
  }

  Widget _backendChecklistCard(RevenueCatService rc) {
    final identityOk = rc.isIdentityMatched;
    final identityLabel = rc.identityStatusLabel;
    final syncStatus = _statusText(
      rc.lastBackendSyncSuccess,
      pendingText: "Bekliyor",
      successText: "Başarılı",
      errorText: "Hatalı",
    );
    final eventStatus = _statusText(
      rc.lastBackendEventSuccess,
      pendingText: "Bekliyor",
      successText: "Başarılı",
      errorText: "Hatalı",
    );
    final syncTime = _timeLabel(rc.lastBackendSyncAt);
    final eventTime = _timeLabel(rc.lastBackendEventAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sync Checklist (debug)",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _checkRow(
            "Kimlik",
            "$identityLabel (${rc.currentAppUserId ?? "-"})",
            color: identityOk ? const Color(0xFF0F9D58) : Colors.red,
          ),
          _checkRow(
            "Son sync",
            "$syncStatus • $syncTime",
            color: _statusColor(rc.lastBackendSyncSuccess),
          ),
          _checkRow(
            "Son event",
            "$eventStatus • $eventTime",
            color: _statusColor(rc.lastBackendEventSuccess),
          ),
          _checkRow(
            "Event sonucu",
            rc.lastBackendEventResult ?? "-",
            color: Colors.black87,
          ),
          if (rc.expectedAppUserId != null && rc.expectedAppUserId!.isNotEmpty)
            _checkRow(
              "Beklenen RC ID",
              rc.expectedAppUserId!,
              color: Colors.black87,
            ),
          if (rc.lastBackendSyncError != null &&
              rc.lastBackendSyncError!.isNotEmpty)
            _checkRow("Sync hata", rc.lastBackendSyncError!, color: Colors.red),
          if (rc.lastBackendEventError != null &&
              rc.lastBackendEventError!.isNotEmpty)
            _checkRow(
              "Event hata",
              rc.lastBackendEventError!,
              color: Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _checkRow(String label, String value, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(
    bool? status, {
    required String pendingText,
    required String successText,
    required String errorText,
  }) {
    if (status == null) return pendingText;
    return status ? successText : errorText;
  }

  Color _statusColor(bool? status) {
    if (status == null) return Colors.black54;
    return status ? const Color(0xFF0F9D58) : Colors.red;
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return "-";
    String two(int value) => value.toString().padLeft(2, "0");
    return "${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}";
  }

  Widget _subscriptionCard(AuthProvider auth) {
    final tiles = <Widget>[
      _menuTile(
        Icons.menu_book_outlined,
        "E-Kitaplar",
        onTap: () => _openAccess(auth, "book", "E-Kitaplarım"),
      ),
    ];
    tiles.addAll([
      const Divider(height: 1, indent: 56),
      _menuTile(
        Icons.library_books,
        "E-Dergiler",
        onTap: () => _openAccess(auth, "magazine", "E-Dergiler"),
      ),
      const Divider(height: 1, indent: 56),
      _menuTile(
        Icons.history_edu,
        "Dergi Sayıları",
        onTap: () => _openAccess(auth, "magazine_issue", "Dergi Sayılarım"),
      ),
      const Divider(height: 1, indent: 56),
      _menuTile(
        Icons.newspaper,
        "E-Gazete",
        onTap: () => _openAccess(auth, "newspaper_subscription", "E-Gazete"),
      ),
    ]);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: tiles),
    );
  }

  Widget _menuCard({required List<Widget> items}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuTile(IconData icon, String text, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ?? () {},
    );
  }

  Future<void> _openAccess(
    AuthProvider auth,
    String itemType,
    String title,
  ) async {
    if (_loadingAccess) return;
    final userId = auth.user?.id;
    if (userId == null) return;

    setState(() => _loadingAccess = true);
    List<Map<String, dynamic>> entries = [];
    try {
      entries = await _accessService.getAccess(
        userId: userId,
        itemType: itemType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erişim alınamadı: $e")));
      }
    } finally {
      if (mounted) setState(() => _loadingAccess = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
        ),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loadingAccess
                    ? const Center(child: CircularProgressIndicator())
                    : entries.isEmpty
                    ? const Center(child: Text("Kayıt bulunamadı"))
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final entry = entries[i];
                          return FutureBuilder<_AccessItem>(
                            future: _resolveAccessItem(itemType, entry),
                            builder: (_, snap) {
                              if (!snap.hasData) {
                                return const ListTile(
                                  title: Text("Yükleniyor..."),
                                  trailing: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              final data = snap.data!;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  foregroundColor: Colors.red,
                                  child: const Icon(Icons.book),
                                ),
                                title: Text(data.title),
                                subtitle: data.subtitle != null
                                    ? Text(data.subtitle!)
                                    : null,
                                trailing: data.onTap != null
                                    ? const Icon(Icons.chevron_right)
                                    : const SizedBox.shrink(),
                                onTap: data.onTap,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_AccessItem> _resolveAccessItem(
    String type,
    Map<String, dynamic> entry,
  ) async {
    final itemId = _asInt(entry["item_id"]);
    switch (type) {
      case "book":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen kitap");
        final book = await _bookService.getBookById(itemId);
        final title = book?["title"]?.toString() ?? "Kitap #$itemId";
        final url = book?["book_url"]?.toString();
        final subtitle = _accessSubtitle(entry, fallback: "Kitap");
        return _AccessItem(
          title: title,
          subtitle: subtitle,
          onTap: (url == null || url.isEmpty)
              ? null
              : () {
                  unawaited(
                    PdfOpenHelper.downloadAndOpen(
                      context,
                      url: url,
                      title: title,
                      isPrivate: true,
                    ),
                  );
                },
        );
      case "magazine_issue":
        if (itemId == null) return _AccessItem(title: "Bilinmeyen sayı");
        final issue = await _magService.getIssueById(itemId);
        final magName = issue?["magazine"]?["name"]?.toString() ?? "Dergi";
        final issueNumber = issue?["issue_number"]?.toString() ?? "#$itemId";
        final url = issue?["file_url"]?.toString();
        final subtitle = _accessSubtitle(entry, fallback: "Dergi Sayısı");
        return _AccessItem(
          title: "$magName - $issueNumber",
          subtitle: subtitle,
          onTap: (url == null || url.isEmpty)
              ? null
              : () {
                  unawaited(
                    PdfOpenHelper.downloadAndOpen(
                      context,
                      url: url,
                      title: "$magName - $issueNumber",
                      isPrivate: true,
                    ),
                  );
                },
        );
      case "magazine":
        if (itemId == null) return _AccessItem(title: "Dergi aboneliği");
        final mag = await _magService.getMagazineById(itemId);
        final name = mag?["name"]?.toString() ?? "Dergi #$itemId";
        return _AccessItem(
          title: name,
          subtitle: _accessSubtitle(entry, fallback: "Dergi aboneliği"),
          onTap: () => _openMagazineIssues(itemId, name),
        );
      case "newspaper_subscription":
        return _AccessItem(
          title: "Gazete aboneliği",
          subtitle: _accessSubtitle(entry, fallback: "Abonelik aktif"),
          onTap: null,
        );
      default:
        return _AccessItem(title: "Bilinmeyen içerik");
    }
  }

  String _accessSubtitle(
    Map<String, dynamic> entry, {
    required String fallback,
  }) {
    final parts = <String>[];
    final expiresAt = _parseDateTime(entry["expires_at"]);
    if (expiresAt != null) {
      parts.add("Bitiş Tarihi: ${_formatDateShort(expiresAt)}");
    }

    final channel = PurchaseChannelLabels.accessChannelLabel(entry);
    if (channel != "Bilinmiyor") {
      parts.add("Kanal: $channel");
    }

    if (parts.isEmpty) return fallback;
    return parts.join(" • ");
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.tryParse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  String _formatDateShort(DateTime date) {
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(local.day)}.${two(local.month)}.${local.year}";
  }

  Future<void> _openMagazineIssues(int magazineId, String name) async {
    final issues = await _magService.getIssues(magazineId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
        ),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$name Sayıları",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: issues.isEmpty
                    ? const Center(child: Text("Sayı bulunamadı"))
                    : ListView.separated(
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final issue = issues[i];
                          final title = "Sayı ${issue["issue_number"]}";
                          return ListTile(
                            title: Text(title),
                            subtitle: Text(
                              "Eklenme: ${issue["added_at"] ?? ''}",
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final url = issue["file_url"]?.toString();
                              if (url == null || url.isEmpty) return;
                              unawaited(
                                PdfOpenHelper.downloadAndOpen(
                                  context,
                                  url: url,
                                  title: "$name - $title",
                                  isPrivate: true,
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessItem {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  _AccessItem({required this.title, this.subtitle, this.onTap});
}
