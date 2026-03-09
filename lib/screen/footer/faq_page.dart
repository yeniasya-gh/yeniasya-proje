import 'package:flutter/material.dart';

import '../../services/error/error_manager.dart';
import '../../services/faq_service.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final FaqService _service = FaqService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getActiveFaqs();
  }

  void _reload() {
    setState(() {
      _future = _service.getActiveFaqs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("SSS"),
        elevation: 1,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final parsed = ErrorManager.parseGraphQLError(
                snapshot.error.toString(),
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        parsed,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Tekrar Dene"),
                      ),
                    ],
                  ),
                ),
              );
            }

            final items = snapshot.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: Colors.black38,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Henüz eklenmiş bir SSS kaydı bulunmuyor.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Bu bölümde sık sorulan sorular yayınlandığında burada listelenecek.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      title: Text(
                        item["title"]?.toString() ?? "",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SelectableText(
                            item["description"]?.toString() ?? "",
                            style: const TextStyle(
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
