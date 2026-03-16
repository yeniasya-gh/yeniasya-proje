import 'package:flutter/material.dart';

import '../../services/upload_service.dart';

class AdminUploadProgressController extends ChangeNotifier {
  AdminUploadProgressController({
    required this.title,
    String initialMessage = "İşlem hazırlanıyor...",
  }) : _message = initialMessage;

  final String title;
  String _message;
  String? _detail;
  double? _progress;

  String get message => _message;
  String? get detail => _detail;
  double? get progress => _progress;

  void update({required String message, String? detail, double? progress}) {
    _message = message;
    _detail = detail;
    _progress = progress?.clamp(0, 1).toDouble();
    notifyListeners();
  }

  void trackUpload(String label, UploadProgressSnapshot snapshot) {
    switch (snapshot.stage) {
      case UploadStage.preparing:
        update(
          message: "$label hazırlanıyor...",
          detail: snapshot.filename,
          progress: 0,
        );
        break;
      case UploadStage.uploading:
        final fraction = snapshot.fraction;
        final detail = snapshot.totalBytes > 0
            ? "${UploadService.formatByteSize(snapshot.sentBytes)} / ${UploadService.formatByteSize(snapshot.totalBytes)}"
            : snapshot.filename;
        update(
          message: "$label yükleniyor...",
          detail: detail,
          progress: fraction,
        );
        break;
      case UploadStage.processing:
        update(
          message: "$label CDN tarafında işleniyor...",
          detail: "Yükleme tamamlandı, sunucu yanıtı bekleniyor.",
          progress: null,
        );
        break;
      case UploadStage.completed:
        update(
          message: "$label tamamlandı.",
          detail: snapshot.filename,
          progress: 1,
        );
        break;
    }
  }
}

Future<T> runAdminUploadTask<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(AdminUploadProgressController controller) task,
}) async {
  final controller = AdminUploadProgressController(title: title);
  NavigatorState? dialogNavigator;

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      dialogNavigator = Navigator.of(ctx, rootNavigator: true);
      return _AdminUploadProgressDialog(controller: controller);
    },
  );

  await Future<void>.delayed(Duration.zero);

  try {
    return await task(controller);
  } finally {
    if (dialogNavigator?.canPop() ?? false) {
      dialogNavigator?.pop();
    }
    await dialogFuture;
    controller.dispose();
  }
}

class _AdminUploadProgressDialog extends StatelessWidget {
  const _AdminUploadProgressDialog({required this.controller});

  final AdminUploadProgressController controller;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = controller.progress;
          final percent = progress == null ? null : (progress * 100).round();
          return AlertDialog(
            title: Text(controller.title),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: progress,
                      backgroundColor: const Color(0xFFF3E5E5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (percent != null)
                    Text(
                      "%$percent",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (controller.detail != null &&
                      controller.detail!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        controller.detail!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
