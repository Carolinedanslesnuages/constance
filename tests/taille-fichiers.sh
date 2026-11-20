#!/usr/bin/env bash
# Tests du contrôle de taille, dans des dépôts git jetables.
set -u
# shellcheck source=tests/commun.sh
source "$(dirname "${BASH_SOURCE[0]}")/commun.sh"
SCRIPT="$RACINE/taille-fichiers/verifier.sh"

lignes() { local i; for i in $(seq 1 "$1"); do echo "const a$i = $i"; done; }

# Crée un dépôt avec un commit de base ; renvoie son chemin dans $DEPOT et le commit dans $BASE.
nouveau_depot() {
  DEPOT=$(mktemp -d)
  git -C "$DEPOT" init -q
  git -C "$DEPOT" config user.email essai@exemple.fr
  git -C "$DEPOT" config user.name essai
}
base() { git -C "$DEPOT" add -A && git -C "$DEPOT" commit -q --allow-empty -m base && BASE=$(git -C "$DEPOT" rev-parse HEAD); }
pr() { git -C "$DEPOT" add -A && git -C "$DEPOT" commit -q -m pr; }
lancer() { sortie=$(cd "$DEPOT" && BASE="$BASE" "$@" bash "$SCRIPT" 2>&1); code=$?; }

echo "Taille des fichiers"

nouveau_depot; base
lignes 401 > "$DEPOT/nouveau.ts"; pr; lancer env
verifie "nouveau fichier de code de 401 lignes : bloqué" 1 "Fichier trop long::401 lignes" "$code" "$sortie"

nouveau_depot; base
lignes 400 > "$DEPOT/limite.ts"; pr; lancer env
verifie "nouveau fichier de 400 lignes : accepté, avec alerte" 0 "Fichier proche de la limite::400 lignes" "$code" "$sortie"

nouveau_depot; base
lignes 300 > "$DEPOT/petit.ts"; pr; lancer env
verifie "fichier de 300 lignes : accepté sans alerte" 0 "" "$code" "$sortie"
if [ -z "$sortie" ]; then ok "  …et rien n'est affiché"; else ko "  …et rien n'est affiché" "$sortie"; fi

nouveau_depot; lignes 450 > "$DEPOT/ancien.ts"; base
sed -i.bak 's/const a1 = 1/const a1 = 100/' "$DEPOT/ancien.ts" && rm "$DEPOT/ancien.ts.bak"; pr; lancer env
verifie "fichier long existant, modifié sans grossir : toléré" 0 "Fichier long toléré::450 lignes" "$code" "$sortie"

nouveau_depot; lignes 450 > "$DEPOT/ancien.ts"; base
echo "const z = 0" >> "$DEPOT/ancien.ts"; pr; lancer env
verifie "fichier long existant qui grossit : bloqué" 1 "Fichier trop long::451 lignes" "$code" "$sortie"

nouveau_depot; lignes 450 > "$DEPOT/ancien.ts"; base
git -C "$DEPOT" mv ancien.ts renomme.ts; pr; lancer env
verifie "fichier long seulement renommé : toléré (défaut corrigé)" 0 "ex-ancien.ts" "$code" "$sortie"

nouveau_depot; mkdir -p "$DEPOT/src"; lignes 450 > "$DEPOT/src/ancien.ts"; base
mkdir -p "$DEPOT/lib"; git -C "$DEPOT" mv src/ancien.ts lib/deplace.ts; pr; lancer env
verifie "fichier long déplacé de dossier : toléré" 0 "Fichier long toléré" "$code" "$sortie"

nouveau_depot; base
lignes 550 > "$DEPOT/calcul.spec.ts"; pr; lancer env
verifie "fichier de test de 550 lignes : accepté (limite 600)" 0 "" "$code" "$sortie"

nouveau_depot; base
lignes 601 > "$DEPOT/calcul.test.ts"; pr; lancer env
verifie "fichier de test de 601 lignes : bloqué" 1 "fichier de test" "$code" "$sortie"

nouveau_depot; base
lignes 1000 > "$DEPOT/types.d.ts"; mkdir -p "$DEPOT/db/migrations"; lignes 1000 > "$DEPOT/db/migrations/001.ts"; pr; lancer env
verifie "fichiers exclus (.d.ts, migrations) : ignorés" 0 "" "$code" "$sortie"

nouveau_depot; base
lignes 1000 > "$DEPOT/main.go"; pr; lancer env
verifie "extension non comptée (.go) : ignorée par défaut" 0 "" "$code" "$sortie"
lancer env EXTENSIONS="go"
verifie "extension ajoutée par réglage (.go) : bloquée" 1 "main.go" "$code" "$sortie"

nouveau_depot; base
{ lignes 380; for _ in $(seq 1 100); do echo; echo "   "; done; } > "$DEPOT/aere.ts"; pr; lancer env
verifie "lignes vides non comptées (380 lignes + 200 vides)" 0 "380 lignes" "$code" "$sortie"

nouveau_depot; base
lignes 401 > "$DEPOT/mon fichier.ts"; pr; lancer env
verifie "nom de fichier avec espace : traité" 1 "mon fichier.ts" "$code" "$sortie"

nouveau_depot; base
lignes 120 > "$DEPOT/a.ts"; pr; lancer env MAX_CODE=100
verifie "seuil réglé à 100 lignes : 120 bloqué" 1 "maximum 100" "$code" "$sortie"

nouveau_depot; base
lignes 401 > "$DEPOT/x.ts"; pr
resume=$(mktemp); lancer env GITHUB_STEP_SUMMARY="$resume"
verifie "résumé de la PR écrit" 1 "" "$code" "$sortie"
if grep -q '🔴 trop long' "$resume"; then ok "  …avec la ligne du fichier trop long"; else ko "  …avec la ligne du fichier trop long" "$(cat "$resume")"; fi

bilan
