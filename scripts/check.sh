#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
if [[ ! -f pubspec.yaml ]]; then
  printf '%s\n' 'Preparación terminada. La verificación de la solución estará disponible después de crear el proyecto Flutter.' >&2
  exit 2
fi
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
