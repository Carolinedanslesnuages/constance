#!/usr/bin/env bash
# Constance — dangerous patterns: code patterns known to open a security hole.
#
# Only lines added by the pull request are read, tests excluded. A dangerous line that already
# existed before the PR (same file, same text once trimmed) is tolerated as long as the PR does not
# add more copies of it: moved or reindented code passes, one more copy is reported. Known limit:
# a PR that removes one copy and adds an identical one elsewhere in the file keeps the count equal,
# so it passes (no more risk than before). A line holding « constance: autorisé » is skipped: the
# exception is written in the code, next to what it allows.
#
# Blocking (error): TLS certificate checks turned off.
# Warning only: CORS open to everyone, HTML injected, SQL built from text, empty catch. These
# patterns are sometimes legitimate (sanitised HTML, deliberate empty catch).
#
# Variables: BASE (base commit, required), HEAD_REF (default HEAD), EXTENSIONS, EXCLUSIONS
# (space-separated lists), GITHUB_STEP_SUMMARY (optional).
set -uo pipefail
set -f # patterns (*.spec.*…) must never be expanded by the shell

: "${BASE:?BASE manquant : le commit de base de la PR}"
HEAD_REF="${HEAD_REF:-HEAD}"
EXTENSIONS="${EXTENSIONS:-ts tsx js jsx mjs cjs mts cts vue py}"
EXCLUSIONS="${EXCLUSIONS:-*.spec.* *.test.* */test/* */tests/* */e2e/* */__tests__/* */test_*.py *_test.py}"

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

# Findings as "path<TAB>line number<TAB>rule<TAB>added text", one per pattern found.
added_findings() {
  git diff -U0 --no-color "$BASE" "$HEAD_REF" -- "${pathspecs[@]}" | perl -ne '
    if (m{^\+\+\+ b/(.*)$}) { $file = $1; next }
    if (m{^@@ -\S+ \+(\d+)}) { $line = $1; next }
    next unless s/^\+//;
    chomp;
    my $text = $_;
    unless ($text =~ /constance\s*:\s*autoris/i) {
      my @rules;
      push @rules, "tls" if $text =~ /rejectUnauthorized\s*:\s*false|\bverify\s*=\s*False\b|NODE_TLS_REJECT_UNAUTHORIZED\W+0/;
      push @rules, "cors" if $text =~ /Access-Control-Allow-Origin["\x27]?\s*[:,]\s*["\x27]\*["\x27]|\borigin\s*:\s*["\x27]\*["\x27]/i;
      push @rules, "html" if $text =~ /\.(inner|outer)HTML\s*\+?=(?!=)|\bv-html\s*=|dangerouslySetInnerHTML|insertAdjacentHTML\s*\(/;
      push @rules, "sql" if $text =~ /(["\x27]).*\b(SELECT\b.*\bFROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM)\b.*\1\s*\+|`[^`]*\b(SELECT\b[^`]*\bFROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM)\b[^`]*\$\{|\bf["\x27].*\b(SELECT\b.*\bFROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM)\b.*\{/;
      push @rules, "catch" if $text =~ /\bcatch\s*(\([^)]*\))?\s*\{\s*\}|\bexcept\b[^:]*:\s*pass\b/;
      print "$file\t$line\t$_\t$text\n" for @rules;
    }
    $line++;
  '
}

# Plain functions rather than associative arrays: macOS still ships bash 3.2.
title_of() {
  case "$1" in
    tls) echo "Vérification TLS désactivée" ;;
    cors) echo "CORS ouvert à tous" ;;
    html) echo "HTML injecté" ;;
    sql) echo "SQL assemblé avec du texte" ;;
    catch) echo "Erreur avalée" ;;
  esac
}

advice_of() {
  case "$1" in
    tls) echo "la connexion accepte n'importe quel certificat : un intermédiaire peut lire et modifier les échanges. Corrigez le certificat plutôt que de désactiver la vérification." ;;
    cors) echo "n'importe quel site peut appeler cette adresse depuis le navigateur. Listez les origines autorisées." ;;
    html) echo "si ce contenu vient d'un utilisateur ou d'une base, il peut exécuter du code dans la page (XSS). Préférez du texte, ou nettoyez le HTML avant." ;;
    sql) echo "une valeur insérée dans le texte de la requête peut la détourner (injection SQL). Utilisez une requête paramétrée." ;;
    catch) echo "l'erreur disparaît sans laisser de trace. Journalisez-la, ou dites en commentaire pourquoi on l'ignore." ;;
  esac
}

trimmed_lines() { sed -E 's/^[[:space:]]+|[[:space:]]+$//g'; }

# How many lines of a file, at a revision, equal the given (trimmed) text. 0 when the file is absent.
copies_at() { # $1: revision, $2: path, $3: trimmed text
  local count
  count=$(git show "$1:$2" 2>/dev/null | trimmed_lines | grep -cxF -- "$3")
  printf '%s' "${count:-0}"
}

failed=0
summary_rows=""
while IFS=$'\t' read -r file_path line_number rule added_text; do
  matches_any "$file_path" "$EXCLUSIONS" && continue
  # Tolerated when the PR adds no copy of a line that already existed (moved or reindented code).
  # Only lines found by the patterns get here: a few per PR, so two « git show » each cost nothing.
  trimmed="$(printf '%s' "$added_text" | trimmed_lines)"
  if [ "$(copies_at "$HEAD_REF" "$file_path" "$trimmed")" -le "$(copies_at "$BASE" "$file_path" "$trimmed")" ]; then continue; fi
  level="warning"
  [ "$rule" = "tls" ] && level="error" && failed=1
  echo "::$level file=$file_path,line=$line_number,title=Motif dangereux : $(title_of "$rule")::$(advice_of "$rule") Si c'est voulu, ajoutez « constance: autorisé » en commentaire sur la ligne."
  summary_rows+="| $([ "$level" = error ] && echo '🔴' || echo '🟠') $(title_of "$rule") | \`$file_path\` (ligne $line_number) |"$'\n'
done < <(added_findings)

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Motifs dangereux"
    echo
    if [ -n "$summary_rows" ]; then
      echo "| Motif | Emplacement |"
      echo "|---|---|"
      printf '%s' "$summary_rows"
      echo
      echo "🔴 bloque la PR · 🟠 à relire. Exception voulue : « constance: autorisé » en commentaire sur la ligne."
    else
      echo "Aucun motif dangereux dans les lignes ajoutées."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$failed"
