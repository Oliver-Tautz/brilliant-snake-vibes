## Art direction decoded from divine_inspiration("snake-art").
## Every art parameter comes from one character of the seed: its index in the 64-symbol alphabet
## (A-Z a-z 0-9 - _). Continuous values are scaled into the range spec §11 allows; categorical
## choices take index % option count. The seed position is cited on every line, and agent_adr.md
## has the same table. Spec rules still win: black and white with red only for blood, pie-cut eyes.
class_name Art
extends RefCounted

const TOPIC := "snake-art"
const SEED := "iQArc_U_sXqaOB8InrOqe6h2jRfPE3ajgV9SQ2N7Tdb-C09SiKFe-XgDIDug-dKQ"
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

enum FloorPattern { CHECKER, FLOORBOARDS, HARLEQUIN, POLKA }
enum SkinPattern { BANDS, DIAMONDS, SPOTS, STRIPE }
enum HeadShape { ROUND, VIPER, BIG_JAW }
enum PreySpecies { MOUSE, BEETLE, CHICK, FROG }
enum WallStyle { SINGLE, DOUBLE, HATCHED }
enum OrnamentStyle { DOTS, DIAMONDS, SCROLLS }

static var floor_pattern: int = pick(0, 4)  # seed[0]
static var floor_contrast: float = lerpf(0.03, 0.10, amount(1))  # seed[1]
static var skin: int = pick(2, 4)  # seed[2]
static var body_width: float = lerpf(0.66, 0.9, amount(3))  # seed[3], fraction of a cell
static var head: int = pick(4, 3)  # seed[4]
static var fang_length: float = lerpf(0.3, 0.6, amount(5))  # seed[5], fraction of head radius
static var eye_size: float = lerpf(0.3, 0.5, amount(6))  # seed[6], fraction of head radius
static var ink_width: float = lerpf(2.0, 4.0, amount(7))  # seed[7], px
static var boil_fps: float = lerpf(8.0, 14.0, amount(8))  # seed[8]
static var boil_amount: float = lerpf(0.4, 1.4, amount(9))  # seed[9], px
static var prey_species_a: int = pick(10, 4)  # seed[10]
static var prey_species_b: int = pick(11, 4)  # seed[11]
static var prey_nerves: float = lerpf(0.3, 1.5, amount(12))  # seed[12], tremble strength
static var prey_size: float = lerpf(0.28, 0.4, amount(13))  # seed[13], fraction of a cell
static var gore_amount: float = lerpf(0.6, 1.8, amount(14))  # seed[14], blood multiplier
static var extra_bones: int = pick(15, 4)  # seed[15]
static var film_grain: float = lerpf(0.04, 0.14, amount(16))  # seed[16]
static var film_flicker: float = lerpf(0.03, 0.10, amount(17))  # seed[17]
static var film_scratches: int = pick(18, 4) + 1  # seed[18]
static var vignette: float = lerpf(0.5, 0.95, amount(19))  # seed[19]
static var wall: int = pick(20, 3)  # seed[20]
static var ornament: int = pick(21, 3)  # seed[21]
static var blood: Color = Color(0.78, 0.02, 0.03).lerp(Color(0.52, 0.0, 0.02), amount(22))  # seed[22]
static var paper_tone: float = lerpf(0.86, 0.98, amount(23))  # seed[23]
static var floor_tone: float = lerpf(0.72, 0.88, amount(24))  # seed[24]
static var zoom: float = lerpf(1.5, 2.0, amount(25))  # seed[25]


static func value(i: int) -> int:
	return ALPHABET.find(SEED[i])


static func amount(i: int) -> float:
	return value(i) / 63.0


static func pick(i: int, count: int) -> int:
	return value(i) % count
