#!/usr/bin/env bash
set -e

CONFIG_FILE="config/env.example.json"
if [ -f "config/dev.json" ]; then
  CONFIG_FILE="config/dev.json"
fi

echo "==> Building Android Debug APK with config from $CONFIG_FILE"
flutter build apk --debug --dart-define-from-file="$CONFIG_FILE"
echo "==> Debug APK build completed: build/app/outputs/flutter-apk/app-debug.apk"
