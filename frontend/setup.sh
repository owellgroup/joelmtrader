#!/usr/bin/env bash
# One-time: generate the platform folders (windows/web/android/...) around the provided lib/ code.
set -e
cd "$(dirname "$0")"
flutter create --project-name waya_fx_bot --org com.wayaspot --platforms=windows,web,android,ios,macos,linux .
flutter pub get
echo "Done. Run:  flutter run -d windows   (or: flutter run -d chrome)"
