# Admin Flutter web (lib/main_admin.dart) — required on Chrome 111+ / 151.
# Plain `flutter run -t lib/main_admin.dart` → Chrome does NOT pass --remote-allow-origins=* and DWDS times out.
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\dev-flutter-admin.ps1') @args
