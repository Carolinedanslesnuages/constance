#!/usr/bin/env bash
# Pull request title check tests.
set -u
# shellcheck source=tests/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
SCRIPT="$ROOT/titre-pr/check.sh"

run_check() { output=$(env "$@" bash "$SCRIPT" 2>&1); code=$?; }

echo "Titre de PR"

for title in "feat: ajouter l'export CSV" "fix(api): corriger le tri" "feat!: nouvelle URL" "chore(main): release 1.2.0" "docs: README"; do
  run_check TITLE="$title"
  expect "conforme : $title" 0 "Titre conforme" "$code" "$output"
done

for title in "Ajouter l'export CSV" "feat:sans espace" "feat: " "Feat: majuscule" "feature: x" "fix(): portée vide" ""; do
  run_check TITLE="$title"
  expect "refusé : « $title »" 1 "Titre de PR non conforme" "$code" "$output"
done

run_check TITLE="Corrige le bouton d'envoi"
expect "suggestion pour « Corrige le bouton d'envoi »" 1 "Essayez : « fix: corrige le bouton d'envoi »" "$code" "$output"
run_check TITLE="Add CSV export"
expect "suggestion pour « Add CSV export »" 1 "Essayez : « feat: add CSV export »" "$code" "$output"
run_check TITLE="Feature: export CSV"
expect "suggestion pour « Feature: export CSV »" 1 "Essayez : « feat: export CSV »" "$code" "$output"
run_check TITLE="[WIP] Documentation de l'API"
expect "suggestion pour « [WIP] Documentation de l'API »" 1 "Essayez : « docs: documentation de l'API »" "$code" "$output"
run_check TITLE="API publique"
expect "sigle conservé dans la suggestion" 1 "Essayez : « feat: API publique »" "$code" "$output"

run_check TITLE='Revert "feat: ajouter l'"'"'export CSV"'
expect "titre du bouton « Revert » de GitHub : accepté" 0 "annulation" "$code" "$output"
run_check TITLE='Revert "Ajouter un truc"'
expect "« Revert » d'un titre non conforme : refusé" 1 "non conforme" "$code" "$output"

run_check TITLE="Bump vite from 5.0.0 to 5.0.1" AUTHOR="dependabot[bot]"
expect "robot non conforme : non bloqué" 0 "commit-message.prefix" "$code" "$output"
run_check TITLE="Bump vite from 5.0.0 to 5.0.1" AUTHOR="dependabot[bot]" IGNORE_BOTS=false
expect "robot non conforme avec ignorer-bots=false : bloqué" 1 "non conforme" "$code" "$output"
run_check TITLE="Bump vite" AUTHOR="caroline"
expect "humain non conforme : bloqué" 1 "non conforme" "$code" "$output"

run_check TITLE="refactor: découper" TYPES="feat fix"
expect "types réglés : « refactor » refusé" 1 "types : feat fix" "$code" "$output"

run_check TITLE="feat: x" SQUASH_SETTING="COMMIT_OR_PR_TITLE"
expect "réglage de squash risqué : avertissement" 0 "Default to pull request title" "$code" "$output"
run_check TITLE="feat: x" SQUASH_SETTING="PR_TITLE"
expect "bon réglage de squash : pas d'avertissement" 0 "" "$code" "$output"
if printf '%s' "$output" | grep -q "Réglage de fusion"; then fail "  …aucun avertissement attendu" "$output"; else pass "  …aucun avertissement"; fi

# shellcheck disable=SC2016 # intended: the title holds a command that must never run
run_check TITLE='feat: $(touch /tmp/constance-injection)'
expect "titre avec commande : traité comme du texte" 0 "Titre conforme" "$code" "$output"
if [ ! -e /tmp/constance-injection ]; then pass "  …et la commande n'est pas exécutée"; else fail "  …la commande a été exécutée"; fi

report
