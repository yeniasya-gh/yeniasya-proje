import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/admin/admin_magazine_service.dart';
import '../../services/access_provider.dart';
import '../../services/error/error_manager.dart';
import '../../services/secure_file_service.dart';
import '../../services/upload_service.dart';
import '../../utils/safe_image.dart';
import '../profile/pdf_viewer_screen.dart';

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
  bool _opening = false;

  Future<void> _openPdf(BuildContext context, String fileUrl, String title) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (!kIsWeb) {
        await SecureFileService.instance.getPdfBytes(
          url: fileUrl,
          isPrivate: true,
        );
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            url: fileUrl,
            title: title,
            isPrivate: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya açılamadı: ${ErrorManager.parseGraphQLError(e.toString())}")),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dergi Sayıları"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service.getIssues(widget.magazineId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Sayılar yüklenemedi: ${snapshot.error}"));
          }
          final issues = snapshot.data ?? [];
          if (issues.isEmpty) {
            return const Center(child: Text("Henüz sayı eklenmedi."));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: issues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final issue = issues[i];
              final issueId = issue["id"] as int?;
              final issueNumber = issue["issue_number"]?.toString() ?? "";
              final imageUrl = issue["photo_url"]?.toString() ?? widget.magazineCoverUrl ?? "";
              final fileUrl = issue["file_url"]?.toString() ?? "";
              final hasAccess = access.hasAccess("magazine_issue", itemId: issueId);

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Sayı $issueNumber",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Abonelik ile erişilir",
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            if (hasAccess)
                              const Padding(
                                padding: EdgeInsets.only(top: 6.0),
                                child: Text(
                                  "Sahip",
                                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        height: 40,
                        child: hasAccess
                            ? OutlinedButton(
                                onPressed: fileUrl.isEmpty
                                    ? null
                                    : () => _openPdf(context, UploadService.normalizeUrl(fileUrl), "Sayı $issueNumber"),
                                child: _opening
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text("Görüntüle"),
                              )
                            : ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Abonelik için dergi detayından Abone Ol'a basın.")),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text("Abone Ol", style: TextStyle(color: Colors.white)),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
