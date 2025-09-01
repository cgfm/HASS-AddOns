#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  - Sync all from addons.json:   .github/scripts/sync_subtrees.sh
#  - Sync one (from dispatch):    .github/scripts/sync_subtrees.sh <name> <repo_url> <ref>

sync_one() {
  local name="$1" repo_url="$2" ref="$3" prefix
  prefix="$name"

  echo "--- Syncing $name from $repo_url@$ref -> $prefix/"

  # Add/update remote
  local remote="remote_${name}"
  if git remote | grep -q "^${remote}$"; then
    git remote set-url "$remote" "$repo_url"
  else
    git remote add "$remote" "$repo_url"
  fi
  git fetch "$remote" --tags --prune

  # If prefix exists, pull; otherwise, add
  if [[ -d "$prefix" ]]; then
    echo "Pulling into existing subtree $prefix"
    git subtree pull --prefix "$prefix" "$remote" "$ref" --squash || {
      echo "Subtree pull failed. If this is a first-time import with a different history, remove $prefix and re-add." >&2
      exit 1
    }
  else
    echo "Adding new subtree at $prefix"
    git subtree add --prefix "$prefix" "$remote" "$ref" --squash
  fi
}

if [[ $# -eq 0 ]]; then
  # Bulk mode from addons.json
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    exit 1
  fi
  if [[ ! -f addons.json ]]; then
    echo "addons.json not found in repo root" >&2
    exit 1
  fi
  mapfile -t names < <(jq -r '.[].name' addons.json)
  for name in "${names[@]}"; do
    repo_url=$(jq -r ".[] | select(.name==\"$name\") | .repo" addons.json)
    ref=$(jq -r ".[] | select(.name==\"$name\") | .ref" addons.json)
    sync_one "$name" "$repo_url" "$ref"
  done
else
  # Single item (repository_dispatch)
  if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <name> <repo_url> <ref>" >&2
    exit 2
  fi
  sync_one "$1" "$2" "$3"
fi

echo "All done."

