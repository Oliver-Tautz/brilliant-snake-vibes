# Spec: Snake (Hand-drawn Horror)

Status: Draft v0.1. Items marked **TBD** need a decision.

## 1. Goal
A browser and phone Snake game with a hand-drawn horror look. The player hunts animals on a configurable, potentially huge grid. Delivered as a Godot web build to GitHub Pages via GitHub Actions.

## 2. Game Loop
1. Main menu: Play, Options, link to GitHub.
2. Options: start level, grid size, touch control mode, audio.
3. Run: the snake moves, hunts animals, collects power-ups.
4. Life lost: snake shrinks, brief invulnerability, play continues.
5. Game over (0 lives): score summary, local best, Restart or Menu.

### Rules
- Lives: 3. Everything costs a life: walls, own body, dangerous animals.
- On life loss the snake loses 50% of its length (minimum length **TBD**, suggest 3), is placed on a safe cell and is invulnerable for a short time (**TBD**, suggest 2 s, blinking).
- Speed increases with each food eaten, up to a cap (**TBD** values).
- Game over when the last life is lost.

## 3. Player Movement
- Grid-based logic, smooth interpolated visuals.
- No reversing into the neck; input buffer of 2 turns.
- Keyboard: Arrow keys and WASD. Esc or P pauses.
- Touch: swipe or on-screen D-pad, selectable in options. Pause button always visible.
- Speed is set by the starting level and rises during the run.

## 4. Grid and Screen Size
- Presets S / M / L / XL plus custom width x height.
- Must support at least 500 x 500 cells.
- Default view: camera follows the snake. Player can switch to fit-whole-grid in options.
- Zoom scales with grid size (zoom out for larger grids) but the snake never gets smaller than a minimum on-screen size (**TBD** px).
- Performance rule: no node per cell. Grid is a data array; only visible cells are drawn.

## 5. Starting Levels
- Numbered levels 1 to 10, each a combination of speed and starting length (table **TBD**).
- Selected in a simple, attractive options menu.

## 6. Animals (Food)
| Tier       | Behavior             | Modes                  | Reward                   |
| ---------- | -------------------- | ---------------------- | ------------------------ |
| 1 Prey     | Stationary, helpless | None                   | Low points, grow 1       |
| 2 Hunter   | Moves                | Dangerous / Vulnerable | Medium points, grow more |
| 3 Predator | Moves                | Dangerous / Vulnerable | High points, grow most   |

- Dangerous: touching it costs a life. Vulnerable: touching it eats it.
- Mode switching: timer cycle plus power-ups that force vulnerable.
- Every switch is telegraphed with a visual and audio warning.
- Spawn counts and AI movement rules **TBD**.
- Point and growth values **TBD** (tunable in one data file).

## 7. Power-ups
Dropped only by animals when caught (chance per tier **TBD**).

- Good: Slow-down, Ghost (pass through own body), Score multiplier, Force vulnerable.
- Bad: Speed-up, Smokescreen, Reverse controls, Darkness (small vision circle), Extra predator, Screen shake / distortion.
- Each has a duration and an on-screen indicator with a timer.

## 8. Scoring
- Points come from animals by tier, multiplied by active score multipliers.
- Local best saved in the browser per setup (start level + grid size).

## 9. Animations
As many as feasible, all in the hand-drawn style:
- Line-boil wobble on all sprites.
- Snake movement, turning and growth pulse.
- Animal idle, move, mode-change telegraph, catch and eat.
- Power-up pickup and active effects.
- Life loss, shrink, invulnerability blink, death sequence.
- Menu, pause and screen transitions.

## 10. Audio
- Music (menu and in-game), sound effects, menu sounds.
- Separate volume sliders for music and SFX, mute toggle.

## 11. Visual Style
Violent 1920s cartoon horror: hand-drawn, black and white, with sparse color accents.

### Look
- 1920s rubber-hose animation style: bendy limbs, pie-cut eyes, exaggerated squash and stretch, bouncy cartoon motion that turns violent.
- Base image is strictly black and white with grayscale shading.
- Visible ink lines with uneven thickness, line boil on everything.
- Old-film treatment over the whole screen: grain, scratches, dust, flicker, vignette, slightly uneven frame rate feel.
- Animals start cute and turn grotesque when dangerous (teeth, distorted faces, stretched limbs).

### Color accents
Color is used only to make gameplay elements stand out. Everything else stays black and white.

| Color  | Saturation                       | Used for                                        |
| ------ | -------------------------------- | ----------------------------------------------- |
| Red    | Strong, the only saturated color | Blood, damage, life loss, danger telegraph      |
| Purple | Muted, sickly                    | Bad power-ups, darkness and smokescreen effects |
| Green  | Muted, bile / rot                | Good power-ups, ghost mode, vulnerable animals  |

- No other colors anywhere, including UI.
- Colors look disgusting, not cheerful: dirty, desaturated, slightly off.

### Violence
- Catching an animal: cartoon gore, blood splatter in red, chunks, bones.
- Blood stains stay on the grid for a while and fade (performance: pooled decals, capped count).
- Life loss and death: exaggerated cartoon violence on the snake itself.

### UI
- Title cards and menus styled like 1920s intertitles: ornate frames, black background, white serif or hand-lettered text.
- Score, lives and power-up timers drawn in the same ink style.

### Effects
- Heavy effects are always on (no reduce-effects toggle).
- Film effects are one shader over the whole screen, not per sprite.

### References
References are for mood and technique only. No characters, designs or assets are copied; all art is original.

- **Cuphead:** 1920s rubber-hose animation, hand-inked lines, old-film grain and flicker, bouncy squash and stretch, bosses that turn grotesque.
- **Mouse P.I. for Hire:** the same 1920s style pushed into a darker, noir, more violent tone in black and white.
- **2005-era Newgrounds Flash games:** over-the-top, slapstick cartoon gore. Exaggerated blood sprays, absurd amounts of red, comedic brutality rather than realistic violence.

Target mix: the drawing and animation quality of the 1920s references, with the gleeful, excessive violence of early Newgrounds.

## 12. Pause
- Pause button (and Esc / P).
- Menu: Resume, Restart, Options, Quit to menu, link to GitHub.

## 13. Non-Functional Requirements
- Engine: Godot 4.x, GDScript, Compatibility renderer for web.
- Web export single-threaded (GitHub Pages cannot send the headers threads need).
- Performance: 60 FPS on mid-range phones in the browser at 500 x 500.
- Architecture: separate game logic (grid, rules) from presentation; logic is testable without scenes.
- Godot practices: scenes small and reusable, signals up and calls down, autoloads only for global services (audio, settings, save), typed GDScript, object pooling for effects, no per-frame allocations in hot paths.
- Input abstraction layer so keyboard, swipe and D-pad share one interface.
- Settings and best scores stored locally in the browser.
- Responsive layout for portrait and landscape, touch targets large enough.
- Asset budget: keep build size small for fast load (target **TBD**).

## 14. Delivery
- Repo hosted on GitHub; GitHub Pages is the publishing target.
- GitHub Actions on every push: run the unit tests and export the Godot web build.
- Every push is published: `main` to the site root, other branches to `/branch/<name>/`, tags `v*` to `/v/<version>/` (kept). Deleting a branch removes its build.
- The game shows which build it is (version tag, or branch and commit).
- Build fails if the tests or the export fail.

## 15. Open Questions
- Art and music references.
- Level table (speed and length per level).
- Point values, growth values, drop chances.
- Animal AI details and spawn rules.
- Minimum snake size on screen, minimum length after shrinking.
- Wall or self hit: exact respawn behavior.

## 16. Testing
- All code must be covered by unit tests.
- Every change must pass unit tests before it is committed.
- If tests fail, ask the `change-reviewer` subagent what to do before retrying.

## 17. Asset Pipeline
Assets are drawn as code (free, no external art or music dependencies):
- SVG written as markup, or a small Python or Godot script that outputs PNGs.
- Godot's own shapes, particles and shaders.
- Best fit: simple, geometric or pixel-style art, UI, tiles and effects.
- Generator scripts are kept in the repo so assets are reproducible and can be tweaked.
- Exception: one bundled open-licence (SIL OFL) serif font, since browsers have no system fonts. Credited in CREDITS.md.
