class_name TWSetup
extends RefCounted
## Creación de partidas: despliegue automático en la zona de cada jugador (C3.3).

const R = preload("res://core/tw_rules.gd")
const ORDER := {"T": 0, "J": 1, "F": 2, "A": 3, "I": 4, "K": 4, "R": 5}


static func deployment_zone(g: TWGame, side: int) -> Array:
	var srcs := []
	for p in g.owner:
		if g.owner[p] == side and (g.terrain[p] == "H" or g.terrain[p] == "Q"):
			srcs.append(p)
	var zone := []
	for p in g.terrain:
		if not g.passable(p, 0):
			continue
		for s in srcs:
			if R.dist(p, s) <= 3:
				zone.append(p)
				break
	return zone


## Elige casilla para las unidades indicadas (índices de army): lo más adelantadas posible dentro de la zona,
## la artillería algo más atrás, sin ocupar el CG ni las casillas ya ocupadas. Devuelve índice -> casilla,
## en el orden en que se colocan.
static func auto_cells(g: TWGame, side: int, army: Array, indices: Array) -> Dictionary:
	var zone := deployment_zone(g, side)
	var enemy_hq: Vector2i = g.hq[1 - side]
	var items := indices.duplicate()
	items.sort_custom(func(i, j):
		var a: String = army[i]
		var b: String = army[j]
		return ORDER[a[0]] < ORDER[b[0]] or (ORDER[a[0]] == ORDER[b[0]] and (a < b or (a == b and i < j))))
	var taken := g.occ.duplicate()
	var out := {}
	for i in items:
		var t: String = army[i][0]
		var k: int = R.UNIT[t][1]
		var extra := 2 if t == "R" else 0
		var best = null
		var best_score := 999
		for p in zone:
			if taken.has(p) or not g.passable(p, k) or g.terrain[p] == "H":
				continue
			var sc := R.dist(p, enemy_hq) + extra
			if best == null or sc < best_score or (sc == best_score and R.pos_less(p, best)):
				best = p
				best_score = sc
		if best != null:
			out[i] = best
			taken[best] = -1
	return out


## C3.3: una unidad puede empezar en una casilla vacía de la zona por la que pueda moverse.
static func can_deploy(g: TWGame, side: int, t: String, p: Vector2i, zone: Array) -> bool:
	return zone.has(p) and not g.occ.has(p) and g.passable(p, R.UNIT[t][1])


## Pone una unidad del ejército en el tablero («T*»: el equipo que lleva al personaje).
static func place(g: TWGame, side: int, item: String, p: Vector2i) -> TWUnit:
	var v := g.add_unit(side, item[0], p)
	if item.ends_with("*"):
		g.add_char(v)
	return v


## Despliegue automático completo.
static func deploy(g: TWGame, side: int, army: Array) -> void:
	var cells := auto_cells(g, side, army, range(army.size()))
	for i in cells:
		place(g, side, army[i], cells[i])


static func allowed_of(army: Array) -> Array:
	var out := []
	for item in army:
		var t: String = item[0]
		if not out.has(t):
			out.append(t)
	return out


static func new_game(army0: String, army1: String, deck0: Array, deck1: Array, first := 0) -> TWGame:
	var a0: Array = R.ARMIES[army0]
	var a1: Array = R.ARMIES[army1]
	var g := TWGame.new("Cuatro plazas", first, [allowed_of(a0), allowed_of(a1)], [deck0, deck1])
	deploy(g, 0, a0)
	deploy(g, 1, a1)
	g.start_turn()
	return g


## Partida a partir de lo elegido en la pantalla de preparación: ejércitos, cartas y casilla de cada unidad.
static func build(armies: Array, decks: Array, cells: Array, first: int) -> TWGame:
	var g := TWGame.new("Cuatro plazas", first, [allowed_of(armies[0]), allowed_of(armies[1])], decks)
	for s in [0, 1]:
		for i in range(armies[s].size()):
			place(g, s, armies[s][i], cells[s][i])
	g.start_turn()
	return g


## Ejército y cartas al azar (para la IA).
static func random_army() -> Array:
	var keys := R.ARMIES.keys()
	return R.ARMIES[keys[randi() % keys.size()]].duplicate()


static func random_deck() -> Array:
	var cards := R.CARDS.keys()
	cards.shuffle()
	var deck := cards.slice(0, 3)
	deck.sort()
	return deck
