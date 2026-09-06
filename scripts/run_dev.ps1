# scripts/run_dev.ps1
# Run Flutter app in development mode on connected device

$ErrorActionPreference = "Stop"
$ConfigFile = If (Test-Path "config/dev.json") { "config/dev.json" } Else { "config/env.example.json" }

Write-Host "==> Launching LiftFlow with config from $ConfigFile" -ForegroundColor Cyan
flutter run --dart-define-from-file=$ConfigFile
