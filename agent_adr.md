# Agent Decision Log

Append-only. Format is defined in AGENTS.md.

## 2026-10-10 — Project at repo root, GUT vendored
- Decision: `project.godot` at repo root; GUT v9.7.1 vendored in `addons/gut`; `.gdignore` in `plugins/` and `docs/`.
- Decided by: user (root layout, GUT, vendoring); claude (version pin)
- Why: Godot default layout; v9.7.1 is the latest GUT release and runs on Godot 4.7.2 headless.
- Source: user answer
- Revisit if: the repo gains a second Godot project.

## 2026-10-10 — Respawn at grid centre, heading right
- Decision: after a life loss the snake is laid out horizontally ending at the grid centre, facing right, and the pending turn buffer is cleared.
- Decided by: claude
- Why: spec lists the exact respawn behaviour as an open question; centre is simple and deterministic. A true "safe cell" search is deferred.
- Source: own judgment (spec §15)
- Revisit if: animals or obstacles can occupy the centre.

## 2026-10-10 — Invulnerability measured in ticks; walls block instead of kill
- Decision: invulnerability lasts 10 ticks (logic has no clock). While invulnerable the snake passes through its own body, and a wall blocks the move without costing a life.
- Decided by: claude
- Why: keeps logic deterministic and testable; spec suggests ~2 s, which is 10 ticks at the base 0.2 s interval. Passing through walls would leave the grid.
- Source: spec §2 suggestion plus own judgment
- Revisit if: the tick rate becomes variable enough that 10 ticks is far from 2 s.

## 2026-10-10 — Placeholder gameplay values
- Decision: min length 3, start length 3, 3 lives, 10 points per food, interval 0.2 s down to 0.06 s in 0.004 s steps per food. All in `logic/game_config.gd`.
- Decided by: claude
- Why: the spec marks these TBD; they are easy to tune in one file.
- Source: spec §2 suggestions plus own judgment
- Revisit if: playtesting feels too slow or too fast.

## 2026-10-10 — Invulnerability in seconds, supersedes the tick-based entry
- Decision: invulnerability is 2.0 s of game time, decremented by the current tick interval each tick.
- Decided by: reviewer (flagged that 10 ticks shrinks to 0.6 s at max speed); claude (implementation)
- Why: the spec asks for ~2 s regardless of speed. Alternative of scaling ticks by speed was more complex.
- Source: spec §2; reviewer finding
- Revisit if: pause or slow-motion effects need to change the game clock.

## 2026-10-10 — Occupancy grid for collision and food spawn
- Decision: keep a per-cell segment-count array next to the body array; collisions and food spawn use it instead of searching the body.
- Decided by: reviewer (flagged per-tick slice copies and O(W·H·N) food scan); claude (implementation)
- Why: spec §4 and §13 require 500x500 grids and no hot-path allocations. Counts (not flags) because invulnerable passes through the body.
- Source: spec §4, §13; reviewer finding
- Revisit if: `body.push_front` shifting on very long snakes shows up in profiling; a ring buffer would fix it.

## 2026-10-10 — Export exclusions deferred
- Decision: no export preset yet, so `addons/gut` and `tests/` are not excluded from builds.
- Decided by: claude
- Why: the web export is out of scope for iteration 1; revisit when the GitLab pipeline is built.
- Source: reviewer nit
- Revisit if: an export preset is created (exclude `addons/gut/*`, `tests/*`).
