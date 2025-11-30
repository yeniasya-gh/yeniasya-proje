import 'dart:convert';

import 'package:flutter/material.dart';
import '../../utils/safe_image.dart';
import '../../services/upload_service.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> magazines;
  final List<Map<String, dynamic>> newspapers;
  final String initialQuery;

  const SearchScreen({
    super.key,
    required this.books,
    required this.magazines,
    required this.newspapers,
    this.initialQuery = "",
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
            hintText: "Kitap, dergi veya gazete ara",
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
              _section("Kitaplar", results.books),
              const SizedBox(height: 18),
              _section("Dergiler", results.magazines),
              const SizedBox(height: 18),
              _section("Gazeteler", results.newspapers),
            ],
          ),
        ),
      ),
    );
  }

  _ResultBuckets _filterResults(String q) {
    if (q.trim().isEmpty) {
      return _ResultBuckets([], [], []);
    }
    final lower = q.toLowerCase();
    final books = widget.books.where((b) {
      final t = (b["title"] ?? "").toString().toLowerCase();
      final a = (b["author_rel"]?["name"] ?? "").toString().toLowerCase();
      return t.contains(lower) || a.contains(lower);
    }).toList();

    final mags = widget.magazines.where((m) {
      final t = (m["name"] ?? "").toString().toLowerCase();
      final c = (m["category"] ?? "").toString().toLowerCase();
      return t.contains(lower) || c.contains(lower);
    }).toList();

    final news = widget.newspapers.where((n) {
      final d = (n["publish_date"] ?? "").toString().toLowerCase();
      final t = (n["title"] ?? "gazete").toLowerCase();
      return d.contains(lower) || t.contains(lower);
    }).toList();

    return _ResultBuckets(books, mags, news);
  }

  Widget _section(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text("Sonuç bulunamadı.", style: TextStyle(color: Colors.black54))
        else
          ...items.map((i) => _resultTile(i)),
      ],
    );
  }

  Widget _resultTile(Map<String, dynamic> item) {
    final title = (item["title"] ?? item["name"] ?? "Başlık").toString();
    final subtitle = (item["author_rel"]?["name"] ?? item["category"] ?? item["publish_date"] ?? "")
        .toString();
    final image = item["cover_url"] ??
        item["cover_image_url"] ??
        item["image_url"] ??
        "assets/images/gazete.jpg";

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 64,
          child: _image(image),
        ),
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        final type = item["title"] != null
            ? "book"
            : (item["name"] != null ? "magazine" : "newspaper");

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

  _ResultBuckets(this.books, this.magazines, this.newspapers);
}
