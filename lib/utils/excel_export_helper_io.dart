import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> exportExcelBytes(Uint8List bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final filePath = p.join(directory.path, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  try {
    await Share.shareXFiles([XFile(filePath)], text: 'Excel export hazır.');
  } catch (_) {
    // Paylaşım desteği olmayan platformlarda dosya yine kaydedilmiş olur.
  }

  return filePath;
}
