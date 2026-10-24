## Sound direction decoded from divine_inspiration("snake-sounds"), the same way Art decodes the art seed:
## every parameter comes from one character of the seed (its index in the 64-symbol alphabet A-Z a-z 0-9
## - _), scaled into a range that fits spec §10. The seed position is cited on every line.
class_name SoundDirection
extends RefCounted

const TOPIC := "snake-sounds"
const SEED := "jic9VjkaU9T1N00rNBTCvVWiO7b1m-BfhZZQSq1CdU7rTRiAycgoHOdiSr1IUOe7"
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

enum Mode { HARMONIC_MINOR, PHRYGIAN, NATURAL_MINOR }
enum Piano { TOY, HONKY_TONK, MUSIC_BOX }

const MODE_STEPS := [[0, 2, 3, 5, 7, 8, 11], [0, 1, 3, 5, 7, 8, 10], [0, 2, 3, 5, 7, 8, 10]]

static var rag_bpm: float = lerpf(150.0, 200.0, amount(0))  # seed[0], in-game ragtime tempo
static var waltz_bpm: float = lerpf(84.0, 120.0, amount(1))  # seed[1], menu waltz tempo
static var root: int = pick(2, 12)  # seed[2], key: semitones above A
static var detune: float = lerpf(4.0, 30.0, amount(3))  # seed[3], cents the piano strings are out of tune
static var piano: int = pick(4, 3)  # seed[4]
static var crackle: float = lerpf(0.01, 0.05, amount(5))  # seed[5], gramophone crackle level
static var swing: float = lerpf(0.0, 0.3, amount(6))  # seed[6], how late off-beat notes come
static var gulp_hz: float = lerpf(80.0, 160.0, amount(7))  # seed[7], where the gulp slides down to
static var squawk_hz: float = lerpf(700.0, 1400.0, amount(8))  # seed[8], chicken squawk pitch
static var crunch_hz: float = lerpf(1500.0, 5000.0, amount(9))  # seed[9], bone crunch brightness
static var echo: float = lerpf(0.0, 0.35, amount(10))  # seed[10], room echo on music and stingers
static var mode: int = pick(11, 3)  # seed[11]
static var vibrato: float = lerpf(0.005, 0.03, amount(12))  # seed[12], wobble on the trombone and whistles
static var melody_seed: int = value(13) * 64 + value(14)  # seed[13..14], drives the melody's random walk


static func value(i: int) -> int:
	return ALPHABET.find(SEED[i])


static func amount(i: int) -> float:
	return value(i) / 63.0


static func pick(i: int, count: int) -> int:
	return value(i) % count


## Frequency of a scale degree in the seed's key and mode (degree 0 = root at A3 + root, may be negative).
static func degree_hz(degree: int, octave := 0) -> float:
	var steps: Array = MODE_STEPS[mode]
	var n := posmod(degree, 7)
	var oct := octave + floori(degree / 7.0)
	var semis: int = root + steps[n] + oct * 12
	return 220.0 * pow(2.0, semis / 12.0)
