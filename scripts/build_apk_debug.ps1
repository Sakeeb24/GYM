# scripts/build_apk_debug.ps1
# Build Android Debug APK with dart-defines

$ErrorActionPreference = "Stop"
$ConfigFile = If (Test-Path "config/dev.json") { "config/dev.json" } Else { "config/env.example.json" }

Write-Host "==> Building Android Debug APK with config from $ConfigFile" -ForegroundColor Cyan
flutter build apk --debug --dart-define-from-file=$ConfigFile
Write-Host "==> Debug APK build completed successfully!" -ForegroundColor Green
Write-Host "Artifact: build/app/outputs/flutter-apk/app-debug.apk" -ForegroundColor Yellow
