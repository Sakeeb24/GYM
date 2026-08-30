#!/usr/bin/env bash
set -e

CONFIG_FILE="config/env.example.json"
if [ -f "config/dev.json" ]; then
  CONFIG_FILE="config/dev.json"
fi

echo "==> Launching LiftFlow with config from $CONFIG_FILE"
flutter run --dart-define-from-file="$CONFIG_FILE"
