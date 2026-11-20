#!/usr/bin/env bash
# Constance — taille des fichiers : un fichier, une responsabilité.
#
# Un fichier de code ne dépasse pas MAX_CODE lignes non vides, un fichier de test MAX_TEST.
# Un fichier plus long venu d'avant est toléré tant qu'il ne grossit pas, même renommé ou
# déplacé : on le découpe quand on y travaille.
#
# Variables : BASE (commit de base, obligatoire), HEAD_REF (défaut HEAD), MAX_CODE (400),
# MAX_TEST (600), SEUIL_AVERTISSEMENT (90, en %), EXTENSIONS, EXCLUSIONS, MOTIFS_TEST
# (listes séparées par des espaces), GITHUB_STEP_SUMMARY (facultatif).
set -uo pipefail
set -f # les motifs (*.d.ts…) ne doivent jamais être développés par le shell

: "${BASE:?BASE manquant : le commit de base de la PR}"
HEAD_REF="${HEAD_REF:-HEAD}"
MAX_CODE="${MAX_CODE:-400}"
MAX_TEST="${MAX_TEST:-600}"
SEUIL="${SEUIL_AVERTISSEMENT:-90}"
EXTENSIONS="${EXTENSIONS:-ts tsx js jsx mjs cjs mts cts vue py}"
EXCLUSIONS="${EXCLUSIONS:-*/migrations/* *.d.ts *.min.js}"
MOTIFS_TEST="${MOTIFS_TEST:-*.spec.* *.test.* */tests/* */test/* */__tests__/* */test_*.py *_test.py}"

utiles() { grep -cv '^[[:space:]]*$' || true; }

correspond() { # $1 : chemin, $2 : liste de motifs
  local motif
  for motif in $2; do
    # shellcheck disable=SC2053 # $motif est un motif voulu
    [[ "/$1" == $motif ]] && return 0
  done
  return 1
}

specs=()
for extension in $EXTENSIONS; do specs+=("*.$extension"); done

echec=0
lignes_resume=""

ajouter_resume() { lignes_resume+="| $1 | \`$2\` | $3 | $4 |"$'\n'; }

while IFS= read -r -d '' statut; do
  if [[ "$statut" == R* ]]; then
    IFS= read -r -d '' ancien
    IFS= read -r -d '' fichier
  else
    IFS= read -r -d '' fichier
    ancien="$fichier"
  fi

  correspond "$fichier" "$EXCLUSIONS" && continue
  if correspond "$fichier" "$MOTIFS_TEST"; then max=$MAX_TEST; genre="test"; else max=$MAX_CODE; genre="code"; fi

  lignes=$(git show "$HEAD_REF:$fichier" | utiles)
  avant=$(git show "$BASE:$ancien" 2>/dev/null | utiles)
  avant=${avant:-0}

  if [ "$lignes" -gt "$max" ]; then
    if [ "$avant" -gt 0 ] && [ "$lignes" -le "$avant" ]; then
      origine=""
      [ "$ancien" != "$fichier" ] && origine=" (ex-$ancien)"
      echo "::notice file=$fichier,title=Fichier long toléré::$lignes lignes non vides (maximum $max pour un fichier de $genre), mais il ne grossit pas$origine. À découper quand on y travaille."
      ajouter_resume "🟡 toléré" "$fichier" "$lignes / $max" "ne grossit pas (avant : $avant)$origine"
    else
      echo "::error file=$fichier,title=Fichier trop long::$lignes lignes non vides (maximum $max pour un fichier de $genre). Découpez-le par responsabilité (pas une fonction par fichier) : chaque partie dans un fichier qui dit ce qu'elle fait."
      ajouter_resume "🔴 trop long" "$fichier" "$lignes / $max" "avant : $avant"
      echec=1
    fi
  elif [ $((lignes * 100)) -ge $((max * SEUIL)) ]; then
    echo "::warning file=$fichier,title=Fichier proche de la limite::$lignes lignes non vides sur $max autorisées pour un fichier de $genre. Pensez à le découper avant qu'il ne bloque."
    ajouter_resume "🟠 proche" "$fichier" "$lignes / $max" "seuil d'alerte : $SEUIL %"
  fi
done < <(git diff -z --name-status -M --diff-filter=AMR "$BASE" "$HEAD_REF" -- "${specs[@]}")

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Taille des fichiers"
    echo
    echo "Maximum : $MAX_CODE lignes non vides pour le code, $MAX_TEST pour les tests. Alerte à $SEUIL %."
    echo
    if [ -n "$lignes_resume" ]; then
      echo "| État | Fichier | Lignes | Détail |"
      echo "|---|---|---|---|"
      printf '%s' "$lignes_resume"
    else
      echo "Aucun fichier modifié n'approche la limite."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$echec"
