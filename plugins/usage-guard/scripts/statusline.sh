#!/usr/bin/env bash
# Status line command: saves rate_limits for the guard hook and prints a short status.
file="${USAGE_GUARD_FILE:-$HOME/.claude/usage.json}"
input=$(cat)

limits=$(printf '%s' "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
if [ -n "$limits" ]; then
  mkdir -p "$(dirname "$file")"
  tmp=$(mktemp "$file.XXXXXX") && printf '%s\n' "$limits" >"$tmp" && mv "$tmp" "$file"  # per-session temp file
fi

five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
out=""
[ -n "$five" ] && out="5h $(printf '%.0f' "$five")%"
[ -n "$week" ] && out="${out:+$out | }wk $(printf '%.0f' "$week")%"
printf '%s\n' "${out:-usage n/a}"
