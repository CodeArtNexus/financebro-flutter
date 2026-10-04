#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
cd "$script_dir/.."
proyecto_bro=""
ejecutar_bro=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --proyecto) proyecto_bro="${2:?Indica el proyecto}"; shift 2;;
    --ejecutar) ejecutar_bro=true; shift;;
    *) printf '%s\n' 'Uso: publicar-banca.sh --proyecto ID [--ejecutar]' >&2; exit 2;;
  esac
done
[[ "$proyecto_bro" == "financebro-sb-20261003" ]] || { printf '%s\n' 'Selecciona el proyecto configurado en los clientes, o configura todos los clientes para otro proyecto primero.' >&2; exit 2; }
if [[ "$ejecutar_bro" != true ]]; then
  printf '%s\n' "Proyecto: $proyecto_bro" 'Vista previa: servidor, reglas, índices, Storage y Hosting.' 'No se modifica facturación. --ejecutar se utiliza después de autorizar costos y habilitar Blaze.'
  exit 0
fi
./scripts/preparar-publicacion.sh
tooling/node_modules/.bin/firebase deploy --project "$proyecto_bro" --only firestore,storage,functions,hosting
printf '%s\n' 'Esperar la creación de índices y verificar registro, transferencia y aprobación desde dos identidades.' 'Compilar los clientes remotos sin USE_EMULATORS. APNs se habilita por separado.'
