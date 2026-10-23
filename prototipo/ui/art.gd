extends RefCounted
## Texturas del arte (assets/arte, preparado con arte/preparar_arte.py). Se cargan una vez y se guardan.

const DIR := "res://assets/arte/"
const SIDE := ["jade", "ambar"]
const UNIT_FILE := {"F": "fusilero", "A": "antitanque", "I": "ingeniero", "K": "hacker", "P": "tripulacion",
	"C": "personaje", "J": "jeep", "T": "tanque", "R": "artilleria"}
const TURRET_FILE := {"plaza": "plaza", "torreta": "terrestre", "misiles": "misiles"}

static var cache := {}


static func tex(path: String) -> Texture2D:
	if not cache.has(path):
		var full := DIR + path + ".png"
		cache[path] = load(full) if ResourceLoader.exists(full) else null
	return cache[path]


static func side_name(owner: int) -> String:
	return "neutral" if owner < 0 else SIDE[owner]


static func unit(t: String, side: int) -> Texture2D:
	return tex("unidades/%s_%s" % [SIDE[side], UNIT_FILE[t]])


static func card(c: String) -> Texture2D:
	return tex("cartas/" + c)
