# scripts/build_apk_release.ps1
# Build Android Release APK with dart-defines

$ErrorActionPreference = "Stop"
$ConfigFile = If (Test-Path "config/prod.json") { "config/prod.json" } ElseIf (Test-Path "config/dev.json") { "config/dev.json" } Else { "config/env.example.json" }

Write-Host "==> Building Android Release APK with config from $ConfigFile" -ForegroundColor Cyan
flutter build apk --release --dart-define-from-file=$ConfigFile
Write-Host "==> Release APK build completed successfully!" -ForegroundColor Green
Write-Host "Artifact: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Yellow
