#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
exec emulator -avd "${POSTULACION_AVD_NAME:-bi_flutter_api36}" -no-boot-anim -gpu auto
