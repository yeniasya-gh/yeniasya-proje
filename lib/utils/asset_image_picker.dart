import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class PickedImageFile {
  final String name;
  final Uint8List bytes;

  const PickedImageFile({required this.name, required this.bytes});
}

class AssetImagePicker {
  static const List<String> _allowedExtensions = ["png", "jpg", "jpeg", "webp"];
  static const int _maxBytes = 20 * 1024 * 1024; // 20MB

  /// Picks an image file (png/jpg/webp) and returns its bytes + original name.
  /// No file-system write is performed; upload logic should handle storage.
  static Future<PickedImageFile?> pickImageFile() async {
    return pickFile(allowedExtensions: _allowedExtensions);
  }

  /// Generic file picker for custom extensions. Returns null if cancelled.
  static Future<PickedImageFile?> pickFile({
    required List<String> allowedExtensions,
    int maxBytes = _maxBytes,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final ext = p.extension(picked.name).replaceFirst(".", "").toLowerCase();
    if (!allowedExtensions.map((e) => e.toLowerCase()).contains(ext)) {
      throw Exception("İzin verilmeyen dosya türü.");
    }

    Uint8List? bytes = picked.bytes;
    if (bytes == null) {
      final pickedPath = picked.path;
      if (pickedPath == null) {
        throw Exception("Seçilen dosya okunamadı.");
      }
      bytes = await File(pickedPath).readAsBytes();
    }

    if (bytes.length > maxBytes) {
      throw Exception("Dosya 20MB sınırını aşıyor.");
    }

    return PickedImageFile(name: picked.name, bytes: bytes);
  }
}
