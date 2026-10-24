#!/usr/bin/env bash
# Tests tools/publish_pages.sh against a throwaway local "origin". Run from the repo root.
set -euo pipefail
script=$(pwd)/tools/publish_pages.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

git init -q --bare "$tmp/origin.git"
git init -q "$tmp/repo"
cd "$tmp/repo"
git config user.email test@example.com
git config user.name test
git commit -q --allow-empty -m init
git remote add origin "$tmp/origin.git"
git push -q origin HEAD:refs/heads/main HEAD:refs/heads/feature/worker-x
mkdir -p "$tmp/build"
echo main1 >"$tmp/build/index.html"

pages() { git -C "$tmp/repo" fetch -q origin gh-pages && git -C "$tmp/repo" show "FETCH_HEAD:$1" 2>/dev/null; }
listing() { git -C "$tmp/repo" fetch -q origin gh-pages && git -C "$tmp/repo" ls-tree -r --name-only FETCH_HEAD; }

"$script" publish "$tmp/build" branch main >/dev/null
check "main publishes to the root" '[ "$(pages index.html)" = main1 ]'
check "root gets .nojekyll" 'listing | grep -qx .nojekyll'

echo feature >"$tmp/build/index.html"
"$script" publish "$tmp/build" branch feature/worker-x >/dev/null
check "branch goes to branch/<slug>/" '[ "$(pages branch/feature-worker-x/index.html)" = feature ]'

echo v020 >"$tmp/build/index.html"
"$script" publish "$tmp/build" tag v0.2.0 >/dev/null
check "tag goes to v/<version>/" '[ "$(pages v/0.2.0/index.html)" = v020 ]'

rm "$tmp/build/index.html"
echo main2 >"$tmp/build/game.pck"
"$script" publish "$tmp/build" branch main >/dev/null
check "new main replaces old root files" '! listing | grep -qx index.html && [ "$(pages game.pck)" = main2 ]'
check "new main keeps branch builds" '[ "$(pages branch/feature-worker-x/index.html)" = feature ]'
check "new main keeps versions" '[ "$(pages v/0.2.0/index.html)" = v020 ]'

"$script" publish "$tmp/build" branch main | grep -q "Nothing to publish"
check "identical publish makes no commit" 'true'

! "$script" publish "$tmp/build" tag v >/dev/null 2>&1
check "a bare 'v' tag is refused" 'true'
check "versions survive a bad tag" '[ "$(pages v/0.2.0/index.html)" = v020 ]'

"$script" publish "$tmp/build" branch gone | grep -q "no longer exists"
check "a deleted branch's late build is skipped" '! listing | grep -q "^branch/gone/"'

git push -q origin --delete feature/worker-x
"$script" remove feature/worker-x >/dev/null
check "deleted branch folder is removed" '! listing | grep -q "^branch/feature-worker-x/"'
check "removing a branch keeps versions" '[ "$(pages v/0.2.0/index.html)" = v020 ]'
check "no publish worktrees or temp branches left behind" '[ "$(git -C "$tmp/repo" worktree list | wc -l)" = 1 ] && ! git -C "$tmp/repo" branch | grep -q publish-tmp'

exit $fail
