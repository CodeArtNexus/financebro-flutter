#!/usr/bin/env bash
# Activar en la sesión actual: source scripts/env.sh
export POSTULACION_TOOLCHAINS_DIR="${POSTULACION_TOOLCHAINS_DIR:-$HOME/Documents/Codex/toolchains}"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21)}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$POSTULACION_TOOLCHAINS_DIR/android-user}"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$POSTULACION_TOOLCHAINS_DIR/android-avd}"
export PUB_CACHE="${PUB_CACHE:-$POSTULACION_TOOLCHAINS_DIR/pub-cache}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$POSTULACION_TOOLCHAINS_DIR/gradle-cache}"
export FIREBASE_EMULATORS_PATH="${FIREBASE_EMULATORS_PATH:-$POSTULACION_TOOLCHAINS_DIR/firebase-emulators}"
export npm_config_cache="${npm_config_cache:-$POSTULACION_TOOLCHAINS_DIR/npm-cache}"
export PATH="/opt/homebrew/share/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$POSTULACION_TOOLCHAINS_DIR/firebase-cli/node_modules/.bin:$PUB_CACHE/bin:/opt/homebrew/bin:$PATH"
