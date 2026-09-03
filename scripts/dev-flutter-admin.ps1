# Admin Flutter web — lib/main_admin.dart. Flutter picks a free port.
# Chrome 111+ (including 151) requires --remote-allow-origins=* or DWDS
# Debugger.enable times out after 5s ("Failed to connect to the web debug service").
# --web-browser-flag is supported by Flutter 3.44 (hidden unless: flutter run -h -v).
# --no-web-resources-cdn serves bundled CanvasKit locally (Flutter 3.44+).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location "$Root/mobile"
flutter run -t lib/main_admin.dart -d chrome --no-web-resources-cdn --web-browser-flag=--remote-allow-origins=* @args
