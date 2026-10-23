class_name TWSave
extends RefCounted
## Guarda y recupera el estado completo de una partida (TWGame) como Dictionary listo para JSON.
## Las casillas se guardan como [x, y]; los enteros se vuelven a convertir al cargar (JSON los da como float).

const VERSION := 1


static func _c(p) -> Variant:
	return null if p == null else [p.x, p.y]


static func _p(a) -> Variant:
	return null if a == null else Vector2i(int(a[0]), int(a[1]))


static func to_dict(g: TWGame) -> Dictionary:
	var units := []
	for u in g.units.values():
		units.append({"id": u.id, "side": u.side, "t": u.t, "hp": u.hp, "pos": _c(u.pos), "veteran": u.veteran,
			"crew": u.crew, "acted": u.acted, "moved": u.moved, "barricades": u.barricades, "carrier": u.carrier,
			"home": u.home, "char_id": u.char_id, "training": u.training, "stun": u.stun})
	var terrain := []
	for p in g.terrain:
		terrain.append([p.x, p.y, g.terrain[p]])
	var owner := []
	for p in g.owner:
		owner.append([p.x, p.y, g.owner[p]])
	var capture := []
	for p in g.capture:
		capture.append([p.x, p.y, g.capture[p]])
	var orders := []
	for p in g.orders:
		orders.append([p.x, p.y, g.orders[p]])
	var turrets := []
	for q in g.turrets:
		turrets.append([q.x, q.y, g.turrets[q]])
	return {
		"version": VERSION, "map": g.map_name, "terrain": terrain, "units": units, "next_id": g.next_id,
		"owner": owner, "hq": [_c(g.hq[0]), _c(g.hq[1])], "capture": capture, "supplies": g.supplies,
		"dom_streak": g.dom_streak, "saved_pm": g.saved_pm, "orders": orders, "allowed": [g.allowed[0], g.allowed[1]],
		"first": g.first, "current": g.current, "round": g.round, "turn": g.turn, "pm": g.pm, "winner": g.winner,
		"how": g.how, "destroyed": g.destroyed, "turrets": turrets, "decks": [g.decks[0], g.decks[1]],
		"card_ready": [g.card_ready[0], g.card_ready[1]],
	}


static func _ints(a: Array) -> Array:
	var out := []
	for x in a:
		out.append(int(x))
	return out


static func from_dict(d: Dictionary) -> TWGame:
	var g := TWGame.new(d.map, int(d.first), d.allowed, d.decks)
	g.terrain = {}
	for e in d.terrain:
		g.terrain[Vector2i(int(e[0]), int(e[1]))] = e[2]
	g.units = {}
	g.occ = {}
	for e in d.units:
		var u := TWUnit.new(int(e.id), int(e.side), e.t, _p(e.pos), int(e.hp))
		u.veteran = e.veteran
		u.crew = int(e.crew)
		u.acted = e.acted
		u.moved = e.moved
		u.barricades = int(e.barricades)
		u.carrier = int(e.carrier)
		u.home = int(e.home)
		u.char_id = int(e.char_id)
		u.training = null if e.training == null else [e.training[0], int(e.training[1])]
		u.stun = int(e.stun)
		g.units[u.id] = u
		if u.pos != null:
			g.occ[u.pos] = u.id
	g.next_id = int(d.next_id)
	g.owner = {}
	for e in d.owner:
		g.owner[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	g.hq = {0: _p(d.hq[0]), 1: _p(d.hq[1])}
	g.capture = {}
	for e in d.capture:
		g.capture[Vector2i(int(e[0]), int(e[1]))] = _ints(e[2])
	g.supplies = _ints(d.supplies)
	g.dom_streak = _ints(d.dom_streak)
	g.saved_pm = _ints(d.saved_pm)
	g.orders = {}
	for e in d.orders:
		g.orders[Vector2i(int(e[0]), int(e[1]))] = [int(e[2][0]), e[2][1], int(e[2][2])]
	g.current = int(d.current)
	g.round = int(d.round)
	g.turn = int(d.turn)
	g.pm = int(d.pm)
	g.winner = int(d.winner)
	g.how = d.how
	g.destroyed = _ints(d.destroyed)
	g.turrets = {}
	for e in d.turrets:
		var t: Dictionary = e[2]
		g.turrets[Vector2i(int(e[0]), int(e[1]))] = {"hp": int(t.hp), "max": int(t.max), "lo": int(t.lo),
			"hi": int(t.hi), "dmg": int(t.dmg), "armor": int(t.armor), "owner": int(t.owner), "off": int(t.off),
			"kind": t.kind, "base": t.base}
	for s in [0, 1]:
		g.card_ready[s] = {}
		for c in d.card_ready[s]:
			g.card_ready[s][c] = int(d.card_ready[s][c])
	return g
