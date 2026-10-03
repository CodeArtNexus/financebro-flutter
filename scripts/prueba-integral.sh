#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
USE_EMULATORS=true node tooling/sembrar.mjs
flutter test integration_test/flujo_critico_test.dart --dart-define=USE_EMULATORS=true --dart-define=ENABLE_LAB=true -d "${FINANCEBRO_DISPOSITIVO:-emulator-5554}"
