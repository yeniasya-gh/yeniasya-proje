import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/access_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/upload_service.dart';
import '../../utils/safe_image.dart';
import '../../models/cart_item.dart';
import '../profile/pdf_viewer_screen.dart';
import 'product_detail_screen.dart';

class MagazineIssuesScreen extends StatefulWidget {
  final int magazineId;
  final String magazineTitle;
  final String? magazineCoverUrl;

  const MagazineIssuesScreen({
    super.key,
    required this.magazineId,
    required this.magazineTitle,
    this.magazineCoverUrl,
  });

  @override
  State<MagazineIssuesScreen> createState() => _MagazineIssuesScreenState();
}

class _MagazineIssuesScreenState extends State<MagazineIssuesScreen> {
  final _service = AdminMagazineService();
  String? _openingIssueKey;
  late final Future<List<Map<String, dynamic>>> _issuesFuture;
  int? _selectedYear;

  bool get _busy => _openingIssueKey != null;

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _issuesFuture = _service.getPublicIssues(widget.magazineId);
  }

  DateTime? _issueDate(Map<String, dynamic> issue) {
    final raw =
        issue["added_at"]?.toString() ??
        issue["publish_date"]?.toString() ??
        issue["created_at"]?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? _issueYear(Map<String, dynamic> issue) {
    final explicit = issue["publish_year"];
    if (explicit is int) return explicit;
    if (explicit != null) return int.tryParse(explicit.toString());
    return _issueDate(issue)?.year;
  }

  bool _isWithinAccessWindow({
    required DateTime issueDate,
    required DateTime start,
    required DateTime end,
  }) {
    final issueDay = DateTime(issueDate.year, issueDate.month, issueDate.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !issueDay.isBefore(startDay) && !issueDay.isAfter(endDay);
  }

  Future<void> _openPdf(
    BuildContext context,
    String fileUrl,
    String title, {
    required String issueKey,
  }) async {
    if (_busy) return;
    setState(() => _openingIssueKey = issueKey);
    try {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfViewerScreen(url: fileUrl, title: title, isPrivate: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Dosya açılamadı: ${ErrorManager.parseGraphQLError(e.toString())}",
          ),
        ),
      );
    } finally {
      if (mounted && _openingIssueKey == issueKey) {
        setState(() => _openingIssueKey = null);
      }
    }
  }

  void _openIssueDetail({
    required BuildContext context,
    required Map<String, dynamic> issue,
    required String issueNumber,
    required String imageUrl,
  }) {
    final issueId = _toInt(issue["id"]);
    if (issueId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sayı detayı açılamadı.")));
      return;
    }

    final title = issueNumber.isEmpty
        ? "${widget.magazineTitle} - Sayı"
        : "${widget.magazineTitle} - Sayı $issueNumber";

    final rawPrice = issue["price"];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? "") ?? 0;
    final description = (issue["description"] ?? "").toString().trim().isEmpty
        ? "Bu dergi sayısına abonelik ile erişilir."
        : (issue["description"] ?? "").toString().trim();
    final issueDate =
        issue["added_at"]?.toString() ??
        issue["publish_date"]?.toString() ??
        issue["created_at"]?.toString();

    final detail = ProductDetail(
      id: "mag-issue-$issueId",
      title: title,
      subtitle: widget.magazineTitle,
      description: description,
      imageUrl: UploadService.normalizeUrl(imageUrl),
      price: price,
      type: CartItemType.magazineIssue,
      metadata: {
        "productId": issueId,
        "magazineId": widget.magazineId,
        "issueDate": issueDate,
      },
      actionLabel: "Sepete Ekle",
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(detail: detail)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();
    final start = access.startDate("magazine", itemId: widget.magazineId);
    final end = access.expiry("magazine", itemId: widget.magazineId);
    final hasMagazineAccess = access.hasAccess(
      "magazine",
      itemId: widget.magazineId,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Dergi Sayıları")),
      body: SafeArea(
        top: false,
        bottom: true,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _issuesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text("Sayılar yüklenemedi: ${snapshot.error}"),
              );
            }
            final issues = snapshot.data ?? [];
            if (issues.isEmpty) {
              return const Center(child: Text("Henüz sayı eklenmedi."));
            }

            final years =
                issues.map(_issueYear).whereType<int>().toSet().toList()
                  ..sort((a, b) => b.compareTo(a));
            final selectedYear = years.contains(_selectedYear)
                ? _selectedYear
                : null;
            final filteredIssues = selectedYear == null
                ? issues
                : issues
                      .where((issue) => _issueYear(issue) == selectedYear)
                      .toList();

            return Column(
              children: [
                if (years.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: selectedYear,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: "Yıl",
                              filled: true,
                              fillColor: const Color(0xFFF8F8F8),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("Tüm Yıllar"),
                              ),
                              ...years.map(
                                (year) => DropdownMenuItem<int?>(
                                  value: year,
                                  child: Text(year.toString()),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedYear = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredIssues.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              "Seçilen yıla ait dergi sayısı bulunamadı.",
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredIssues.length,
                          separatorBuilder: (_, __) => const SizedBox(
                            height: 12,
                          ),
                          itemBuilder: (_, i) {
                            final issue = filteredIssues[i];
                            final issueYear = _issueYear(issue);
                            final issueId = _toInt(issue["id"]);
                            final issueNumber =
                                issue["issue_number"]?.toString() ?? "";
                            final imageUrl =
                                issue["photo_url"]?.toString() ??
                                widget.magazineCoverUrl ??
                                "";
                            final directIssueAccess = access.hasAccess(
                              "magazine_issue",
                              itemId: issueId,
                            );
                            final issueDate = _issueDate(issue);
                            final windowAccess =
                                hasMagazineAccess &&
                                start != null &&
                                end != null &&
                                issueDate != null &&
                                _isWithinAccessWindow(
                                  issueDate: issueDate,
                                  start: start,
                                  end: end,
                                );
                            final canView = directIssueAccess || windowAccess;

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: safeImage(
                                        UploadService.normalizeUrl(imageUrl),
                                        width: 70,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        fallbackIcon: Icons.menu_book,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Sayı $issueNumber",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (issueYear != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6.0,
                                              ),
                                              child: Text(
                                                "$issueYear yılı",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                          if (canView)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 6.0),
                                              child: Text(
                                                "Sahip",
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 110,
                                      height: 40,
                                      child: OutlinedButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _openIssueDetail(
                                                context: context,
                                                issue: issue,
                                                issueNumber: issueNumber,
                                                imageUrl: imageUrl,
                                              ),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                          alignment: Alignment.center,
                                        ),
                                        child: const Center(
                                          child: Text("Detay"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
