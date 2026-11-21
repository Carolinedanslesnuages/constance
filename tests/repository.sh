#!/usr/bin/env bash
# Throwaway git repositories for the checks that compare a pull request with its base.
# shellcheck disable=SC2034 # REPO and BASE are used by the scripts that source this file

# new_repository creates an empty repository in $REPO.
new_repository() {
  REPO=$(mktemp -d)
  git -C "$REPO" init -q
  git -C "$REPO" config user.email essai@exemple.fr
  git -C "$REPO" config user.name essai
}
# commit_base stores the base commit in $BASE; commit_change records the pull request.
commit_base() { git -C "$REPO" add -A && git -C "$REPO" commit -q --allow-empty -m base && BASE=$(git -C "$REPO" rev-parse HEAD); }
commit_change() { git -C "$REPO" add -A && git -C "$REPO" commit -q -m change; }
add_files() { local path; for path in "$@"; do mkdir -p "$REPO/$(dirname "$path")"; touch "$REPO/$path"; done; }
