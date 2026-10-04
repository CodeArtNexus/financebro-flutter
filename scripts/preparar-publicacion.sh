#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
./scripts/check.sh
npm --prefix functions test
npm --prefix admin test
VITE_USE_EMULATORS=false npm --prefix admin run build
node --check functions/src/index.js
node --check functions/src/chequera.js
printf '%s\n' 'Preparación completada. No se desplegó ni se activó facturación.' 'Componentes: reglas, índices, almacenamiento privado, banca, avisos, tres tareas y panel.'
