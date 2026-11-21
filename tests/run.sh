#!/usr/bin/env bash
# Runs every test: bash tests/run.sh
set -u
tests_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failed=0
for test_script in "$tests_folder"/file-size.sh "$tests_folder"/pr-title.sh; do
  bash "$test_script" || failed=1
  echo
done
exit "$failed"
