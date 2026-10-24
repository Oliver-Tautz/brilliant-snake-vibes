#!/usr/bin/env bash
# PreToolUse hook: exit 2 (block) when the 5h or weekly usage is at or above the threshold.
# Fails open: a missing or unreadable usage file never blocks.
file="${USAGE_GUARD_FILE:-$HOME/.claude/usage.json}"
threshold="${USAGE_GUARD_THRESHOLD:-80}"
[[ $threshold =~ ^[0-9]+([.][0-9]+)?$ ]] || threshold=80  # garbage must not block everything

cat >/dev/null
[ -f "$file" ] || exit 0

# A window whose resets_at (unix seconds) is in the past is stale and ignored; a missing or
# non-numeric resets_at counts as current. Absent values print "-".
read -r five week < <(jq -r --argjson now "$(date +%s)" '
  [.five_hour, .seven_day]
  | map(if . != null and .used_percentage != null
          and ((.resets_at | type) != "number" or .resets_at > $now)
        then .used_percentage else "-" end)
  | join(" ")' "$file" 2>/dev/null) || exit 0

over() { [ "${1:--}" != "-" ] && awk -v p="$1" -v t="$threshold" 'BEGIN { exit !(p + 0 >= t + 0) }'; }

if over "$five" || over "$week"; then
  fmt() { [ "${1:--}" = "-" ] && echo "n/a" || printf '%.0f%%' "$1"; }
  echo "Usage at $(fmt "$five") (5h) / $(fmt "$week") (week). Stop. Update PROGRESS.md if possible and summarize where you are." >&2
  exit 2
fi
exit 0
