import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:YeniAsya/services/upload_service.dart';

class _FakeStreamingClient extends http.BaseClient {
  _FakeStreamingClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

Future<void> _drainRequest(http.BaseRequest request) async {
  await request.finalize().drain<void>();
}

void main() {
  test('uploadPublic reports progress stages and returns uploaded url', () async {
    final snapshots = <UploadProgressSnapshot>[];
    final client = _FakeStreamingClient((request) async {
      await _drainRequest(request);
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'ok': true,
              'url': 'https://cdn.example.com/kitap/public/test.pdf',
            }),
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = UploadService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    final url = await service.uploadPublic(
      type: UploadFileType.book,
      bytes: Uint8List.fromList(List<int>.generate(2048, (index) => index % 255)),
      filename: 'test.pdf',
      onProgress: snapshots.add,
    );

    expect(url, 'https://cdn.example.com/kitap/public/test.pdf');
    expect(snapshots.first.stage, UploadStage.preparing);
    expect(
      snapshots.any((snapshot) => snapshot.stage == UploadStage.uploading),
      isTrue,
    );
    expect(snapshots.any((snapshot) => snapshot.stage == UploadStage.processing), isTrue);
    expect(snapshots.last.stage, UploadStage.completed);
  });

  test('uploadPublic maps 429 responses to friendly message', () async {
    final client = _FakeStreamingClient((request) async {
      await _drainRequest(request);
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({'ok': false, 'error': 'Too many upload attempts.'}),
          ),
        ),
        429,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = UploadService(
      baseUrl: 'https://cdn.example.com',
      client: client,
    );

    expect(
      () => service.uploadPublic(
        type: UploadFileType.book,
        bytes: Uint8List.fromList(List<int>.filled(512, 1)),
        filename: 'test.pdf',
      ),
      throwsA(
        predicate(
          (error) => error.toString().contains(
            'Çok fazla yükleme denemesi yapıldı',
          ),
        ),
      ),
    );
  });
}
