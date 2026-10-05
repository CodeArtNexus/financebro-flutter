#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
./scripts/check.sh
node tooling/comprobar-limites.mjs
npm --prefix functions test
npm --prefix admin test
node tooling/preparar-videos.mjs
VITE_USE_EMULATORS=false npm --prefix admin run build
node --check functions/src/index.js
node --check functions/src/chequera.js
printf '%s\n' 'Preparación completada. No se desplegó ni se activó facturación.' 'Componentes activos: reglas, índices, almacenamiento privado, banca, avisos y panel. Las tareas programadas permanecen deshabilitadas.'
