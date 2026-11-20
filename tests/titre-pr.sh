#!/usr/bin/env bash
# Tests du contrôle de titre de PR.
set -u
# shellcheck source=tests/commun.sh
source "$(dirname "${BASH_SOURCE[0]}")/commun.sh"
SCRIPT="$RACINE/titre-pr/verifier.sh"

lancer() { sortie=$(env "$@" bash "$SCRIPT" 2>&1); code=$?; }

echo "Titre de PR"

for titre in "feat: ajouter l'export CSV" "fix(api): corriger le tri" "feat!: nouvelle URL" "chore(main): release 1.2.0" "docs: README"; do
  lancer TITRE="$titre"
  verifie "conforme : $titre" 0 "Titre conforme" "$code" "$sortie"
done

for titre in "Ajouter l'export CSV" "feat:sans espace" "feat: " "Feat: majuscule" "feature: x" "fix(): portée vide" ""; do
  lancer TITRE="$titre"
  verifie "refusé : « $titre »" 1 "Titre de PR non conforme" "$code" "$sortie"
done

lancer TITRE="Corrige le bouton d'envoi"
verifie "suggestion pour « Corrige le bouton d'envoi »" 1 "Essayez : « fix: corrige le bouton d'envoi »" "$code" "$sortie"
lancer TITRE="Add CSV export"
verifie "suggestion pour « Add CSV export »" 1 "Essayez : « feat: add CSV export »" "$code" "$sortie"
lancer TITRE="Feature: export CSV"
verifie "suggestion pour « Feature: export CSV »" 1 "Essayez : « feat: export CSV »" "$code" "$sortie"
lancer TITRE="[WIP] Documentation de l'API"
verifie "suggestion pour « [WIP] Documentation de l'API »" 1 "Essayez : « docs: documentation de l'API »" "$code" "$sortie"
lancer TITRE="API publique"
verifie "sigle conservé dans la suggestion" 1 "Essayez : « feat: API publique »" "$code" "$sortie"

lancer TITRE='Revert "feat: ajouter l'"'"'export CSV"'
verifie "titre du bouton « Revert » de GitHub : accepté" 0 "annulation" "$code" "$sortie"
lancer TITRE='Revert "Ajouter un truc"'
verifie "« Revert » d'un titre non conforme : refusé" 1 "non conforme" "$code" "$sortie"

lancer TITRE="Bump vite from 5.0.0 to 5.0.1" AUTEUR="dependabot[bot]"
verifie "robot non conforme : non bloqué" 0 "commit-message.prefix" "$code" "$sortie"
lancer TITRE="Bump vite from 5.0.0 to 5.0.1" AUTEUR="dependabot[bot]" IGNORER_BOTS=false
verifie "robot non conforme avec ignorer-bots=false : bloqué" 1 "non conforme" "$code" "$sortie"
lancer TITRE="Bump vite" AUTEUR="caroline"
verifie "humain non conforme : bloqué" 1 "non conforme" "$code" "$sortie"

lancer TITRE="refactor: découper" TYPES="feat fix"
verifie "types réglés : « refactor » refusé" 1 "types : feat fix" "$code" "$sortie"

lancer TITRE="feat: x" REGLAGE_SQUASH="COMMIT_OR_PR_TITLE"
verifie "réglage de squash risqué : avertissement" 0 "Default to pull request title" "$code" "$sortie"
lancer TITRE="feat: x" REGLAGE_SQUASH="PR_TITLE"
verifie "bon réglage de squash : pas d'avertissement" 0 "" "$code" "$sortie"
if printf '%s' "$sortie" | grep -q "Réglage de fusion"; then ko "  …aucun avertissement attendu" "$sortie"; else ok "  …aucun avertissement"; fi

# shellcheck disable=SC2016 # voulu : le titre contient une commande qui ne doit pas s'exécuter
lancer TITRE='feat: $(touch /tmp/constance-injection)'
verifie "titre avec commande : traité comme du texte" 0 "Titre conforme" "$code" "$sortie"
if [ ! -e /tmp/constance-injection ]; then ok "  …et la commande n'est pas exécutée"; else ko "  …la commande a été exécutée"; fi

bilan
