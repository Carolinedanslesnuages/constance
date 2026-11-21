#!/usr/bin/env bash
# Constance — environment variables: every variable read in the code is declared in .env.example.
#
# Only lines added by the pull request are read: a variable used before is tolerated.
# Recognised reads: process.env.NAME, process.env['NAME'], import.meta.env.NAME, and
# config.get('NAME') / configService.getOrThrow('NAME') (NestJS ConfigService).
#
# Variables: BASE (base commit, required), HEAD_REF (default HEAD), EXAMPLE_FILE (.env.example),
# EXTENSIONS, EXCLUSIONS, IGNORED (space-separated lists, patterns allowed), GITHUB_STEP_SUMMARY.
set -uo pipefail
set -f # patterns (GITHUB_*…) must never be expanded by the shell

: "${BASE:?BASE manquant : le commit de base de la PR}"
HEAD_REF="${HEAD_REF:-HEAD}"
EXAMPLE_FILE="${EXAMPLE_FILE:-.env.example}"
EXTENSIONS="${EXTENSIONS:-ts tsx js jsx mjs cjs mts cts vue}"
EXCLUSIONS="${EXCLUSIONS:-*.spec.* *.test.* */test/* */tests/* */e2e/* */__tests__/*}"
IGNORED="${IGNORED:-NODE_ENV CI HOME PATH PWD TZ LANG MODE DEV PROD SSR BASE_URL GITHUB_* RUNNER_*}"

matches_any() { # $1: value, $2: list of patterns, $3: prefix added to the value ("/" for paths)
  local pattern
  for pattern in $2; do
    # shellcheck disable=SC2053 # $pattern is meant to be a glob
    [[ "${3:-}$1" == $pattern ]] && return 0
  done
  return 1
}

declared=" "
if git cat-file -e "$HEAD_REF:$EXAMPLE_FILE" 2>/dev/null; then
  while IFS= read -r variable_name; do declared+="$variable_name "; done < <(
    git show "$HEAD_REF:$EXAMPLE_FILE" | sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*/\2/p'
  )
  example_exists=1
else
  example_exists=0
fi

pathspecs=()
for extension in $EXTENSIONS; do pathspecs+=("*.$extension"); done

# Added lines as "path<TAB>line number<TAB>variable name", one per variable read.
added_reads() {
  git diff -U0 --no-color "$BASE" "$HEAD_REF" -- "${pathspecs[@]}" | perl -ne '
    if (m{^\+\+\+ b/(.*)$}) { $file = $1; next }
    if (m{^@@ -\S+ \+(\d+)}) { $line = $1; next }
    next unless s/^\+//;
    while (m{process\.env\.([A-Za-z_]\w*)|process\.env\[\s*["\x27]([A-Za-z_]\w*)["\x27]\s*\]|import\.meta\.env\.([A-Za-z_]\w*)|[Cc]onfig\w*\.(?:get|getOrThrow)(?:<[^>]*>)?\(\s*["\x27]([A-Z_][A-Z0-9_]*)["\x27]}g) {
      print "$file\t$line\t", ($1 // $2 // $3 // $4), "\n";
    }
    $line++;
  '
}

failed=0
reported=" "
summary_rows=""
while IFS=$'\t' read -r file_path line_number variable_name; do
  matches_any "$file_path" "$EXCLUSIONS" / && continue
  matches_any "$variable_name" "$IGNORED" && continue
  [[ "$declared" == *" $variable_name "* ]] && continue
  if [ "$example_exists" = 1 ]; then
    message="« $variable_name » est lue ici mais n'est pas déclarée dans $EXAMPLE_FILE. Ajoutez-la avec une valeur d'exemple et un commentaire qui dit à quoi elle sert."
  else
    message="« $variable_name » est lue ici mais le projet n'a pas de $EXAMPLE_FILE. Créez-le et déclarez-y chaque variable, avec une valeur d'exemple et un commentaire."
  fi
  echo "::error file=$file_path,line=$line_number,title=Variable d'environnement non déclarée::$message"
  if [[ "$reported" != *" $variable_name "* ]]; then
    reported+="$variable_name "
    summary_rows+="| \`$variable_name\` | \`$file_path\` (ligne $line_number) |"$'\n'
  fi
  failed=1
done < <(added_reads)

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Variables d'environnement"
    echo
    if [ -n "$summary_rows" ]; then
      echo "À déclarer dans \`$EXAMPLE_FILE\` :"
      echo
      echo "| Variable | Lue dans |"
      echo "|---|---|"
      printf '%s' "$summary_rows"
    else
      echo "Toutes les variables lues par la PR sont déclarées dans \`$EXAMPLE_FILE\`."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
