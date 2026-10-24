# Roadmap

Work requested by the user, in order. Status: proposed → agreed → in progress → done.
Decisions are logged in [agent_adr.md](../agent_adr.md); spec changes are only made after the user approves them.

## 1. Performance testing and fixes — done (waiting for the user's playtest)
Problem: the game was very slow in the browser on the user's integrated-graphics laptop.

- `tools/benchmark.gd` renders a heavy staged scene offscreen and reports per-layer frame times and draw calls.
  Run: `godot --path . -s tools/benchmark.gd -- 1920 1080 200`; weak-GPU worst case: prefix `LIBGL_ALWAYS_SOFTWARE=1`.
- F3 in game toggles an FPS / frame-time / draw-call overlay (works in the browser too).
- Results (1920x1080, fast desktop GPU): before 28 ms / 4,883 draw calls per frame; after 5 ms / 313 calls.
- Results (software rendering, worst case): before 19 fps at 2880x1800; after 57 fps at the fixed internal resolution, independent of screen size.
- Fixes: all circles, ellipses, snake segments and blood drops are quads of one generated disc texture so they batch; the game renders at 1152x648 and is scaled up to the window.
- Still open: dense prey (400 on screen) costs ~21 ms on the fast GPU. Matters for the frenzy step; the fix would be pre-rendered prey sprites.

## 1b. Touch controls — done (waiting for the user's tablet test)
Added on request between steps, so the game can be tried on a tablet.
- Swipe anywhere (one zig-zag gesture can queue two turns), on-screen D-pad (bottom-right, shown on touch
  screens), always-visible pause button (top-right), tap to resume or restart.
- All input goes through `presentation/controls.gd` (spec §13 input layer).
- Step 3 added an option to show or hide the D-pad; swiping always works.

## 1c. Branch builds and versioning — done (waiting for a working push)
- Every push is published: `main` → https://oliver-tautz.github.io/brilliant-snake-vibes/,
  branch `dev` → …/brilliant-snake-vibes/branch/dev/, tag `v0.2.0` → …/brilliant-snake-vibes/v/0.2.0/.
- Deleting a branch removes its folder. The game shows which build it is in the bottom-left corner.
- User to do once: Settings → Pages → Source: "Deploy from a branch", `gh-pages`, `/ (root)`.
- Pushing from the user's machine currently hangs on SSH (port 22); see the chat for the port-443 workaround.

## 3. Menu and options, with a gore switch — done (waiting for the user's tablet test)
- Title card: Play, Options, GitHub. Pause card: Resume, Restart, Options, Quit to menu, GitHub.
  Game-over card: score, Restart, Menu. All intertitle cards with buttons (keyboard, mouse, touch).
- Options: Gore (On / Off), Arrows on touch (Shown / Hidden), Fullscreen (On / Off).
  Gore and arrows are saved locally (`Settings` autoload); fullscreen is not, browsers only allow it after a tap.
- Gore On (default): blood, bones and splats. Off: dust puff and spinning stars, no stains.
  (The user rejected three levels: on/off only.)
- Spec changes suggested to the user (not made): §11 a Gore on/off option; §2 options list.
- Audio: see step 6. Start level and view (follow / whole arena) were added with step 5; highscores in step 4. Grid size: dropped, see step 5.

## 4. Menu follow-ups — done (waiting for the user's playtest)
- Gore Off hides all gore; no dust or stars instead.
- The player's snake gets fatter again ("in between": clearly fatter, rows almost touch but keep their outlines).
- Main menu: Gore On / Off moves to the top level; a Highscores page is added.
- Highscores (top 10: score, level, date) saved locally; shown on the game-over card with the new entry marked (spec §8).

## 5. New gameplay — done (waiting for the user's playtest), written into spec §1–§6b, §8, §11, §15
Replaces the earlier "frenzier gameplay" step; that step's ideas stay below for later.
1. Chickens refill one at a time on random free cells when below the target count (§6).
2. Big chickens, slightly orange, worth more and grow more (§6, §11).
3. Three enemy snakes: green anaconda (slow), purple king cobra (faster), black mamba (fast), each with its own
   head. They compete for chickens and die when their head hits your body, or head-on if you are at least as long (§6b).
   Cheap AI: score three moves, short flood fill, no full-grid pathfinding.
   A dead enemy's body turns into chickens in its colour (§6b).
4. A level is won when all three are dead; each level has a time limit, and running out costs a life and restarts the level (§5).
5. Each level: enemies faster, arena 10% smaller; level 10 should be hard (§5).
   Points: chicken 1, big chicken 5, enemy 20 minus 1 per 10 s since the level started, at least 5, plus round(level x 0.33 x base)
   in every category (§8; level 3: +1 / +5 / +20). Timer retries keep the score (arcade style). The grid size option is dropped (§4).
6. Chickens sometimes hop 1 to 2 cells after a short wind-up (§6).
Suggested order: roadmap step 4 first (quick), then items 1 + 2 + 6 (chickens), then 3, then 4 + 5 (levels).

## Later: frenzier gameplay ideas (from the earlier step 2)
Problem: growing takes far too long; it should feel frantic.
Reference from the user: **Pac-Man Championship Edition DX** — as fast and interesting, but in the current
style; some flashing colours are allowed (spec §11 change needed). What makes CE DX work: constantly rising
speed, short timed score-attack rounds, sleeping enemies that wake and trail you as long "ghost trains" you
devour in one chain, and neon flashes as feedback.

Ideas (to pick from):
- Grow more per prey (e.g. +3 instead of +1). Spec §6 says tier 1 grows 1, so this needs a spec change.
- Much denser prey, spawning in clusters (a "flock" of chicks) so you can chain-eat.
- Combo: eating again within ~1.5 s raises a multiplier for score and growth, shown as a shouted intertitle ("BLOODBATH x4!").
- Frenzy mode: a long enough combo briefly speeds the snake up and makes prey panic.
- Faster starting speed and steeper speed ramp.
- Longer starting snake.

## Spec drift to fix
- Fixed: §1 used to say "via a GitLab pipeline"; it now says GitHub Actions like §14.

## 6. Audio — first try done (waiting for the user's ears)
- Everything synthesised in GDScript at startup from the "snake-sounds" seed: effects, a menu waltz and an
  in-game rag, gramophone crackle. Music, Sounds and Mute in the options (spec §10).
- Listen outside the game: `godot --headless --path . -s tools/export_sounds.gd -- <folder>`.
