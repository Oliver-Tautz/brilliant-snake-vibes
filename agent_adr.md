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

## 2026-10-10 — First playable scene: plain Node2D with custom drawing
- Decision: `presentation/main.tscn` is one Node2D that draws grid, snake and food with `_draw()` (visible cells only), a smoothed Camera2D following the head, and a CanvasLayer HUD. Keys are handled directly in the scene (WASD/arrows, Esc/P pause, Enter/Space/R restart), cells are 24 px, grid 100x100.
- Decided by: claude (layout, controls); user (100x100 camera-follow grid, core loop only)
- Why: smallest thing that is playable and keeps the no-node-per-cell rule. Deferred to later iterations: input abstraction layer (§13) and touch controls/pause button (§3), interpolated movement (§3), zoom scaling with grid size (§4), pause menu with Resume/Restart/Options/Quit (§12). Movement keys use physical keycodes so WASD works on any layout.
- Source: spec §3, §4, §13; user answers
- Revisit if: touch controls or the options menu are added.

## 2026-10-10 — Many food items, one per 80 cells
- Decision: the grid holds one food item per 80 cells (125 on 100x100, minimum 1). Eating one spawns a replacement elsewhere, so the count stays constant. `CELLS_PER_FOOD` in `logic/game_config.gd`.
- Decided by: user (asked for far more spawns); claude (the ratio)
- Why: the camera shows about 1300 of 10000 cells, so this keeps roughly 15 items in view. Scales with the configurable grid size.
- Source: user feedback after first playtest
- Revisit if: animals and power-ups arrive; food may become one tier among several. Known: if the board ever fills completely, the food count drops and does not refill.

## 2026-10-10 — Smooth rendering by interpolating one tick behind
- Decision: the snake is drawn as an antialiased polyline plus round joints and a head with eyes, with each part sliding from its previous cell to its current one over the tick (`last_tick_moved` and `tail_vacated` come from the logic). The camera follows the interpolated head with no extra smoothing. 4x MSAA for 2D; food pulses.
- Decided by: claude
- Why: previous 1-cell squares looked jumpy. Interpolating from known previous cells needs no copy of the body per tick. Rendering is one tick behind the logic, a deliberate trade for smoothness.
- Source: user feedback; spec §3 (smooth interpolated visuals)
- Revisit if: the one-tick visual lag feels bad on collisions.

## 2026-10-10 — Snake path through cell centres (fixes corner cutting), supersedes per-part interpolation
- Decision: the snake's drawn centre line runs through the real cell centres; only the head point slides from the previous head cell and the tail end slides from the vacated cell. Segments are drawn without caps plus a circle at every joint.
- Decided by: claude (after user reported the animation looked wrong)
- Why: interpolating every part in a straight line cut diagonally across corners. This keeps corners square to the grid and the body length constant during a slide.
- Source: user feedback; spec §3; verified with screenshots
- Revisit if: turning should look bendier (e.g. curved corners for the rubber-hose look).

## 2026-10-10 — 1920s ink-on-paper art direction, all drawn as code
- Decision: low-contrast grey checker floor (shader), black boiling ink outlines at 12 fps with uneven width, white rubber-hose snake with ink bands, pie-cut eyes and fangs, trembling mouse-like prey with ears and curly tails, thick wobbly ink walls, one full-screen film shader (gate weave, 18 fps flicker, grain, scratches, dust, vignette, slight desaturation). Red only for blood. Procedural variation is seeded from divine_inspiration("snake-game").
- Decided by: claude
- Why: spec §11 asks for 1920s rubber-hose black and white with red accents only for gore; §17 asks for assets as code. The checker floor gives the grid a period look while staying readable; it was toned down after it read as a transparency pattern.
- Source: spec §9, §11, §17; user feedback that the art style was wrong
- Revisit if: hand-drawn sprites replace the procedural drawing.

## 2026-10-10 — Cartoon gore with fixed pools
- Decision: eating sprays red droplets and two bones and leaves a splat; a crash sprays more, five bones, and shakes the camera. Pools are capped (256 drops, 24 bones, 160 splats in a ring buffer); splats fade over 25 s.
- Decided by: claude
- Why: spec §11 Violence and §13 (pooled effects, capped decal count, no per-frame allocation).
- Source: spec §9, §11, §13
- Revisit if: profiling on phones shows the splat drawing is too heavy.

## 2026-10-10 — Camera zoom 1.7, MSAA removed, serif system font
- Decision: camera zoom fixed at 1.7 (about 28 x 16 cells visible). MSAA setting removed. HUD and cards are intertitles (black panel, double white frame) using a SystemFont serif (DejaVu/Liberation/Noto Serif).
- Decided by: claude
- Why: at zoom 1 the prey were unreadable. 2D MSAA is not supported by the Compatibility renderer (Godot logged a warning), so it did nothing. SystemFont needs no bundled asset.
- Source: screenshots; Godot warning; spec §4, §11 UI
- Revisit if: zoom must scale with grid size (spec §4) or the web build shows the fallback sans font (system fonts are not available in browsers; a bundled OFL serif would fix it, needs user approval as an external asset).

## 2026-10-10 — Screenshot tool for visual checks
- Decision: `tools/capture.gd` renders the main scene in a fixed 1152x648 offscreen viewport and saves a PNG for staged scenarios (start, paused, play, corners, eat).
- Decided by: claude
- Why: headless runs render nothing, and the window manager resizes real windows, so visual problems went unnoticed before.
- Source: own judgment
- Revisit if: the Godot MCP gains a screenshot tool.

## 2026-10-10 — Gore timing and lifecycle fixes from review
- Decision: the logic reports `last_crash` so crash gore lands where the head hit, not where the respawn faces. Eaten prey stays drawn until the sliding head reaches it, then bursts. Gore freezes while paused, clears on restart, and stops redrawing once all splats have faded. Ink helpers use separate scratch arrays.
- Decided by: reviewer (findings); claude (fixes)
- Why: crash spray always pointed right after a respawn; blood appeared a cell ahead of the mouth; faded splats cost a redraw every frame; a shared scratch array was reallocated every frame (spec §13).
- Source: reviewer findings
- Revisit if: pause becomes a real tree pause with a pause menu (spec §12).
