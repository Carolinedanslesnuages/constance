#!/usr/bin/env bash
# Outils communs aux tests : assertions et compteurs.
# shellcheck disable=SC2034 # utilisé par les scripts qui chargent ce fichier
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
reussis=0
rates=0

ok() { reussis=$((reussis + 1)); echo "  ✅ $1"; }
ko() { rates=$((rates + 1)); echo "  ❌ $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; }

# verifie <description> <code attendu> <texte attendu ou ""> <code obtenu> <sortie>
verifie() {
  local description="$1" code_attendu="$2" texte="$3" code="$4" sortie="$5"
  if [ "$code" != "$code_attendu" ]; then
    ko "$description (code $code, attendu $code_attendu)" "$sortie"
  elif [ -n "$texte" ] && ! printf '%s' "$sortie" | grep -qF -- "$texte"; then
    ko "$description (texte absent : $texte)" "$sortie"
  else
    ok "$description"
  fi
}

bilan() {
  echo
  echo "$reussis réussi(s), $rates raté(s)"
  [ "$rates" -eq 0 ]
}
