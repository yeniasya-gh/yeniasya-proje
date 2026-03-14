import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin/admin_contact_message_service.dart';
import '../../services/error/error_manager.dart';
import 'admin_loading_indicator.dart';
import 'admin_user_detail_page.dart';

enum _ContactSourceFilter { all, linkedUser, anonymous }

enum _ContactSortOption { newestFirst, oldestFirst }

class AdminContactMessagesPage extends StatefulWidget {
  const AdminContactMessagesPage({super.key});

  @override
  State<AdminContactMessagesPage> createState() =>
      _AdminContactMessagesPageState();
}

class _AdminContactMessagesPageState extends State<AdminContactMessagesPage> {
  static const String _allTopics = "__all_topics__";

  final _service = AdminContactMessageService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  int? _deletingId;
  String _selectedTopic = _allTopics;
  _ContactSourceFilter _sourceFilter = _ContactSourceFilter.all;
  _ContactSortOption _sortOption = _ContactSortOption.newestFirst;

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getAll();
      if (!mounted) return;
      setState(() => _messages = items);
    } catch (error) {
      _showSnack(
        ErrorManager.parseGraphQLError(error.toString()),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  List<String> get _topicOptions {
    final options = _messages.map(_topicOf).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  List<Map<String, dynamic>> get _filteredMessages {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _messages.where((item) {
      final matchesTopic =
          _selectedTopic == _allTopics || _topicOf(item) == _selectedTopic;
      final matchesSource = switch (_sourceFilter) {
        _ContactSourceFilter.all => true,
        _ContactSourceFilter.linkedUser => _hasLinkedUser(item),
        _ContactSourceFilter.anonymous => !_hasLinkedUser(item),
      };

      if (!matchesTopic || !matchesSource) return false;
      if (query.isEmpty) return true;

      final haystack = [
        item["id"]?.toString() ?? "",
        _topicOf(item),
        _subjectOf(item),
        _messageBodyOf(item),
        _emailOf(item),
        _senderNameOf(item),
        item["user_id"]?.toString() ?? "",
      ].join(" ").toLowerCase();

      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final leftDate = _dateOf(a);
      final rightDate = _dateOf(b);
      final leftId = _asInt(a["id"]) ?? 0;
      final rightId = _asInt(b["id"]) ?? 0;

      final result = switch (_sortOption) {
        _ContactSortOption.newestFirst => _compareDateDesc(
          leftDate,
          rightDate,
          leftId,
          rightId,
        ),
        _ContactSortOption.oldestFirst => _compareDateAsc(
          leftDate,
          rightDate,
          leftId,
          rightId,
        ),
      };

      return result;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMessages;
    final totalCount = _messages.length;
    final filteredCount = filtered.length;
    final linkedCount = _messages.where(_hasLinkedUser).length;
    final anonymousCount = totalCount - linkedCount;
    final recentCount = _messages.where(_isRecentMessage).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Bize Ulaşın Mesajları",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: filtered.isEmpty ? null : _copyFilteredList,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text("Filtreliyi Kopyala"),
                ),
                IconButton(
                  tooltip: "Yenile",
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard(
              label: "Toplam Mesaj",
              value: totalCount.toString(),
              icon: Icons.mail_outline,
              color: Colors.blueGrey,
            ),
            _statCard(
              label: "Filtrelenen",
              value: filteredCount.toString(),
              icon: Icons.filter_alt_outlined,
              color: Colors.deepPurple,
            ),
            _statCard(
              label: "Kullanıcılı",
              value: linkedCount.toString(),
              icon: Icons.verified_user_outlined,
              color: Colors.green,
            ),
            _statCard(
              label: "Anonim",
              value: anonymousCount.toString(),
              icon: Icons.person_off_outlined,
              color: Colors.orange,
            ),
            _statCard(
              label: "Son 7 Gün",
              value: recentCount.toString(),
              icon: Icons.schedule_outlined,
              color: Colors.redAccent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFiltersCard(),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const AdminLoadingIndicator()
              : filtered.isEmpty
              ? _emptyState()
              : _buildTable(filtered),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final fieldWidth = wide
              ? ((constraints.maxWidth - 36) / 4).clamp(220.0, 320.0)
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: "Ara",
                    hintText: "Başlık, mesaj, e-posta, kullanıcı...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: "Temizle",
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTopic,
                  decoration: const InputDecoration(
                    labelText: "Konu Türü",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: _allTopics,
                      child: Text("Tüm Konular"),
                    ),
                    ..._topicOptions.map(
                      (topic) => DropdownMenuItem<String>(
                        value: topic,
                        child: Text(topic),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedTopic = value ?? _allTopics);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<_ContactSourceFilter>(
                  initialValue: _sourceFilter,
                  decoration: const InputDecoration(
                    labelText: "Kaynak",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _ContactSourceFilter.all,
                      child: Text("Tümü"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSourceFilter.linkedUser,
                      child: Text("Giriş Yapmış Kullanıcı"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSourceFilter.anonymous,
                      child: Text("Anonim / E-posta"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sourceFilter = value);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<_ContactSortOption>(
                  initialValue: _sortOption,
                  decoration: const InputDecoration(
                    labelText: "Sıralama",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _ContactSortOption.newestFirst,
                      child: Text("En Yeni İlk"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSortOption.oldestFirst,
                      child: Text("En Eski İlk"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortOption = value);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        Colors.grey.shade100,
                      ),
                      columnSpacing: 16,
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 92,
                      columns: const [
                        DataColumn(label: Text("Tarih")),
                        DataColumn(label: Text("Konu Türü")),
                        DataColumn(label: Text("Başlık")),
                        DataColumn(label: Text("Gönderen")),
                        DataColumn(label: Text("Mesaj")),
                        DataColumn(label: Text("Kaynak")),
                        DataColumn(label: Text("Aksiyon")),
                      ],
                      rows: items.map((item) {
                        final deleting = _deletingId == _asInt(item["id"]);
                        final user = _userOf(item);
                        final senderSubtitle = [
                          if (_emailOf(item).isNotEmpty) _emailOf(item),
                          if (_asInt(item["user_id"]) != null)
                            "ID: ${item["user_id"]}",
                        ].join(" • ");

                        return DataRow(
                          onSelectChanged: (_) => _openMessageDetail(item),
                          cells: [
                            DataCell(Text(_formatDateTime(item["created_at"]))),
                            DataCell(_topicChip(_topicOf(item))),
                            DataCell(
                              SizedBox(
                                width: 240,
                                child: Text(
                                  _subjectOf(item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 240,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _senderNameOf(item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (senderSubtitle.isNotEmpty)
                                      Text(
                                        senderSubtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 340,
                                child: Text(
                                  _preview(_messageBodyOf(item), 180),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(_sourceChip(_hasLinkedUser(item))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: "Detay",
                                    onPressed: () => _openMessageDetail(item),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Mesajı Kopyala",
                                    onPressed: () => _copyMessageBody(item),
                                    icon: const Icon(
                                      Icons.content_copy_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: user == null
                                        ? "Bağlı kullanıcı yok"
                                        : "Kullanıcı detayı",
                                    onPressed: user == null
                                        ? null
                                        : () => _openUserDetail(user),
                                    icon: const Icon(
                                      Icons.person_search_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Sil",
                                    onPressed: deleting
                                        ? null
                                        : () => _deleteMessage(item),
                                    icon: deleting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 48,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          const Text(
            "Gösterilecek mesaj bulunamadı.",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _messages.isEmpty
                ? "Henüz bize ulaşın formundan kayıt oluşmamış."
                : "Arama veya filtreleri değiştirip tekrar deneyin.",
            style: TextStyle(color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _openMessageDetail(Map<String, dynamic> item) async {
    final user = _userOf(item);
    final email = _emailOf(item);
    final messageBody = _messageBodyOf(item);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Mesaj #${item["id"] ?? "-"}"),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _topicChip(_topicOf(item)),
                    _sourceChip(_hasLinkedUser(item)),
                    _metaChip(
                      Icons.schedule_outlined,
                      _formatDateTime(item["created_at"]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailSection(
                  "Başlık",
                  SelectableText(
                    _subjectOf(item),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                _detailSection(
                  "Gönderen",
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(_senderNameOf(item)),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SelectableText(email),
                      ],
                      if (_asInt(item["user_id"]) != null) ...[
                        const SizedBox(height: 4),
                        SelectableText("Kullanıcı ID: ${item["user_id"]}"),
                      ],
                      if ((user?["phone"]?.toString().trim() ?? "").isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SelectableText("Telefon: ${user?["phone"]}"),
                        ),
                      if ((user?["role"]?.toString().trim() ?? "").isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SelectableText("Rol: ${user?["role"]}"),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _detailSection(
                  "Mesaj",
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(messageBody),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (email.isNotEmpty)
            TextButton.icon(
              onPressed: () => _copyToClipboard(email, "E-posta kopyalandı."),
              icon: const Icon(Icons.alternate_email),
              label: const Text("E-postayı Kopyala"),
            ),
          TextButton.icon(
            onPressed: () => _copyToClipboard(messageBody, "Mesaj kopyalandı."),
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text("Mesajı Kopyala"),
          ),
          if (user != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openUserDetail(user);
              },
              icon: const Icon(Icons.person_search_outlined),
              label: const Text("Kullanıcıya Git"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(Map<String, dynamic> item) async {
    final id = _asInt(item["id"]);
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Mesajı Sil"),
        content: Text(
          "#$id numaralı mesajı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = id);
    try {
      await _service.deleteMessage(id);
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((item) => _asInt(item["id"]) == id);
      });
      _showSnack("Mesaj silindi.");
    } catch (error) {
      _showSnack(
        ErrorManager.parseGraphQLError(error.toString()),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  void _openUserDetail(Map<String, dynamic> user) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AdminUserDetailPage(user: user)));
  }

  Future<void> _copyFilteredList() async {
    final lines = <String>[
      "id\ttarih\tkonu_turu\tbaslik\tgonderen\temail\tuser_id\tmesaj",
      for (final item in _filteredMessages)
        [
          item["id"]?.toString() ?? "",
          _formatDateTime(item["created_at"]),
          _topicOf(item),
          _subjectOf(item),
          _senderNameOf(item),
          _emailOf(item),
          item["user_id"]?.toString() ?? "",
          _messageBodyOf(item).replaceAll("\t", " ").replaceAll("\n", " "),
        ].join("\t"),
    ];

    await _copyToClipboard(
      lines.join("\n"),
      "Filtrelenmiş mesaj listesi panoya kopyalandı.",
    );
  }

  Future<void> _copyMessageBody(Map<String, dynamic> item) async {
    await _copyToClipboard(_messageBodyOf(item), "Mesaj panoya kopyalandı.");
  }

  Future<void> _copyToClipboard(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnack(successMessage);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 208,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicChip(String topic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        topic,
        style: const TextStyle(
          color: Color(0xFF274690),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sourceChip(bool linkedUser) {
    final color = linkedUser ? Colors.green : Colors.orange;
    final label = linkedUser ? "Kullanıcılı" : "Anonim";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  bool _hasLinkedUser(Map<String, dynamic> item) =>
      _asInt(item["user_id"]) != null;

  bool _isRecentMessage(Map<String, dynamic> item) {
    final createdAt = _dateOf(item);
    if (createdAt == null) return false;
    return createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)));
  }

  String _topicOf(Map<String, dynamic> item) {
    final subject = (item["subject"]?.toString() ?? "").trim();
    final taggedSubject = RegExp(r"^\[(.+?)\]\s*(.*)$").firstMatch(subject);
    if (taggedSubject != null) {
      final topic = taggedSubject.group(1)?.trim() ?? "";
      if (topic.isNotEmpty) return topic;
    }

    final body = (item["message"]?.toString() ?? "").trim();
    final taggedBody = RegExp(
      r"^Konu Türü:\s*(.+?)(?:\r?\n|$)",
    ).firstMatch(body);
    final topic = taggedBody?.group(1)?.trim() ?? "";
    return topic.isEmpty ? "Genel" : topic;
  }

  String _subjectOf(Map<String, dynamic> item) {
    final subject = (item["subject"]?.toString() ?? "").trim();
    if (subject.isEmpty) return "(Konu girilmemiş)";
    final taggedSubject = RegExp(r"^\[(.+?)\]\s*(.*)$").firstMatch(subject);
    if (taggedSubject == null) return subject;
    final clean = taggedSubject.group(2)?.trim() ?? "";
    return clean.isEmpty ? subject : clean;
  }

  String _messageBodyOf(Map<String, dynamic> item) {
    final body = (item["message"]?.toString() ?? "").trim();
    if (body.isEmpty) return "(Mesaj içeriği boş)";
    final cleaned = body.replaceFirst(
      RegExp(r"^Konu Türü:\s*.+?(?:\r?\n){1,2}"),
      "",
    );
    return cleaned.trim().isEmpty ? body : cleaned.trim();
  }

  String _senderNameOf(Map<String, dynamic> item) {
    final user = _userOf(item);
    final userName = user?["name"]?.toString().trim() ?? "";
    if (userName.isNotEmpty) return userName;
    final email = _emailOf(item);
    return email.isNotEmpty ? email : "Anonim Gönderim";
  }

  String _emailOf(Map<String, dynamic> item) {
    final direct = item["email"]?.toString().trim() ?? "";
    if (direct.isNotEmpty) return direct;
    final user = _userOf(item);
    return user?["email"]?.toString().trim() ?? "";
  }

  Map<String, dynamic>? _userOf(Map<String, dynamic> item) {
    final user = item["user"];
    return user is Map<String, dynamic> ? user : null;
  }

  DateTime? _dateOf(Map<String, dynamic> item) {
    final raw = item["created_at"]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString().trim() ?? "";
    if (raw.isEmpty) return "-";
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    final dd = date.day.toString().padLeft(2, "0");
    final mm = date.month.toString().padLeft(2, "0");
    final yyyy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, "0");
    final min = date.minute.toString().padLeft(2, "0");
    return "$dd.$mm.$yyyy $hh:$min";
  }

  String _preview(String text, int maxLength) {
    final normalized = text.replaceAll(RegExp(r"\s+"), " ").trim();
    if (normalized.length <= maxLength) return normalized;
    return "${normalized.substring(0, maxLength - 1)}…";
  }

  int _compareDateDesc(DateTime? a, DateTime? b, int aId, int bId) {
    if (a != null && b != null) {
      final compared = b.compareTo(a);
      if (compared != 0) return compared;
    } else if (a != null) {
      return -1;
    } else if (b != null) {
      return 1;
    }
    return bId.compareTo(aId);
  }

  int _compareDateAsc(DateTime? a, DateTime? b, int aId, int bId) {
    if (a != null && b != null) {
      final compared = a.compareTo(b);
      if (compared != 0) return compared;
    } else if (a != null) {
      return -1;
    } else if (b != null) {
      return 1;
    }
    return aId.compareTo(bId);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }
}
