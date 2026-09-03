# Deprecated — use repo-root scripts/dev-flutter-web.ps1 (single Customer web entry point).
& (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'scripts\dev-flutter-web.ps1') @args
