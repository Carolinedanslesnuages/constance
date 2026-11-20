#!/usr/bin/env bash
# Constance — titre de PR au format Conventional Commits 1.0.0.
#
# En fusion squash, le titre de la PR devient le commit de la branche principale, que les
# outils de version (release-please, semantic-release) lisent pour choisir la version.
#
# Variables : TITRE (obligatoire), TYPES (liste séparée par des espaces), AUTEUR,
# IGNORER_BOTS (true/false), REGLAGE_SQUASH (valeur lue sur le dépôt, facultative).
set -uo pipefail

TITRE="${TITRE-}"
TYPES="${TYPES:-feat fix perf refactor docs test build ci chore style revert}"
AUTEUR="${AUTEUR:-}"
IGNORER_BOTS="${IGNORER_BOTS:-true}"
REGLAGE_SQUASH="${REGLAGE_SQUASH:-}"

alternatives=$(printf '%s' "$TYPES" | tr -s '[:space:]' '|' | sed 's/^|//;s/|$//')
motif="^($alternatives)(\([^()[:space:]][^()]*\))?!?: [^[:space:]]"

conforme() { printf '%s' "$1" | grep -Eq "$motif"; }

minuscule() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Propose un titre corrigé à partir du premier mot (français ou anglais).
suggestion() {
  local titre="$1" type reste premier
  # « Feature: x », « Fix : x », « [WIP] x » : on retire le préfixe existant.
  titre=$(printf '%s' "$titre" | sed -E 's/^\[[^]]*\][[:space:]]*//')
  if printf '%s' "$titre" | grep -Eq '^[A-Za-z]+(\([^)]*\))?[[:space:]]*:'; then
    premier=$(minuscule "$(printf '%s' "$titre" | sed -E 's/^([A-Za-z]+).*/\1/')")
    reste=$(printf '%s' "$titre" | sed -E 's/^[A-Za-z]+(\([^)]*\))?[[:space:]]*:[[:space:]]*//')
  else
    premier=$(minuscule "$(printf '%s' "$titre" | sed -E 's/^([^[:space:]]+).*/\1/')")
    reste="$titre"
  fi
  case "$premier" in
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
  # Première lettre en minuscule, sauf sigle (ex. « API »).
  if printf '%s' "$reste" | grep -Eq '^[[:upper:]][[:lower:]]'; then
    reste="$(minuscule "${reste:0:1}")${reste:1}"
  fi
  printf '%s: %s' "$type" "$reste"
}

if [ "$IGNORER_BOTS" = "true" ] && [[ "$AUTEUR" == *"[bot]" ]] && ! conforme "$TITRE"; then
  echo "::notice title=Titre de PR non vérifié::PR ouverte par $AUTEUR. Pour que ses titres soient conformes, configurez son préfixe de commit (ex. Dependabot : commit-message.prefix « chore »)."
  exit 0
fi

# Titre produit par le bouton « Revert » de GitHub : Revert "feat: …"
interieur=$(printf '%s' "$TITRE" | sed -nE 's/^Revert "(.*)"$/\1/p')
if [ -n "$interieur" ] && conforme "$interieur"; then
  echo "Titre conforme (annulation d'une PR) : $TITRE"
  echo "::notice title=Annulation::Les outils de version ne comptent pas toujours une annulation. Pour qu'elle apparaisse dans le journal des modifications, préférez « revert: $interieur »."
  exit 0
fi

if conforme "$TITRE"; then
  echo "Titre conforme : $TITRE"
  echec=0
else
  echo "::error title=Titre de PR non conforme::« $TITRE » doit suivre Conventional Commits : « type: description » (types : $TYPES). Essayez : « $(suggestion "$TITRE") ». Ajoutez « ! » avant « : » pour un changement incompatible."
  echec=1
fi

case "$REGLAGE_SQUASH" in
  ""|PR_TITLE) ;;
  *)
    echo "::warning title=Réglage de fusion::Le dépôt utilise « $REGLAGE_SQUASH » pour le titre des fusions en squash : quand une PR n'a qu'un commit, GitHub garde le message de ce commit et ignore ce titre. Réglez Settings → General → Pull Requests → « Default to pull request title »."
    ;;
esac

exit "$echec"
