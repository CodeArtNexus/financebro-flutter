#!/usr/bin/env bash
# Activar en la sesión actual: source scripts/env.sh
if [[ -z "${POSTULACION_TOOLCHAINS_DIR:-}" ]]; then
  if [[ -d "$HOME/Documents/Codex/toolchains" ]]; then
    POSTULACION_TOOLCHAINS_DIR="$HOME/Documents/Codex/toolchains"
  else
    POSTULACION_TOOLCHAINS_DIR="$HOME/.cache/financebro"
  fi
fi
export POSTULACION_TOOLCHAINS_DIR
if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
  JAVA_HOME="$(/usr/libexec/java_home -v 21)"
  export JAVA_HOME
fi
if [[ -z "${ANDROID_HOME:-}" ]]; then
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    ANDROID_HOME="$ANDROID_SDK_ROOT"
  elif [[ -d /opt/homebrew/share/android-commandlinetools ]]; then
    ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
  elif [[ "$(uname -s)" == Darwin ]]; then
    ANDROID_HOME="$HOME/Library/Android/sdk"
  else
    ANDROID_HOME="$HOME/Android/Sdk"
  fi
fi
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$POSTULACION_TOOLCHAINS_DIR/android-user}"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$POSTULACION_TOOLCHAINS_DIR/android-avd}"
export PUB_CACHE="${PUB_CACHE:-$POSTULACION_TOOLCHAINS_DIR/pub-cache}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$POSTULACION_TOOLCHAINS_DIR/gradle-cache}"
export FIREBASE_EMULATORS_PATH="${FIREBASE_EMULATORS_PATH:-$POSTULACION_TOOLCHAINS_DIR/firebase-emulators}"
export npm_config_cache="${npm_config_cache:-$POSTULACION_TOOLCHAINS_DIR/npm-cache}"
# Conservar herramientas configuradas en PATH; añadir ubicaciones existentes.
for bro_bin in /opt/homebrew/share/flutter/bin "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator" "$ANDROID_HOME/cmdline-tools/latest/bin" "$POSTULACION_TOOLCHAINS_DIR/firebase-cli/node_modules/.bin" "$PUB_CACHE/bin" /opt/homebrew/bin; do
  if [[ -d "$bro_bin" ]]; then export PATH="$bro_bin:$PATH"; fi
done
unset bro_bin
