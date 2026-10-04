#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
export FIREBASE_STORAGE_EMULATOR_HOST="${FIREBASE_STORAGE_EMULATOR_HOST:-127.0.0.1:9199}"
USE_EMULATORS=true node tooling/sembrar.mjs
node functions/sembrar-local.js
flutter test integration_test/flujo_critico_test.dart \
  --dart-define=USE_EMULATORS=true --dart-define=ENABLE_LAB=true \
  -d "${FINANCEBRO_DISPOSITIVO:-emulator-5554}" \
  --dart-define="EMULATOR_HOST=${FINANCEBRO_HOST:-10.0.2.2}" \
  --dart-define="AUTH_PORT=${FIREBASE_AUTH_EMULATOR_HOST##*:}" \
  --dart-define="FIRESTORE_PORT=${FIRESTORE_EMULATOR_HOST##*:}" \
  --dart-define="FUNCTIONS_PORT=${FUNCTIONS_PORT:-5001}" \
  --dart-define="STORAGE_PORT=${FIREBASE_STORAGE_EMULATOR_HOST##*:}"
