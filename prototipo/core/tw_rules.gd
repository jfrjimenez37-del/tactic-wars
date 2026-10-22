class_name TWRules
extends RefCounted
## Datos de las reglas vigentes de la capa 0 (Reglamento capa 0 v2, 22-10-2026).
## Mismas cifras que la configuración «REGLAS_ACTUALES» del simulador en Python.

const W := 12
const H := 8
const COLS := "ABCDEFGHIJKL"
const ROUNDS := 20

# Mitad inferior (filas 1-4) de cada mapa; la superior se obtiene por rotación de 180° (C1.4).
# . llano  = carretera  B bosque  C colina  ~ río  P puente  # muro  r ruinas  X barricada  O torreta de carta
# H cuartel general  Q cuartel  U ciudad
const MAPS := {
	"Cuatro plazas": ["..U..B..C...", ".Q=...U.B...", "..=.#..=~~..", "H===r.U.~P.."],
}

# C2: coste de movimiento por clase (0 a pie, 1 ruedas, 2 orugas); -1 = intransitable
const MOVE_COST := {
	".": [1, 2, 1], "=": [1, 1, 1], "B": [1, 3, 2], "C": [2, 3, 2], "~": [2, -1, -1],
	"P": [1, 1, 1], "#": [-1, -1, -1], "X": [-1, -1, -1], "r": [1, 1, 1],
	"H": [1, 1, 1], "Q": [1, 1, 1], "U": [1, 1, 1], "O": [-1, -1, -1],
}
const COVER := "BrHQU"
const BUILDINGS := "HQU"

# Sec. 2.1: tipo -> [clase objetivo, clase de movimiento, PV, Mov, PM, alcance mín, alcance máx, coste, turnos]
# «turnos» es el tiempo base; la fabricación real es base + 1 (C11).
const UNIT := {
	"F": ["pie", 0, 3, 3, 1, 1, 1, 2, 1],
	"A": ["pie", 0, 3, 2, 1, 1, 1, 2, 1],
	"I": ["pie", 0, 3, 2, 1, 1, 1, 2, 1],
	"P": ["pie", 0, 2, 2, 1, 1, 1, 0, 0],
	"J": ["lig", 1, 4, 6, 1, 1, 1, 3, 1],
	"T": ["bli", 2, 8, 4, 2, 1, 1, 6, 2],
	"R": ["lig", 1, 5, 4, 2, 2, 3, 5, 2],
	"K": ["pie", 0, 2, 2, 1, 1, 1, 3, 1],
	"C": ["pie", 0, 4, 3, 1, 1, 1, 0, 0],
}
const NAMES := {"F": "Fusilero", "A": "Antitanque", "I": "Ingeniero", "P": "Tripulación", "J": "Jeep",
	"T": "Tanque medio", "R": "Artillería", "C": "Personaje", "K": "Hacker"}
const VEHICLES := "JTR"
const FOOT := "FAIPCK"

# Sec. 2.2: daño base por clase de objetivo (con el reequilibrio S1)
const DAMAGE := {
	"F": {"pie": 2, "lig": 1, "bli": 0}, "A": {"pie": 1, "lig": 3, "bli": 4}, "I": {"pie": 1, "lig": 0, "bli": 0},
	"P": {"pie": 1, "lig": 0, "bli": 0}, "J": {"pie": 2, "lig": 1, "bli": 0}, "T": {"pie": 2, "lig": 4, "bli": 3},
	"R": {"pie": 4, "lig": 3, "bli": 3}, "C": {"pie": 2, "lig": 1, "bli": 0}, "K": {"pie": 1, "lig": 0, "bli": 0},
}

const BUILD_EXTRA := 1          # C11: +1 turno a la fabricación de todo
const SUPPLIES_START := 2       # C3.4
const INCOME_BASE := 1          # C4.2
const INCOME_CITY := 1
const CITY_FIRST := 5           # C10.3: conquista de una ciudad neutral
const CITY_RETAKE := 2          # C10.3: conquista de una ciudad del rival
const SUPPLY_CAP := 30
const PM_SCHEDULE := [[1, 5, 1], [8, 6, 2], [14, 7, 3]]   # [ronda, PM, máximo guardado]
const CAPS := {"veh": 6, "foot": 4, "crew": 6}             # C11.5
const DOMINATION := 7           # C12.2
const CHAR_EJECT_HP := 2
const CHAR_BOUNTY := 3
const HACK_RANGE := 2
const HACK_PM := 2

# C14 y C15: torretas
const TURRETS := {
	"plaza": {"hp": 6, "lo": 0, "hi": 2, "dmg": 2, "armor": 1},
	"torreta": {"hp": 6, "lo": 1, "hi": 2, "dmg": 2, "armor": 0},
	"misiles": {"hp": 5, "lo": 2, "hi": 4, "dmg": 3, "armor": 0},
}
const PLAZA_REGEN := 1

# C15: carta -> [PM, recarga en rondas, desde la ronda]
const CARDS := {
	"marcha": [1, 4, 1], "reparacion": [1, 4, 1], "pem": [1, 6, 4], "torreta": [2, 6, 3],
	"refuerzo": [2, 6, 3], "hackeo": [2, 6, 3], "aereo": [3, 8, 4], "misiles": [3, 6, 5],
	"saturacion": [3, 8, 5], "paracaidistas": [3, 8, 5],
}
const CARD_NAMES := {"marcha": "Orden de marcha", "reparacion": "Reparación de campo", "pem": "PEM",
	"torreta": "Torreta terrestre", "refuerzo": "Refuerzo de emergencia", "hackeo": "Hackeo de red",
	"aereo": "Ataque aéreo", "misiles": "Torreta lanzamisiles", "saturacion": "Bombardeo de saturación",
	"paracaidistas": "Paracaidistas"}

# Ejércitos de prueba (4 equipos + 2 tropas a pie; «T*» = equipo que lleva al personaje)
const ARMIES := {
	"equilibrado4": ["T*", "T", "R", "J", "F", "A"],
	"blindado4": ["T*", "T", "T", "R", "F", "A"],
	"artilleria4": ["T*", "R", "R", "J", "F", "A"],
	"rapido4": ["T*", "J", "J", "J", "F", "F"],
	"infanteria4": ["T*", "T", "R", "J", "F", "I"],
	"ingenieros4": ["T*", "T", "R", "J", "I", "I"],
	"hacker4": ["T*", "T", "R", "J", "F", "K"],
}


static func cell_name(p) -> String:
	if p == null:
		return "-"
	return "%s%d" % [COLS[p.x], p.y]


static func cell(name: String) -> Vector2i:
	return Vector2i(COLS.find(name[0]), int(name.substr(1)))


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func neighbors(p: Vector2i) -> Array:
	var out := []
	for q in [Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y), Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1)]:
		if q.x >= 0 and q.x < W and q.y >= 1 and q.y <= H:
			out.append(q)
	return out


static func pos_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func sorted_cells(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort_custom(pos_less)
	return out


static func build_terrain(map_name: String) -> Dictionary:
	var bottom: Array = MAPS[map_name]
	var rows := {}
	for r in range(4):
		rows[r + 1] = bottom[r]
		rows[8 - r] = (bottom[r] as String).reverse()
	var terrain := {}
	for r in range(1, 9):
		for c in range(12):
			terrain[Vector2i(c, r)] = (rows[r] as String)[c]
	return terrain
