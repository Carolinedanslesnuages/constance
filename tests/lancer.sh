#!/usr/bin/env bash
# Lance tous les tests : bash tests/lancer.sh
set -u
dossier="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echec=0
for test in "$dossier"/taille-fichiers.sh "$dossier"/titre-pr.sh; do
  bash "$test" || echec=1
  echo
done
exit "$echec"
