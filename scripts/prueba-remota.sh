#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
export FINANCEBRO_DEVICE_ID="${FINANCEBRO_DEVICE_ID:-emulator-5554}"
export FINANCEBRO_PRUEBA_DEFINES="${FINANCEBRO_PRUEBA_DEFINES:-.secrets/prueba-real.json}"
test -f "$FINANCEBRO_PRUEBA_DEFINES" || { echo 'Falta el archivo privado de acceso remoto. Prepáralo con las credenciales de demostración de tu proyecto Firebase; no debe versionarse.'; exit 1; }
mkdir -p evidencia-local
./android/gradlew -p tooling/android-push :app:assembleDebug :app:assembleDebugAndroidTest --console=plain
adb -s "$FINANCEBRO_DEVICE_ID" install -r tooling/android-push/app/build/outputs/apk/debug/app-debug.apk
adb -s "$FINANCEBRO_DEVICE_ID" install -r tooling/android-push/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
# Permiso de la instalación de evaluación, no una respuesta falsa del repositorio push.
flutter build apk --debug --target=integration_test/flujo_remoto_test.dart --dart-define-from-file="$FINANCEBRO_PRUEBA_DEFINES" --dart-define=CAPTURE_EVIDENCE="${FINANCEBRO_GRABAR:-false}"
adb -s "$FINANCEBRO_DEVICE_ID" install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s "$FINANCEBRO_DEVICE_ID" shell pm grant ec.financebro.financebro android.permission.POST_NOTIFICATIONS
: > evidencia-local/e2e-remoto.log
node tooling/probar-push.mjs evidencia-local/e2e-remoto.log > evidencia-local/envio-push.log 2>&1 &
administrador=$!
trap 'kill "$administrador" 2>/dev/null || true' EXIT
flutter test integration_test/flujo_remoto_test.dart --dart-define-from-file="$FINANCEBRO_PRUEBA_DEFINES" --dart-define=CAPTURE_EVIDENCE="${FINANCEBRO_GRABAR:-false}" -d "$FINANCEBRO_DEVICE_ID" > evidencia-local/e2e-remoto.log 2>&1
wait "$administrador"
cat evidencia-local/e2e-remoto.log evidencia-local/envio-push.log
