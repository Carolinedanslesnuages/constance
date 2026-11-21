#!/usr/bin/env bash
# Shared test helpers: assertions and counters.
# shellcheck disable=SC2034 # used by the scripts that source this file
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
passed_count=0
failed_count=0

pass() { passed_count=$((passed_count + 1)); echo "  ✅ $1"; }
fail() { failed_count=$((failed_count + 1)); echo "  ❌ $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; }

# expect <description> <expected code> <expected text or ""> <actual code> <output>
expect() {
  local description="$1" expected_code="$2" expected_text="$3" actual_code="$4" output="$5"
  if [ "$actual_code" != "$expected_code" ]; then
    fail "$description (code $actual_code, attendu $expected_code)" "$output"
  elif [ -n "$expected_text" ] && ! printf '%s' "$output" | grep -qF -- "$expected_text"; then
    fail "$description (texte absent : $expected_text)" "$output"
  else
    pass "$description"
  fi
}

report() {
  echo
  echo "$passed_count réussi(s), $failed_count raté(s)"
  [ "$failed_count" -eq 0 ]
}
