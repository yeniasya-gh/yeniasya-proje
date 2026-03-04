# yeniasya

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Runtime Mail Config (dart-define)

Mail endpoint bilgileri artık sabit kod yerine `dart-define` ile override edilebilir.

```bash
flutter run \
  --dart-define=MAIL_API_URL=https://cdn.yeniasyadigital.com/mail/send \
  --dart-define=MAIL_ORDER_SUMMARY_API_URL=https://cdn.yeniasyadigital.com/mail/order-summary \
  --dart-define=MAIL_WELCOME_API_URL=https://cdn.yeniasyadigital.com/mail/welcome \
  --dart-define=MAIL_API_TOKEN=your-mail-token \
  --dart-define=MAIL_FROM_NAME="Yeni Asya Dijital"
```

Unutma riskini kaldırmak için önerilen kullanım:

1. `tool/dart_defines.example.json` dosyasındaki değerleri doldur.
2. Uygulamayı script ile çalıştır:

```bash
./tool/run_android.sh
```

Release APK:

```bash
./tool/build_apk_release.sh
```
