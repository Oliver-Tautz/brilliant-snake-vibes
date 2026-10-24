## Tunable gameplay values. Spec TBDs use the spec's suggestions.
extends RefCounted

const LIVES := 3
const START_LENGTH := 3
const MIN_LENGTH := 3
const INVULNERABLE_SECONDS := 2.0
const INPUT_BUFFER := 2
const BASE_INTERVAL := 0.2
const MIN_INTERVAL := 0.06
const INTERVAL_DECAY := 0.004
const CELLS_PER_FOOD := 80  # target chickens: one per this many arena cells

# Points (spec §8): base + round(level x LEVEL_BONUS x base); enemies then lose 1 per decay step.
const CHICKEN_POINTS := 1
const BIG_POINTS := 5
const ENEMY_POINTS := 20
const LEVEL_BONUS := 0.33
const ENEMY_DECAY_SECONDS := 10.0
const ENEMY_MIN_POINTS := 5

# Chickens (spec §6)
const BIG_CHANCE := 0.125  # share of new chickens that are big
const BIG_GROWTH := 3
const REFILL_DELAY := 0.4  # seconds between new chickens while below the target (spec suggests 1 s; enemies eat fast)
const HOP_RATE := 0.6  # hops started per second across the arena
const HOP_WINDUP := 0.5  # seconds of crouch and shake before a hop
const HOP_STEP := 0.3  # seconds per hopped cell
const MAX_HOPS := 3
const SEGMENTS_PER_CHICKEN := 3  # a dead enemy leaves one chicken per this many segments

# Levels (spec §5)
const ARENA := Vector2i(60, 40)  # level 1
const MIN_ARENA := Vector2i(16, 12)
const ARENA_SHRINK := 0.9
const LEVEL_SECONDS := 120.0

# Enemy snakes (spec §6b), by EnemySnake.Species: anaconda, cobra, mamba
const ENEMY_START_LENGTH := 5
const ENEMY_INTERVAL: Array[float] = [0.3, 0.2, 0.13]  # seconds per move at level 1
const ENEMY_SPEEDUP := 0.93  # interval factor per level
const ENEMY_FLEE: Array[float] = [1.0, 3.0, 6.0]  # how hard a shorter enemy keeps away from the player's head
const FLEE_RANGE := 6
const FLOOD_CAP := 30
