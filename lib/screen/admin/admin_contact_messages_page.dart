import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin/admin_contact_message_service.dart';
import '../../services/error/error_manager.dart';
import 'admin_loading_indicator.dart';
import 'admin_user_detail_page.dart';

enum _ContactSourceFilter { all, linkedUser, anonymous }

enum _ContactReplyFilter { all, replied, unreplied }

enum _ContactSortOption { newestFirst, oldestFirst, replyNewestFirst, replyOldestFirst }

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
  Timer? _searchDebounce;
  int? _deletingId;
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalCount = 0;
  String _selectedTopic = _allTopics;
  _ContactSourceFilter _sourceFilter = _ContactSourceFilter.all;
  _ContactReplyFilter _replyFilter = _ContactReplyFilter.all;
  _ContactSortOption _sortOption = _ContactSortOption.newestFirst;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() => _loading = true);
    try {
      final requestedPage = page ?? _currentPage;
      final result = await _service.listMessagesPage(
        keyword: _searchCtrl.text,
        source: switch (_sourceFilter) {
          _ContactSourceFilter.all => "all",
          _ContactSourceFilter.linkedUser => "linked",
          _ContactSourceFilter.anonymous => "anonymous",
        },
        replyStatus: switch (_replyFilter) {
          _ContactReplyFilter.all => "all",
          _ContactReplyFilter.replied => "replied",
          _ContactReplyFilter.unreplied => "unreplied",
        },
        sort: switch (_sortOption) {
          _ContactSortOption.newestFirst => "created_desc",
          _ContactSortOption.oldestFirst => "created_asc",
          _ContactSortOption.replyNewestFirst => "reply_desc",
          _ContactSortOption.replyOldestFirst => "reply_asc",
        },
        startDate: _startDate,
        endDate: _endDate,
        page: requestedPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final totalPages = _totalPagesFor(result.totalCount, _pageSize);
      final safePage = totalPages == 0
          ? 1
          : requestedPage.clamp(1, totalPages);
      if (safePage != requestedPage) {
        if (mounted) {
          setState(() => _currentPage = safePage);
        }
        await _load(page: safePage);
        return;
      }
      setState(() {
        _messages = result.items;
        _totalCount = result.totalCount;
        _currentPage = safePage;
      });
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
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Text(
                    "Toplam: $_totalCount",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _messages.isEmpty ? null : _copyCurrentPageList,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text("Görüneni Kopyala"),
                ),
                IconButton(
                  tooltip: "Yenile",
                  onPressed: () => _load(page: _currentPage),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFiltersCard(),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const AdminLoadingIndicator()
              : _messages.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    Expanded(child: _buildTable(_messages)),
                    const SizedBox(height: 12),
                    _paginationBar(),
                  ],
                ),
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
          final wide = constraints.maxWidth >= 1180;
          final fieldWidth = wide
              ? ((constraints.maxWidth - 48) / 3).clamp(240.0, 360.0)
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
                      child: Text("Kullanıcılı"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSourceFilter.anonymous,
                      child: Text("Anonim"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sourceFilter = value);
                    _load(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<_ContactReplyFilter>(
                  initialValue: _replyFilter,
                  decoration: const InputDecoration(
                    labelText: "Cevap Durumu",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _ContactReplyFilter.all,
                      child: Text("Tümü"),
                    ),
                    DropdownMenuItem(
                      value: _ContactReplyFilter.replied,
                      child: Text("Cevaplanan"),
                    ),
                    DropdownMenuItem(
                      value: _ContactReplyFilter.unreplied,
                      child: Text("Cevapsız"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _replyFilter = value);
                    _load(page: 1);
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
                      child: Text("En yeni"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSortOption.oldestFirst,
                      child: Text("En eski"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSortOption.replyNewestFirst,
                      child: Text("Cevap yeni"),
                    ),
                    DropdownMenuItem(
                      value: _ContactSortOption.replyOldestFirst,
                      child: Text("Cevap eski"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortOption = value);
                    _load(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: DropdownButtonFormField<int>(
                  initialValue: _pageSize,
                  decoration: const InputDecoration(
                    labelText: "Sayfa Boyutu",
                    border: OutlineInputBorder(),
                  ),
                  items: const [10, 20, 50]
                      .map(
                        (size) => DropdownMenuItem(
                          value: size,
                          child: Text("$size / sayfa"),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _pageSize = value);
                    _load(page: 1);
                  },
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: OutlinedButton.icon(
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _startDate == null
                        ? "Tek tarih"
                        : "Başlangıç: ${_formatDateOnly(_startDate)}",
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: OutlinedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _endDate == null
                        ? "Bitiş"
                        : "Bitiş: ${_formatDateOnly(_endDate)}",
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: OutlinedButton.icon(
                  onPressed: (_startDate == null && _endDate == null)
                      ? null
                      : () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _load(page: 1);
                        },
                  icon: const Icon(Icons.clear_all_outlined),
                  label: const Text("Tarihleri Temizle"),
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
                      columnSpacing: 18,
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 104,
                      columns: const [
                        DataColumn(label: Text("Konu")),
                        DataColumn(label: Text("Gönderen")),
                        DataColumn(label: Text("Tarih")),
                        DataColumn(label: Text("Başlık")),
                        DataColumn(label: Text("Mesaj")),
                        DataColumn(label: Text("Cevap")),
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
                            DataCell(
                              SizedBox(
                                width: 190,
                                child: Text(
                                  _topicLabel(item),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 250,
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
                                    const SizedBox(height: 6),
                                    _sourceChip(_hasLinkedUser(item)),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(_formatDateTime(item["created_at"]))),
                            DataCell(
                              SizedBox(
                                width: 230,
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
                                width: 340,
                                child: Text(
                                  _preview(_messageBodyOf(item), 180),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(_replyStatusChip(item)),
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

  Widget _paginationBar() {
    final totalPages = _totalPagesFor(_totalCount, _pageSize);
    final safeTotalPages = totalPages == 0 ? 1 : totalPages;
    if (safeTotalPages <= 1) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text("Sayfa 1 / $safeTotalPages"),
      );
    }

    final canPrev = _currentPage > 1;
    final canNext = _currentPage < safeTotalPages;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Sayfa $_currentPage / $safeTotalPages"),
        Row(
          children: [
            IconButton(
              onPressed: canPrev ? () => _goToPage(_currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: canNext ? () => _goToPage(_currentPage + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
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
            _totalCount == 0
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
    final messageId = _asInt(item["id"]);
    if (messageId == null) return;
    final user = _userOf(item);
    final email = _emailOf(item);
    final messageBody = _messageBodyOf(item);
    final existingReply = _replyMessageOf(item);
    final replyAt = _replyAtOf(item);
    final replyUser = _replyUserOf(item);
    final replyCtrl = TextEditingController(text: existingReply);
    var replying = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                      _replyStatusChip(item),
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
                        if ((user?["phone"]?.toString().trim() ?? "")
                            .isNotEmpty)
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
                  const SizedBox(height: 12),
                  _detailSection(
                    "Cevap",
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (existingReply.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.reply_outlined,
                                      size: 18,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      replyAt.isEmpty
                                          ? "Cevaplandı"
                                          : "Cevaplandı • $replyAt",
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                if (replyUser != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    "Yanıtlayan: ${_replyUserLabel(replyUser)}",
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                SelectableText(
                                  existingReply,
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: replyCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: "Admin cevabı",
                            hintText: "Bu mesaja verilecek yanıtı yazın",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
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
              onPressed: () =>
                  _copyToClipboard(messageBody, "Mesaj kopyalandı."),
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
            TextButton.icon(
              onPressed: replying
                  ? null
                  : () async {
                      final reply = replyCtrl.text.trim();
                      if (reply.isEmpty) {
                        _showSnack("Cevap boş olamaz.", isError: true);
                        return;
                      }
                      setDialogState(() => replying = true);
                      try {
                        await _service.replyMessage(
                          id: messageId,
                          replyMessage: reply,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _load();
                        _showSnack("Cevap kaydedildi.");
                      } catch (error) {
                        _showSnack(
                          ErrorManager.parseGraphQLError(error.toString()),
                          isError: true,
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => replying = false);
                        }
                      }
                    },
              icon: replying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.reply_outlined),
              label: Text(
                existingReply.isEmpty ? "Yanıtla" : "Yanıtı Güncelle",
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Kapat"),
            ),
          ],
        ),
      ),
    );

    replyCtrl.dispose();
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

  Future<void> _copyCurrentPageList() async {
    final lines = <String>[
      "id\ttarih\tkonu\tbaslik\tgonderen\temail\tuser_id\tmesaj",
      for (final item in _messages)
        [
          item["id"]?.toString() ?? "",
          _formatDateTime(item["created_at"]),
          _topicLabel(item),
          _subjectOf(item),
          _senderNameOf(item),
          _emailOf(item),
          item["user_id"]?.toString() ?? "",
          _messageBodyOf(item).replaceAll("\t", " ").replaceAll("\n", " "),
        ].join("\t"),
    ];

    await _copyToClipboard(
      lines.join("\n"),
      "Görünen mesajlar panoya kopyalandı.",
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

  bool _hasReply(Map<String, dynamic> item) {
    return _replyMessageOf(item).isNotEmpty || _replyAtOf(item).isNotEmpty;
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

  String _topicLabel(Map<String, dynamic> item) {
    return _topicOf(item);
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

  String _replyMessageOf(Map<String, dynamic> item) {
    final reply = (item["reply_message"]?.toString() ?? "").trim();
    return reply;
  }

  String _replyAtOf(Map<String, dynamic> item) {
    final raw = item["reply_at"]?.toString().trim() ?? "";
    if (raw.isEmpty) return "";
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return "";
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(parsed.day)}.${two(parsed.month)}.${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}";
  }

  Map<String, dynamic>? _replyUserOf(Map<String, dynamic> item) {
    final replyUser = item["reply_user"];
    return replyUser is Map<String, dynamic> ? replyUser : null;
  }

  String _replyUserLabel(Map<String, dynamic> user) {
    final name = user["name"]?.toString().trim() ?? "";
    if (name.isNotEmpty) return name;
    final email = user["email"]?.toString().trim() ?? "";
    if (email.isNotEmpty) return email;
    return "Admin";
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

  Widget _replyStatusChip(Map<String, dynamic> item) {
    final reply = _replyMessageOf(item);
    final replied = reply.isNotEmpty;
    final color = replied ? Colors.green : Colors.orange;
    final label = replied ? "Cevaplandı" : "Bekliyor";
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

  DateTime? _dateOf(Map<String, dynamic> item) {
    final raw = item["created_at"]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) return "-";
    final yyyy = value.year.toString().padLeft(4, "0");
    final mm = value.month.toString().padLeft(2, "0");
    final dd = value.day.toString().padLeft(2, "0");
    return "$dd.$mm.$yyyy";
  }

  int _totalPagesFor(int totalCount, int pageSize) {
    if (totalCount <= 0) return 0;
    final safePageSize = pageSize < 1 ? 1 : pageSize;
    return ((totalCount + safePageSize - 1) ~/ safePageSize);
  }

  void _goToPage(int page) {
    final totalPages = _totalPagesFor(_totalCount, _pageSize);
    final safePage = page.clamp(1, totalPages == 0 ? 1 : totalPages);
    if (safePage == _currentPage) return;
    _load(page: safePage);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
    await _load(page: 1);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = picked;
      if (_startDate != null && _startDate!.isAfter(_endDate!)) {
        _startDate = _endDate;
      }
    });
    await _load(page: 1);
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
