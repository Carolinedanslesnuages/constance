#!/usr/bin/env bash
# File naming check tests, in throwaway git repositories.
set -u
# shellcheck source=tests/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
# shellcheck source=tests/repository.sh
source "$(dirname "${BASH_SOURCE[0]}")/repository.sh"
SCRIPT="$ROOT/nommage-fichiers/check.sh"

run_check() { output=$(cd "$REPO" && BASE="$BASE" "$@" bash "$SCRIPT" 2>&1); code=$?; }

echo "Nommage des fichiers"

new_repository; commit_base
add_files src/user-service.ts src/user-service.spec.ts src/components/UserCard.vue src/styles/main-layout.css; commit_change; run_check env
expect "kebab-case et PascalCase.vue : acceptés" 0 "" "$code" "$output"

new_repository; commit_base
add_files src/userService.ts; commit_change; run_check env
expect "camelCase : refusé, avec proposition" 1 "Proposition : « user-service.ts »" "$code" "$output"

new_repository; commit_base
add_files src/HTTPClient.spec.ts; commit_change; run_check env
expect "sigle : découpé correctement" 1 "« http-client.spec.ts »" "$code" "$output"

new_repository; commit_base
add_files src/my_helper.js; commit_change; run_check env
expect "tiret bas : refusé" 1 "« my-helper.js »" "$code" "$output"

new_repository; commit_base
add_files src/components/user-card.vue; commit_change; run_check env
expect "composant Vue en kebab-case : refusé" 1 "Proposition : « UserCard.vue »" "$code" "$output"

new_repository; add_files src/oldName.ts; commit_base
echo "export const value = 1;" > "$REPO/src/oldName.ts"; commit_change; run_check env
expect "fichier existant mal nommé, modifié : toléré" 0 "" "$code" "$output"

new_repository; add_files src/old-name.ts; commit_base
git -C "$REPO" mv src/old-name.ts src/newName.ts; commit_change; run_check env
expect "renommage vers un mauvais nom : refusé" 1 "« new-name.ts »" "$code" "$output"

new_repository; commit_base
add_files src/db/migrations/1700000-InitSchema.ts src/types.d.ts .eslintrc.cjs README.md scripts/Deploy.sh; commit_change; run_check env
expect "migrations, .d.ts, fichiers cachés, extensions non vérifiées : ignorés" 0 "" "$code" "$output"

new_repository; commit_base
add_files scripts/Deploy.sh; commit_change; run_check env EXTENSIONS="sh"
expect "extension ajoutée par réglage (.sh) : vérifiée" 1 "« deploy.sh »" "$code" "$output"

new_repository; commit_base
add_files src/userService.ts; commit_change
summary_file=$(mktemp); run_check env GITHUB_STEP_SUMMARY="$summary_file"
expect "résumé de la PR écrit" 1 "" "$code" "$output"
if grep -q 'user-service.ts' "$summary_file"; then pass "  …avec le nom proposé"; else fail "  …avec le nom proposé" "$(cat "$summary_file")"; fi

report
