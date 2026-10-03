#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
./scripts/check.sh
HOOK
chmod +x .git/hooks/pre-commit
printf '%s\n' 'Verificación previa al commit instalada en este clon.'
