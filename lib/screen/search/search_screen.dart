import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/safe_image.dart';
import '../../services/access_provider.dart';
import '../../services/upload_service.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> newspapers;
  final List<Map<String, dynamic>> attachments;
  final String initialQuery;
  final bool hideMagazines;
  final bool hideNewspapers;

  const SearchScreen({
    super.key,
    required this.books,
    required this.magazines,
    required this.newspapers,
    required this.attachments,
    this.initialQuery = "",
    this.hideMagazines = false,
    this.hideNewspapers = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _controller;
  String _query = "";

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filterResults(_query);
    final access = context.watch<AccessProvider>();
    final hintSegments = [
      "Kitap",
      if (!widget.hideMagazines) "dergi",
      if (!widget.hideNewspapers) "gazete",
      "ek",
    ];
    final hintText = "${hintSegments.join(", ")} ara";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            suffixIcon: (_query.isNotEmpty)
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = "");
                    },
                  )
                : null,
          ),
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section("Kitaplar", results.books, "book", access: access),
              const SizedBox(height: 18),
              if (!widget.hideMagazines) ...[
                _section(
                  "Dergiler",
                  results.magazines,
                  "magazine",
                  access: access,
                ),
                const SizedBox(height: 18),
              ],
              if (!widget.hideNewspapers) ...[
                _section(
                  "Gazeteler",
                  results.newspapers,
                  "newspaper",
                  access: access,
                ),
                const SizedBox(height: 18),
              ],
              _section("Ekler", results.ekler, "ek", access: access),
            ],
          ),
        ),
      ),
    );
  }

  _ResultBuckets _filterResults(String q) {
    if (q.trim().isEmpty) {
      return _ResultBuckets([], [], [], []);
    }
    final lower = q.toLowerCase();
    final books = widget.books.where((b) {
      final t = (b["title"] ?? "").toString().toLowerCase();
      final a = (b["author_rel"]?["name"] ?? "").toString().toLowerCase();
      return t.contains(lower) || a.contains(lower);
    }).toList();

    final mags = widget.hideMagazines
        ? <Map<String, dynamic>>[]
        : widget.magazines.where((m) {
            final t = (m["name"] ?? "").toString().toLowerCase();
            final c = (m["category"] ?? "").toString().toLowerCase();
            return t.contains(lower) || c.contains(lower);
          }).toList();

    final news = widget.hideNewspapers
        ? <Map<String, dynamic>>[]
        : widget.newspapers.where((n) {
            final d = (n["publish_date"] ?? "").toString().toLowerCase();
            final t = (n["title"] ?? "gazete").toLowerCase();
            return d.contains(lower) || t.contains(lower);
          }).toList();

    final eks = widget.attachments.where((e) {
      final name = (e["ad"] ?? "").toString().toLowerCase();
      final desc = (e["aciklama"] ?? "").toString().toLowerCase();
      return name.contains(lower) || desc.contains(lower);
    }).toList();

    return _ResultBuckets(books, mags, news, eks);
  }

  Widget _section(
    String title,
    List<Map<String, dynamic>> items,
    String type, {
    required AccessProvider access,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            "Sonuç bulunamadı.",
            style: TextStyle(color: Colors.black54),
          )
        else
          ...items.map((i) => _resultTile(i, type, access: access)),
      ],
    );
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  String? _statusLabelFor(
    Map<String, dynamic> item,
    String type,
    AccessProvider access,
  ) {
    switch (type) {
      case "book":
        return access.hasAccess("book", itemId: _toInt(item["id"]))
            ? "Satın alındı"
            : null;
      case "magazine":
        return access.hasAccess("magazine", itemId: _toInt(item["id"]))
            ? "Abonelik aktif"
            : null;
      case "newspaper":
        return access.hasAccess("newspaper_subscription")
            ? "Abonelik aktif"
            : null;
      case "ek":
        return access.hasAccess("ek", itemId: _toInt(item["id"]))
            ? "Erişim aktif"
            : null;
      default:
        return null;
    }
  }

  Widget _resultTile(
    Map<String, dynamic> item,
    String type, {
    required AccessProvider access,
  }) {
    final title =
        (type == "ek"
                ? (item["ad"] ?? item["title"] ?? "Ek")
                : (item["title"] ?? item["name"] ?? "Başlık"))
            .toString();
    final subtitle =
        (type == "ek"
                ? (item["aciklama"] ??
                      item["description"] ??
                      item["publish_date"] ??
                      "")
                : (item["author_rel"]?["name"] ??
                      item["category"] ??
                      item["publish_date"] ??
                      ""))
            .toString();
    final image =
        (type == "ek"
                ? (item["photo_url"] ??
                      item["image_url"] ??
                      "assets/images/gazete.jpg")
                : (item["cover_url"] ??
                      item["cover_image_url"] ??
                      item["image_url"] ??
                      "assets/images/gazete.jpg"))
            .toString();

    final status = _statusLabelFor(item, type, access);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 48, height: 64, child: _image(image)),
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: status == null
          ? null
          : Text(
              status,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
      onTap: () {
        Navigator.pop(context, {"item": item, "type": type});
      },
    );
  }

  Widget _image(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFFE0E0E0),
        child: const Icon(Icons.image_not_supported),
      );
    }
    final normalized = UploadService.normalizeUrl(url);
    final isData = normalized.startsWith("data:image");
    if (isData) {
      return Image.memory(
        base64Decode(normalized.split(",").last),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return safeImage(
      normalized,
      fit: BoxFit.cover,
      fallbackIcon: Icons.broken_image,
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE0E0E0),
      child: const Icon(Icons.broken_image),
    );
  }
}

class _ResultBuckets {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> newspapers;
  final List<Map<String, dynamic>> ekler;

  _ResultBuckets(this.books, this.magazines, this.newspapers, this.ekler);
}
