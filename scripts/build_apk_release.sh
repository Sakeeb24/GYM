#!/usr/bin/env bash
set -e

CONFIG_FILE="config/env.example.json"
if [ -f "config/prod.json" ]; then
  CONFIG_FILE="config/prod.json"
elif [ -f "config/dev.json" ]; then
  CONFIG_FILE="config/dev.json"
fi

echo "==> Building Android Release APK with config from $CONFIG_FILE"
flutter build apk --release --dart-define-from-file="$CONFIG_FILE"
echo "==> Release APK build completed: build/app/outputs/flutter-apk/app-release.apk"
