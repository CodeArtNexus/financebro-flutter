#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
mkdir -p .secrets/servidor/tmp
export TMPDIR="$PWD/.secrets/servidor/tmp"
argumentos_bro=(emulators:start --only auth,firestore,functions,storage --project demo-financebro --export-on-exit "$PWD/.secrets/servidor/respaldo")
if [[ -f .secrets/servidor/respaldo/firebase-export-metadata.json ]]; then
  argumentos_bro+=(--import "$PWD/.secrets/servidor/respaldo")
fi
tooling/node_modules/.bin/firebase "${argumentos_bro[@]}"
