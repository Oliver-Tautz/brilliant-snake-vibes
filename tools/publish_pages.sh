#!/usr/bin/env bash
# Publishes a web build into the gh-pages branch, one folder per build:
#   main            -> /                 (latest; branch/ and v/ folders are kept)
#   branch <name>   -> /branch/<name>/   ("/" and other odd characters become "-")
#   tag v<version>  -> /v/<version>/     (kept forever)
# Usage:
#   publish_pages.sh publish <build-dir> <branch|tag> <ref-name>
#   publish_pages.sh remove <branch-name>     # when a branch is deleted
# Run inside a git checkout whose "origin" remote you can push to. Retries if another publish
# pushed to gh-pages at the same time. Branch names that slug to the same folder (feature/x and
# feature-x) share it. A branch build that finishes after its branch was deleted is skipped.
set -euo pipefail

slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-'; }

target_dir() {
  local type=$1 name=$2
  if [ "$type" = tag ]; then
    local version
    version=$(slug "${name#v}")
    if [ -z "$version" ]; then
      echo "Refusing tag '$name': no version after the v." >&2
      return 1
    fi
    echo "v/$version"
  elif [ "$name" = main ]; then
    echo "."
  else
    echo "branch/$(slug "$name")"
  fi
}

# Applies the change inside the gh-pages worktree ($1); prints the commit message.
apply() {
  local work=$1
  touch "$work/.nojekyll"
  case $action in
    publish)
      local dest
      dest=$(target_dir "$ref_type" "$ref_name") || return 1
      if [ "$dest" = . ]; then
        find "$work" -mindepth 1 -maxdepth 1 ! -name .git ! -name .nojekyll ! -name branch ! -name v \
          -exec rm -rf {} +
      else
        rm -rf "${work:?}/$dest"
        mkdir -p "$work/$dest"
      fi
      cp -R "$build_dir"/. "$work/$dest/"
      echo "Publish $ref_type $ref_name to /$dest"
      ;;
    remove)
      rm -rf "${work:?}/branch/$(slug "$ref_name")"
      echo "Remove branch $ref_name"
      ;;
  esac
}

action=${1:?usage: publish_pages.sh publish|remove ...}
if [ "$action" = publish ]; then
  build_dir=$(cd "${2:?build dir}" && pwd)
  ref_type=${3:?branch or tag}
  ref_name=${4:?ref name}
  target_dir "$ref_type" "$ref_name" >/dev/null  # fail early on a bad tag
  if [ "$ref_type" = branch ] && ! git ls-remote --exit-code --heads origin "$ref_name" >/dev/null; then
    echo "Branch $ref_name no longer exists, skipping."
    exit 0
  fi
else
  ref_name=${2:?branch name}
fi

work=""
tmp_branch="publish-tmp-$$"
cleanup() {
  if [ -n "$work" ]; then git worktree remove --force "$work" 2>/dev/null || true; fi
  git branch -D "$tmp_branch" >/dev/null 2>&1 || true
  work=""
}
trap cleanup EXIT

for attempt in 1 2 3 4 5; do
  work=$(mktemp -d)
  if git ls-remote --exit-code --heads origin gh-pages >/dev/null; then
    git fetch -q --depth 1 origin gh-pages  # history is not needed to add one commit on top
    git worktree add -q --detach "$work" FETCH_HEAD
  else
    git worktree add -q --detach "$work"
    git -C "$work" checkout -q --orphan "$tmp_branch"
    git -C "$work" rm -rq --ignore-unmatch .
  fi
  message=$(apply "$work")
  git -C "$work" add -A
  if git -C "$work" diff --cached --quiet; then
    echo "Nothing to publish."
    exit 0
  fi
  git -C "$work" commit -q -m "$message"
  if git -C "$work" push -q origin HEAD:refs/heads/gh-pages; then
    echo "$message"
    exit 0
  fi
  echo "Push rejected (attempt $attempt), retrying with the latest gh-pages..."
  cleanup
  sleep $((attempt * 2))
done
echo "Could not publish after 5 attempts." >&2
exit 1
