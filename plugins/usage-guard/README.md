# usage-guard

Blocks every tool call once your claude.ai plan usage reaches a threshold (default 80%) in the 5-hour or the weekly window.

## How it works

1. `scripts/statusline.sh` is the status line command. Claude Code pipes session JSON to it. It saves `rate_limits` to `~/.claude/usage.json` and prints e.g. `5h 23% | wk 41%`.
2. `scripts/usage-guard.sh` is a `PreToolUse` hook (all tools). It reads that file and exits with code 2 when either window is at or above the threshold. Claude receives the message on stderr.

A plugin cannot set `statusLine`, so you add it to your settings yourself.

## Setup

1. Add this repo's marketplace and install the plugin, or load it with `--plugin-dir plugins/usage-guard`:

   ```
   /plugin marketplace add Oliver-Tautz/brilliant-snake-vibes
   /plugin install usage-guard@brilliant-snake-vibes
   ```
2. Add the status line to `~/.claude/settings.json` (path depends on where the plugin is installed):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/absolute/path/to/plugins/usage-guard/scripts/statusline.sh"
     }
   }
   ```

3. Run `/hooks` and confirm a `PreToolUse` hook from `usage-guard` is registered.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `USAGE_GUARD_THRESHOLD` | `80` | Percent at which tool calls are blocked |
| `USAGE_GUARD_FILE` | `~/.claude/usage.json` | Where usage is saved and read |

## Tests

```
plugins/usage-guard/tests/test.sh
```

Uses a temp file, never `~/.claude`. Requires `jq`.

## Known limits

- The value is only as fresh as the last API response, so usage can overshoot the threshold slightly.
- `rate_limits` only exists for claude.ai Pro and Max plans, and only after the first API response in a session. Until then (or with no file) nothing is blocked.
- A window whose `resets_at` has passed is treated as stale and ignored.
- The hook blocks all tool calls, including file writes, so the agent can only summarize in chat once it trips.
- Not verified: whether the status line runs in the VS Code extension. The docs describe it as a terminal feature, so if it does not, run Claude Code in VS Code's integrated terminal.
- The hook fails open: a corrupt or unreadable usage file never blocks.
