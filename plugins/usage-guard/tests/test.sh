#!/usr/bin/env bash
# Acceptance tests for usage-guard. Uses a temp usage file, never ~/.claude.
cd "$(dirname "$0")/.." || exit 1
tmp=$(mktemp -d); export USAGE_GUARD_FILE="$tmp/usage.json"
fail=0
check() { # name expected_exit actual_exit
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (expected exit $2, got $3)"; fail=1; fi
}
future=$(( $(date +%s) + 3600 )); past=$(( $(date +%s) - 3600 ))
guard() { echo '{"tool_name":"Bash"}' | scripts/usage-guard.sh 2>"$tmp/err"; echo $?; }

echo "{\"five_hour\":{\"used_percentage\":79,\"resets_at\":$future},\"seven_day\":{\"used_percentage\":10,\"resets_at\":$future}}" >"$USAGE_GUARD_FILE"
check "79% allowed" 0 "$(guard)"
echo "{\"five_hour\":{\"used_percentage\":80,\"resets_at\":$future},\"seven_day\":{\"used_percentage\":10,\"resets_at\":$future}}" >"$USAGE_GUARD_FILE"
check "80% 5h blocked" 2 "$(guard)"
grep -q "Usage at 80% (5h) / 10% (week)" "$tmp/err" && echo "ok   block message" || { echo "FAIL block message"; fail=1; }
echo "{\"five_hour\":{\"used_percentage\":5,\"resets_at\":$future},\"seven_day\":{\"used_percentage\":85.5,\"resets_at\":$future}}" >"$USAGE_GUARD_FILE"
check "85% week blocked" 2 "$(guard)"
echo "{\"five_hour\":{\"used_percentage\":95,\"resets_at\":$past},\"seven_day\":{\"used_percentage\":10,\"resets_at\":$future}}" >"$USAGE_GUARD_FILE"
check "expired window ignored" 0 "$(guard)"
echo '{"seven_day":{"used_percentage":30,"resets_at":'$future'}}' >"$USAGE_GUARD_FILE"
check "missing five_hour allowed" 0 "$(guard)"
echo "not json" >"$USAGE_GUARD_FILE"
check "corrupt file allowed" 0 "$(guard)"
echo "{\"five_hour\":{\"used_percentage\":50,\"resets_at\":$future}}" >"$USAGE_GUARD_FILE"
check "threshold override blocks" 2 "$(USAGE_GUARD_THRESHOLD=50 guard)"
echo "{\"five_hour\":{\"used_percentage\":50,\"resets_at\":$future}}" >"$USAGE_GUARD_FILE"
check "garbage threshold falls back to 80" 0 "$(USAGE_GUARD_THRESHOLD=abc guard)"
echo '{"five_hour":{"used_percentage":90,"resets_at":"2026-10-25T00:00:00Z"}}' >"$USAGE_GUARD_FILE"
check "non-numeric resets_at counts as current" 2 "$(guard)"
rm -f "$USAGE_GUARD_FILE"
check "no file allowed" 0 "$(guard)"

# statusline
out=$(echo "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":$future},\"seven_day\":{\"used_percentage\":41.2,\"resets_at\":$future}}}" | scripts/statusline.sh)
[ "$out" = "5h 24% | wk 41%" ] && echo "ok   statusline text" || { echo "FAIL statusline text: $out"; fail=1; }
[ "$(jq -r .five_hour.used_percentage "$USAGE_GUARD_FILE")" = "23.5" ] && echo "ok   statusline saves file" || { echo "FAIL statusline saves file"; fail=1; }
rm -f "$USAGE_GUARD_FILE"
out=$(echo '{"model":{"display_name":"x"}}' | scripts/statusline.sh)
[ "$out" = "usage n/a" ] && [ ! -f "$USAGE_GUARD_FILE" ] && echo "ok   statusline without rate_limits" || { echo "FAIL statusline without rate_limits: $out"; fail=1; }

rm -rf "$tmp"
exit $fail
