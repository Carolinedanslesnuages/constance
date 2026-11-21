#!/usr/bin/env bash
# Constance — file naming: kebab-case files, PascalCase Vue components.
#
# Only files added (or renamed) by the pull request are checked: existing names are tolerated.
# A file name is the part before the first dot ("user-service" in "user-service.spec.ts").
#
# Variables: BASE (base commit, required), HEAD_REF (default HEAD), EXTENSIONS, EXCLUSIONS
# (space-separated lists), GITHUB_STEP_SUMMARY (optional).
set -uo pipefail
set -f # patterns (*.d.ts…) must never be expanded by the shell

: "${BASE:?BASE manquant : le commit de base de la PR}"
HEAD_REF="${HEAD_REF:-HEAD}"
EXTENSIONS="${EXTENSIONS:-ts tsx js jsx mjs cjs mts cts vue css scss}"
EXCLUSIONS="${EXCLUSIONS:-*/migrations/* */__tests__/* *.d.ts}"

KEBAB_CASE='^[a-z0-9]+(-[a-z0-9]+)*$'
PASCAL_CASE='^[A-Z][a-z0-9]*([A-Z][a-z0-9]*)*$'

matches_any() { # $1: path, $2: list of patterns
  local pattern
  for pattern in $2; do
    # shellcheck disable=SC2053 # $pattern is meant to be a glob
    [[ "/$1" == $pattern ]] && return 0
  done
  return 1
}

# Splits a name into lowercase words: "UserProfile_card" → "user profile card".
words_of() {
  printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g; s/([A-Z]+)([A-Z][a-z])/\1 \2/g; s/[^A-Za-z0-9]+/ /g' \
    | tr '[:upper:]' '[:lower:]' | xargs
}

to_kebab_case() { words_of "$1" | tr ' ' '-'; }

to_pascal_case() {
  local word result=""
  for word in $(words_of "$1"); do result+="$(printf '%s' "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1}"; done
  printf '%s' "$result"
}

pathspecs=()
for extension in $EXTENSIONS; do pathspecs+=("*.$extension"); done

failed=0
summary_rows=""

while IFS= read -r -d '' change_status; do
  [[ "$change_status" == R* ]] && IFS= read -r -d '' _previous_path
  IFS= read -r -d '' file_path
  matches_any "$file_path" "$EXCLUSIONS" && continue
  file_name="${file_path##*/}"
  [[ "$file_name" == .* ]] && continue # dotfiles (.eslintrc.cjs…) follow their tool's convention
  stem="${file_name%%.*}"
  suffix="${file_name#"$stem"}"
  if [[ "$file_name" == *.vue ]]; then
    [[ "$stem" =~ $PASCAL_CASE ]] && continue
    expected="$(to_pascal_case "$stem")$suffix"
    rule="un composant Vue s'écrit en PascalCase"
  else
    [[ "$stem" =~ $KEBAB_CASE ]] && continue
    expected="$(to_kebab_case "$stem")$suffix"
    rule="un fichier s'écrit en kebab-case (minuscules et tirets)"
  fi
  echo "::error file=$file_path,title=Nom de fichier::« $file_name » : $rule. Proposition : « $expected »."
  summary_rows+="| \`$file_path\` | \`$expected\` |"$'\n'
  failed=1
done < <(git diff -z --name-status -M --diff-filter=AR "$BASE" "$HEAD_REF" -- "${pathspecs[@]}")

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Nommage des fichiers"
    echo
    if [ -n "$summary_rows" ]; then
      echo "| Fichier | Nom proposé |"
      echo "|---|---|"
      printf '%s' "$summary_rows"
    else
      echo "Tous les fichiers ajoutés sont bien nommés."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
