#!/usr/bin/env bash
# Constance — pull request title in Conventional Commits 1.0.0 format.
#
# With squash merging, the PR title becomes the commit on the main branch, which release tools
# (release-please, semantic-release) read to choose the next version.
#
# Variables: TITLE (required), TYPES (space-separated list), AUTHOR,
# IGNORE_BOTS (true/false), SQUASH_SETTING (value read on the repository, optional).
set -uo pipefail

TITLE="${TITLE-}"
TYPES="${TYPES:-feat fix perf refactor docs test build ci chore style revert}"
AUTHOR="${AUTHOR:-}"
IGNORE_BOTS="${IGNORE_BOTS:-true}"
SQUASH_SETTING="${SQUASH_SETTING:-}"

alternatives=$(printf '%s' "$TYPES" | tr -s '[:space:]' '|' | sed 's/^|//;s/|$//')
title_pattern="^($alternatives)(\([^()[:space:]][^()]*\))?!?: [^[:space:]]"

is_valid() { printf '%s' "$1" | grep -Eq "$title_pattern"; }

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Suggests a corrected title from the first word (French or English).
suggest() {
  local title="$1" type rest first_word
  # "Feature: x", "Fix : x", "[WIP] x": remove the existing prefix.
  title=$(printf '%s' "$title" | sed -E 's/^\[[^]]*\][[:space:]]*//')
  if printf '%s' "$title" | grep -Eq '^[A-Za-z]+(\([^)]*\))?[[:space:]]*:'; then
    first_word=$(lowercase "$(printf '%s' "$title" | sed -E 's/^([A-Za-z]+).*/\1/')")
    rest=$(printf '%s' "$title" | sed -E 's/^[A-Za-z]+(\([^)]*\))?[[:space:]]*:[[:space:]]*//')
  else
    first_word=$(lowercase "$(printf '%s' "$title" | sed -E 's/^([^[:space:]]+).*/\1/')")
    rest="$title"
  fi
  case "$first_word" in
    fix|fixe|fixes|fixed|bug|bugfix|hotfix|corrige|corriger|correction|répare|repare|réparer) type=fix ;;
    feat|feature|add|adds|added|ajoute|ajouter|ajout|nouveau|nouvelle|crée|cree|créer|implement|implemente|implémente) type=feat ;;
    doc|docs|documentation|readme|documente) type=docs ;;
    test|tests|teste|tester) type="test" ;;
    refacto|refactor|refactoring|réorganise|reorganise|simplifie|découpe|decoupe|renomme) type=refactor ;;
    perf|performance|accélère|accelere|optimise) type=perf ;;
    style|format|formatage|lint) type=style ;;
    ci) type=ci ;;
    build|deps|dépendances|dependances|bump|update|maj|met) type=chore ;;
    chore) type=chore ;;
    revert|annule) type=revert ;;
    *) type=feat ;;
  esac
  # Lowercase first letter, except for an acronym (e.g. "API").
  if printf '%s' "$rest" | grep -Eq '^[[:upper:]][[:lower:]]'; then
    rest="$(lowercase "${rest:0:1}")${rest:1}"
  fi
  printf '%s: %s' "$type" "$rest"
}

if [ "$IGNORE_BOTS" = "true" ] && [[ "$AUTHOR" == *"[bot]" ]] && ! is_valid "$TITLE"; then
  echo "::notice title=Titre de PR non vérifié::PR ouverte par $AUTHOR. Pour que ses titres soient conformes, configurez son préfixe de commit (ex. Dependabot : commit-message.prefix « chore »)."
  exit 0
fi

# Title produced by GitHub's "Revert" button: Revert "feat: …"
reverted_title=$(printf '%s' "$TITLE" | sed -nE 's/^Revert "(.*)"$/\1/p')
if [ -n "$reverted_title" ] && is_valid "$reverted_title"; then
  echo "Titre conforme (annulation d'une PR) : $TITLE"
  echo "::notice title=Annulation::Les outils de version ne comptent pas toujours une annulation. Pour qu'elle apparaisse dans le journal des modifications, préférez « revert: $reverted_title »."
  exit 0
fi

if is_valid "$TITLE"; then
  echo "Titre conforme : $TITLE"
  failed=0
else
  echo "::error title=Titre de PR non conforme::« $TITLE » doit suivre Conventional Commits : « type: description » (types : $TYPES). Essayez : « $(suggest "$TITLE") ». Ajoutez « ! » avant « : » pour un changement incompatible."
  failed=1
fi

case "$SQUASH_SETTING" in
  ""|PR_TITLE) ;;
  *)
    echo "::warning title=Réglage de fusion::Le dépôt utilise « $SQUASH_SETTING » pour le titre des fusions en squash : quand une PR n'a qu'un commit, GitHub garde le message de ce commit et ignore ce titre. Réglez Settings → General → Pull Requests → « Default to pull request title »."
    ;;
esac

exit "$failed"
