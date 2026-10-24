# Spec: Snake (Hand-drawn Horror)

Status: Draft v0.1. Items marked **TBD** need a decision.

## 1. Goal
A browser and phone Snake game with a hand-drawn horror look. The player hunts chickens in an arena that shrinks each level and fights three enemy snakes for them. Delivered as a Godot web build to GitHub Pages via GitHub Actions.

## 2. Game Loop
1. Main menu: Play, How to play, Gore (On / Off), Highscores, Options, link to GitHub.
2. Options: start level, view (follow / fit), on-screen arrows on touch (shown / hidden), fullscreen, audio.
3. Run: the snake moves, hunts chickens, competes with three enemy snakes, collects power-ups.
4. Life lost: snake shrinks, brief invulnerability, play continues.
5. Level won: all three enemy snakes are dead. The next level starts (see §5).
6. Game over (0 lives): score summary and the highscore table with the new entry marked, Restart or Menu.

### Rules
- Lives: 3. Everything costs a life: walls, own body, an enemy snake's body or a lost head-on fight (§6b), the level timer running out (§5), dangerous animals.
- On life loss the snake loses 50% of its length (minimum length **TBD**, suggest 3), is placed on a safe cell and is invulnerable for a short time (**TBD**, suggest 2 s, blinking).
- The player's speed increases with each food eaten, up to a cap (**TBD** values), and goes back to its base speed at each new level.
- Game over when the last life is lost.

## 3. Player Movement
- Grid-based logic, smooth interpolated visuals.
- No reversing into the neck; input buffer of 2 turns.
- Keyboard: Arrow keys and WASD. Esc or P pauses.
- Touch: swiping always works; the on-screen D-pad can be shown or hidden in options. Pause button always visible.
- The player's speed rises as they eat (see Rules); levels only make the enemies faster (§5).

## 4. Arena and Screen Size
- No grid size option: the arena size comes from the level (§5). Level 1 arena size **TBD**.
- The engine must still support arenas of at least 500 x 500 cells.
- Default view: the whole arena fits the screen, with an arrow ahead of every snake's head showing where it is going. Player can switch to a camera that follows the snake in options.
- Zoom scales with arena size (zoom out for larger grids) but the snake never gets smaller than a minimum on-screen size (**TBD** px).
- Performance rule: no node per cell. Grid is a data array; only visible cells are drawn.

## 5. Levels and Progression
- A level is won when all three enemy snakes are dead.
- Each level has a time limit (**TBD**). When it runs out before all three enemies are dead, the player loses a life and the level restarts: clock reset, all three enemies back, score kept (arcade style: the score only resets at game over). The player's length and speed on a retry are **TBD** (suggest: as at the start of the level). Game over on the last life.
- Each new level is harder: the enemy snakes are faster (the player's speed is not affected) and the arena shrinks by 10% (minimum size **TBD**). Reaching level 10 should be hard.
- Score and lives carry over to the next level; what happens to the player's length is **TBD** (suggest: back to the starting length).
- Numbered levels 1 to 10 can be picked as the starting level, each a combination of enemy speed and arena size (table **TBD**).
- Selected in a simple, attractive options menu.

## 6. Animals (Food)
### Chickens
- Chickens are the prey and the only animals for now. They replace the stationary tier 1 in the table below.
- The arena keeps a target number of chickens (**TBD**, scales with arena size). When there are fewer, new ones appear one at a time on random free cells after a short delay (**TBD**, suggest 1 s), not instantly.
- Big chickens: rarer (**TBD**, suggest 1 in 8), tinted slightly orange, worth more points (see §8) and make the snake grow faster (**TBD**, suggest +3).
- Now and then a chicken hops 1 to 2 cells, slowly, into free cells only. A short wind-up (crouch and shake, **TBD**, suggest 0.5 s) comes first so the player can see it coming.
- Enemy snakes eat chickens too and grow from them.

### Later tiers
Tier 1 is now the chickens above; tiers 2 and 3 are for later.

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

## 6b. Enemy Snakes
- Three per level. Each is themed after a real snake, with its own head design, colour and speed:

| Snake  | Colour       | Real snake     | Speed  | Head                                   |
| ------ | ------------ | -------------- | ------ | -------------------------------------- |
| Green  | Muted green  | Green anaconda | Slow   | Broad, heavy jaw                       |
| Purple | Muted purple | King cobra     | Faster | Spread hood                            |
| Black  | Ink black    | Black mamba    | Fast   | Narrow coffin-shaped head, black mouth |

- They compete with the player for chickens and grow when they eat.
- Contact rules (bodies are walls):
  - Player's head into an enemy's body: the player loses a life.
  - Enemy's head into the player's body: the enemy dies. Trapping them is a way to kill them.
  - Player's head into an enemy's head from the side: the enemy dies, whatever its length. The two cells right behind its head count as the head too, since fast enemies move up to twice between the player's steps.
  - Head-on (the heads meet face to face): the longer snake wins; on a tie the player wins.
  - The biteable part (head and the two cells behind it) is marked with a pulsing muted-green glow.
  - Enemies avoid walls, their own bodies and each other; an enemy with no free move dies.
- Dead enemies burst (gore) and do not come back this level. Their body turns into chickens, one per few segments (**TBD**), tinted in the dead snake's colour; they count as normal chickens.
- Killable, but a challenge: they steer clear of the player's head when they are shorter, and the faster ones flee.
- AI is semi-intelligent and cheap: each move scores its three options (towards the nearest chicken, away from walls and bodies, a short flood fill of at most **TBD** cells, suggest 30, to avoid dead ends). No full-grid pathfinding; a fixed cost per enemy move.

## 7. Power-ups
Dropped only by animals when caught (chance per tier **TBD**).

- Good: Slow-down, Ghost (pass through own body), Score multiplier, Force vulnerable.
- Bad: Speed-up, Smokescreen, Reverse controls, Darkness (small vision circle), Extra predator, Screen shake / distortion.
- Each has a duration and an on-screen indicator with a timer.

## 8. Scoring
- Points come from animals and enemy snakes, multiplied by active score multipliers.
- Base points: chicken 1, big chicken 5, enemy snake 20.
- Level bonus: every category gets round(level x 0.33 x base) extra. Level 3 example: chicken 1 + 1, big chicken 5 + 5, enemy snake 20 + 20.
- Enemy snakes then lose 1 point per 10 s since the level started (the decay does not scale with the level), never below 5.
- Score multipliers apply last (**TBD**, suggest).
- Highscores: the top 10 runs (name, score, level reached, date) saved in the browser. Shown in the main menu's Highscores page and on the game-over card, with the new entry marked.
- A run that makes the table asks for the player's name on the game-over card (up to 12 characters; the last name used is offered again). On touch screens, tapping the field opens the browser's on-screen keyboard.

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
- Style: 1920s cartoon and old-record horror: out-of-tune toy piano, stride bass, slide whistles, a "wah-wah" trombone for losing a life, gramophone crackle over the music.
- Music: a slow minor waltz for the menus, a fast ragtime loop in game that speeds up a little each level.
- Sound effects: eating (gulp), chicken squawk before a hop, gore (crunch and splat, only with Gore on), crash, enemy death, life lost, level cleared (fanfare), the last 10 s of the level timer (ticks) and time up (gong), menu clicks.
- All sound is synthesised by code at startup (§17); parameters follow the divine_inspiration seed for "snake-sounds".

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

| Color  | Saturation                       | Used for                                                                |
| ------ | -------------------------------- | ----------------------------------------------------------------------- |
| Red    | Strong, the only saturated color | Blood, damage, life loss, danger telegraph                              |
| Purple | Muted, sickly                    | Bad power-ups, darkness and smokescreen effects, the purple enemy snake |
| Green  | Muted, bile / rot                | Good power-ups, ghost mode, vulnerable animals, the green enemy snake, an enemy's biteable head and neck |
| Orange | Muted, slightly off              | Big chickens                                                            |

- Chickens left by a dead enemy snake take that snake's colour (green, purple, or ink black).

- No other colors anywhere, including UI.
- Colors look disgusting, not cheerful: dirty, desaturated, slightly off.

### Violence
- Catching an animal: cartoon gore, blood splatter in red, chunks, bones.
- Blood stains stay on the grid for a while and fade (performance: pooled decals, capped count).
- Life loss and death: exaggerated cartoon violence on the snake itself.
- Gore option (On / Off, default On, in the main menu). Off hides all gore: no blood, bones, chunks or stains, and nothing replaces them.

### UI
- Title cards and menus styled like 1920s intertitles: ornate frames, black background, white serif or hand-lettered text.
- Score, lives and power-up timers drawn in the same ink style.

### Effects
- Heavy effects are always on (no reduce-effects toggle). The Gore option is the only exception.
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
- Level table (enemy speed and arena size per level).
- Growth values, drop chances.
- Levels: level 1 arena size, minimum arena size, time limit, the player's length at a new level.
- Chickens: target count, big chicken rate, hop wind-up, chickens per dead-enemy segment.
- Enemy AI: flood-fill cap.
- Animal AI details and spawn rules (chickens and enemy snakes: see §6, §6b).
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
- Sound synthesised in GDScript (oscillators, noise, envelopes) into AudioStreamWAV at startup.
- Best fit: simple, geometric or pixel-style art, UI, tiles and effects.
- Generator scripts are kept in the repo so assets are reproducible and can be tweaked.
- Exception: one bundled open-licence (SIL OFL) serif font, since browsers have no system fonts. Credited in CREDITS.md.
