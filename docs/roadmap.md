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

## 2. Frenzier gameplay — proposed
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

## 3. Menu and options, with a low-violence option — proposed
- Main menu (spec §2): Play, Options, link to GitHub, as an intertitle card.
- Options (spec §2, §4, §5): violence level, start level, grid size, view (follow / fit), later audio and touch mode.
- Pause menu (spec §12): Resume, Restart, Options, Quit to menu.
- Settings saved locally (spec §13), via a Settings autoload.
- Violence levels:
  - Full (default): current blood, bones and splats.
  - Low: no red, no bones; ink splotches that fade fast.
  - None: cartoon puff of dust and stars, no stains.
- Spec §11 (Violence, "heavy effects always on") needs a change to allow this.

## Spec drift to fix
- §1 still says "via a GitLab pipeline"; §14 now says GitHub Actions.
