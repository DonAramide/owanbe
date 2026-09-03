# Customer Flutter web (lib/main.dart) — required on Chrome 111+ / 151.
# Plain `flutter run` → Chrome does NOT pass --remote-allow-origins=* and DWDS times out.
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\dev-flutter-web.ps1') @args
