#!/usr/bin/env bash
# Environment variable check tests, in throwaway git repositories.
set -u
# shellcheck source=tests/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
# shellcheck source=tests/repository.sh
source "$(dirname "${BASH_SOURCE[0]}")/repository.sh"
SCRIPT="$ROOT/variables-env/check.sh"

run_check() { output=$(cd "$REPO" && BASE="$BASE" "$@" bash "$SCRIPT" 2>&1); code=$?; }
with_example() { printf '%s\n' "$@" > "$REPO/.env.example"; }
write_code() { mkdir -p "$REPO/$(dirname "$1")"; printf '%s\n' "${@:2}" > "$REPO/$1"; }

echo "Variables d'environnement"

new_repository; with_example '# Port du serveur' 'PORT=3000' 'export API_URL=http://localhost:3000'; commit_base
write_code src/main.ts 'const port = process.env.PORT;' "const apiUrl = import.meta.env['API_URL'] ?? process.env['API_URL'];"; commit_change; run_check env
expect "variables déclarées (avec ou sans export) : acceptées" 0 "" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/main.ts 'const port = process.env.PORT;' 'const databaseUrl = process.env.DATABASE_URL;'; commit_change; run_check env
expect "variable non déclarée : refusée, avec fichier et ligne" 1 "file=src/main.ts,line=2" "$code" "$output"
expect "  …le message nomme la variable" 1 "« DATABASE_URL » est lue ici" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/app.vue "const apiUrl = import.meta.env.VITE_API_URL;"; commit_change; run_check env
expect "import.meta.env (Vite) : vérifié" 1 "« VITE_API_URL »" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/auth.service.ts "const secret = this.configService.getOrThrow<string>('JWT_SECRET');" "const cached = cache.get('NOT_A_VARIABLE');"; commit_change; run_check env
expect "ConfigService de NestJS : vérifié, cache.get ignoré" 1 "« JWT_SECRET »" "$code" "$output"
if printf '%s' "$output" | grep -q NOT_A_VARIABLE; then fail "  …cache.get n'est pas une variable" "$output"; else pass "  …cache.get n'est pas une variable"; fi

new_repository; commit_base
write_code src/main.ts 'const databaseUrl = process.env.DATABASE_URL;'; commit_change; run_check env
expect "pas de .env.example : demande de le créer" 1 "n'a pas de .env.example" "$code" "$output"

new_repository; with_example 'PORT=3000'; write_code src/old.ts 'const legacyToken = process.env.LEGACY_TOKEN;'; commit_base
write_code src/old.ts 'const legacyToken = process.env.LEGACY_TOKEN;' 'export default legacyToken;'; commit_change; run_check env
expect "variable lue avant la PR : tolérée" 0 "" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/main.ts "if (process.env.NODE_ENV === 'production' || process.env.CI || process.env.GITHUB_SHA) {}"; commit_change; run_check env
expect "variables du système, de Node et de GitHub : ignorées" 0 "" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/main.spec.ts 'const token = process.env.TEST_ONLY;'; write_code test/setup.ts 'process.env.OTHER;'; commit_change; run_check env
expect "fichiers de test : ignorés" 0 "" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/main.ts 'const databaseUrl = process.env.DATABASE_URL;'; commit_change; run_check env IGNORED="DATABASE_*"
expect "variable ignorée par réglage (motif) : acceptée" 0 "" "$code" "$output"

new_repository; printf 'PORT=3000\n' > "$REPO/config.example"; commit_base
write_code src/main.ts 'const port = process.env.PORT;'; commit_change; run_check env EXAMPLE_FILE="config.example"
expect "autre fichier d'exemple par réglage : lu" 0 "" "$code" "$output"

new_repository; with_example 'PORT=3000'; commit_base
write_code src/main.ts 'const databaseUrl = process.env.DATABASE_URL;'; commit_change
summary_file=$(mktemp); run_check env GITHUB_STEP_SUMMARY="$summary_file"
expect "résumé de la PR écrit" 1 "" "$code" "$output"
if grep -q 'DATABASE_URL' "$summary_file"; then pass "  …avec la variable à déclarer"; else fail "  …avec la variable à déclarer" "$(cat "$summary_file")"; fi

report
