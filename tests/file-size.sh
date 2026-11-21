#!/usr/bin/env bash
# File size check tests, in throwaway git repositories.
set -u
# shellcheck source=tests/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
SCRIPT="$ROOT/taille-fichiers/check.sh"

write_lines() { local number; for number in $(seq 1 "$1"); do echo "const value$number = $number"; done; }

# new_repository creates a throwaway repository in $REPO; commit_base stores the base commit in $BASE.
new_repository() {
  REPO=$(mktemp -d)
  git -C "$REPO" init -q
  git -C "$REPO" config user.email essai@exemple.fr
  git -C "$REPO" config user.name essai
}
commit_base() { git -C "$REPO" add -A && git -C "$REPO" commit -q --allow-empty -m base && BASE=$(git -C "$REPO" rev-parse HEAD); }
commit_change() { git -C "$REPO" add -A && git -C "$REPO" commit -q -m change; }
run_check() { output=$(cd "$REPO" && BASE="$BASE" "$@" bash "$SCRIPT" 2>&1); code=$?; }

echo "Taille des fichiers"

new_repository; commit_base
write_lines 401 > "$REPO/nouveau.ts"; commit_change; run_check env
expect "nouveau fichier de code de 401 lignes : bloqué" 1 "Fichier trop long::401 lignes" "$code" "$output"

new_repository; commit_base
write_lines 400 > "$REPO/limite.ts"; commit_change; run_check env
expect "nouveau fichier de 400 lignes : accepté, avec alerte" 0 "Fichier proche de la limite::400 lignes" "$code" "$output"

new_repository; commit_base
write_lines 300 > "$REPO/petit.ts"; commit_change; run_check env
expect "fichier de 300 lignes : accepté sans alerte" 0 "" "$code" "$output"
if [ -z "$output" ]; then pass "  …et rien n'est affiché"; else fail "  …et rien n'est affiché" "$output"; fi

new_repository; write_lines 450 > "$REPO/ancien.ts"; commit_base
sed -i.bak 's/const value1 = 1/const value1 = 100/' "$REPO/ancien.ts" && rm "$REPO/ancien.ts.bak"; commit_change; run_check env
expect "fichier long existant, modifié sans grossir : toléré" 0 "Fichier long toléré::450 lignes" "$code" "$output"

new_repository; write_lines 450 > "$REPO/ancien.ts"; commit_base
echo "const extra = 0" >> "$REPO/ancien.ts"; commit_change; run_check env
expect "fichier long existant qui grossit : bloqué" 1 "Fichier trop long::451 lignes" "$code" "$output"

new_repository; write_lines 450 > "$REPO/ancien.ts"; commit_base
git -C "$REPO" mv ancien.ts renomme.ts; commit_change; run_check env
expect "fichier long seulement renommé : toléré (défaut corrigé)" 0 "ex-ancien.ts" "$code" "$output"

new_repository; mkdir -p "$REPO/src"; write_lines 450 > "$REPO/src/ancien.ts"; commit_base
mkdir -p "$REPO/lib"; git -C "$REPO" mv src/ancien.ts lib/deplace.ts; commit_change; run_check env
expect "fichier long déplacé de dossier : toléré" 0 "Fichier long toléré" "$code" "$output"

new_repository; commit_base
write_lines 550 > "$REPO/calcul.spec.ts"; commit_change; run_check env
expect "fichier de test de 550 lignes : accepté (limite 600)" 0 "" "$code" "$output"

new_repository; commit_base
write_lines 601 > "$REPO/calcul.test.ts"; commit_change; run_check env
expect "fichier de test de 601 lignes : bloqué" 1 "fichier de test" "$code" "$output"

new_repository; commit_base
write_lines 1000 > "$REPO/types.d.ts"; mkdir -p "$REPO/db/migrations"; write_lines 1000 > "$REPO/db/migrations/001.ts"; commit_change; run_check env
expect "fichiers exclus (.d.ts, migrations) : ignorés" 0 "" "$code" "$output"

new_repository; commit_base
write_lines 1000 > "$REPO/main.go"; commit_change; run_check env
expect "extension non comptée (.go) : ignorée par défaut" 0 "" "$code" "$output"
run_check env EXTENSIONS="go"
expect "extension ajoutée par réglage (.go) : bloquée" 1 "main.go" "$code" "$output"

new_repository; commit_base
{ write_lines 380; for _ in $(seq 1 100); do echo; echo "   "; done; } > "$REPO/aere.ts"; commit_change; run_check env
expect "lignes vides non comptées (380 lignes + 200 vides)" 0 "380 lignes" "$code" "$output"

new_repository; commit_base
write_lines 401 > "$REPO/mon fichier.ts"; commit_change; run_check env
expect "nom de fichier avec espace : traité" 1 "mon fichier.ts" "$code" "$output"

new_repository; commit_base
write_lines 120 > "$REPO/court.ts"; commit_change; run_check env MAX_CODE=100
expect "seuil réglé à 100 lignes : 120 bloqué" 1 "maximum 100" "$code" "$output"

new_repository; commit_base
write_lines 401 > "$REPO/long.ts"; commit_change
summary_file=$(mktemp); run_check env GITHUB_STEP_SUMMARY="$summary_file"
expect "résumé de la PR écrit" 1 "" "$code" "$output"
if grep -q '🔴 trop long' "$summary_file"; then pass "  …avec la ligne du fichier trop long"; else fail "  …avec la ligne du fichier trop long" "$(cat "$summary_file")"; fi

report
