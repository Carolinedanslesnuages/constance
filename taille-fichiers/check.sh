#!/usr/bin/env bash
# Constance — file size: one file, one responsibility.
#
# A code file has at most MAX_CODE non-empty lines, a test file at most MAX_TEST.
# A longer file that already existed is tolerated as long as it does not grow, even when renamed
# or moved: it gets split when someone works on it.
#
# Variables: BASE (base commit, required), HEAD_REF (default HEAD), MAX_CODE (400),
# MAX_TEST (600), WARNING_PERCENT (90), EXTENSIONS, EXCLUSIONS, TEST_PATTERNS
# (space-separated lists), GITHUB_STEP_SUMMARY (optional).
set -uo pipefail
set -f # patterns (*.d.ts…) must never be expanded by the shell

: "${BASE:?BASE manquant : le commit de base de la PR}"
HEAD_REF="${HEAD_REF:-HEAD}"
MAX_CODE="${MAX_CODE:-400}"
MAX_TEST="${MAX_TEST:-600}"
WARNING_PERCENT="${WARNING_PERCENT:-90}"
EXTENSIONS="${EXTENSIONS:-ts tsx js jsx mjs cjs mts cts vue py}"
EXCLUSIONS="${EXCLUSIONS:-*/migrations/* *.d.ts *.min.js}"
TEST_PATTERNS="${TEST_PATTERNS:-*.spec.* *.test.* */tests/* */test/* */__tests__/* */test_*.py *_test.py}"

count_non_empty() { grep -cv '^[[:space:]]*$' || true; }

matches_any() { # $1: path, $2: list of patterns
  local pattern
  for pattern in $2; do
    # shellcheck disable=SC2053 # $pattern is meant to be a glob
    [[ "/$1" == $pattern ]] && return 0
  done
  return 1
}

pathspecs=()
for extension in $EXTENSIONS; do pathspecs+=("*.$extension"); done

failed=0
summary_rows=""

add_summary_row() { summary_rows+="| $1 | \`$2\` | $3 | $4 |"$'\n'; }

while IFS= read -r -d '' change_status; do
  if [[ "$change_status" == R* ]]; then
    IFS= read -r -d '' previous_path
    IFS= read -r -d '' file_path
  else
    IFS= read -r -d '' file_path
    previous_path="$file_path"
  fi

  matches_any "$file_path" "$EXCLUSIONS" && continue
  if matches_any "$file_path" "$TEST_PATTERNS"; then limit=$MAX_TEST; kind="test"; else limit=$MAX_CODE; kind="code"; fi

  line_count=$(git show "$HEAD_REF:$file_path" | count_non_empty)
  previous_count=$(git show "$BASE:$previous_path" 2>/dev/null | count_non_empty)
  previous_count=${previous_count:-0}

  if [ "$line_count" -gt "$limit" ]; then
    if [ "$previous_count" -gt 0 ] && [ "$line_count" -le "$previous_count" ]; then
      origin=""
      [ "$previous_path" != "$file_path" ] && origin=" (ex-$previous_path)"
      echo "::notice file=$file_path,title=Fichier long toléré::$line_count lignes non vides (maximum $limit pour un fichier de $kind), mais il ne grossit pas$origin. À découper quand on y travaille."
      add_summary_row "🟡 toléré" "$file_path" "$line_count / $limit" "ne grossit pas (avant : $previous_count)$origin"
    else
      echo "::error file=$file_path,title=Fichier trop long::$line_count lignes non vides (maximum $limit pour un fichier de $kind). Découpez-le par responsabilité (pas une fonction par fichier) : chaque partie dans un fichier qui dit ce qu'elle fait."
      add_summary_row "🔴 trop long" "$file_path" "$line_count / $limit" "avant : $previous_count"
      failed=1
    fi
  elif [ $((line_count * 100)) -ge $((limit * WARNING_PERCENT)) ]; then
    echo "::warning file=$file_path,title=Fichier proche de la limite::$line_count lignes non vides sur $limit autorisées pour un fichier de $kind. Pensez à le découper avant qu'il ne bloque."
    add_summary_row "🟠 proche" "$file_path" "$line_count / $limit" "seuil d'alerte : $WARNING_PERCENT %"
  fi
done < <(git diff -z --name-status -M --diff-filter=AMR "$BASE" "$HEAD_REF" -- "${pathspecs[@]}")

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Taille des fichiers"
    echo
    echo "Maximum : $MAX_CODE lignes non vides pour le code, $MAX_TEST pour les tests. Alerte à $WARNING_PERCENT %."
    echo
    if [ -n "$summary_rows" ]; then
      echo "| État | Fichier | Lignes | Détail |"
      echo "|---|---|---|---|"
      printf '%s' "$summary_rows"
    else
      echo "Aucun fichier modifié n'approche la limite."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
