class_name TWGame
extends RefCounted
## Motor de reglas de la capa 0 (C1-C15). Traducción directa de tw_sim/rules.py.
## Determinista: el mismo estado y la misma acción dan siempre el mismo resultado.
## Una acción es un Dictionary {kind, unit, dest, sub, target}:
##   kind: "activate" | "dismount" | "produce" | "card" | "end"
##   unit: id o -1; dest: Vector2i o null; sub: String; target: id (int), Vector2i, tipo (String) o null.

const R = preload("res://core/tw_rules.gd")
const CELL_SUBS := ["struct", "barricade", "attack_turret", "sabotage", "repair_turret"]
const NO_WINNER := -9

var map_name: String
var terrain := {}            # Vector2i -> carácter
var units := {}              # id -> TWUnit (en orden de id)
var occ := {}                # Vector2i -> id
var next_id := 0
var owner := {}              # edificio -> bando (-1 neutral)
var hq := {}                 # bando -> Vector2i
var capture := {}            # casilla -> [bando, id unidad, puntos]
var supplies := [R.SUPPLIES_START, R.SUPPLIES_START]
var dom_streak := [0, 0]
var saved_pm := [0, 0]
var orders := {}             # edificio -> [bando, tipo, turno global en que sale]
var allowed := {0: [], 1: []}
var first := 0
var current := 0
var round := 1
var turn := 0
var pm := 0
var winner := NO_WINNER
var how := ""
var destroyed := [0, 0]
var turrets := {}            # casilla -> {hp, max, lo, hi, dmg, armor, owner, off, kind, base}
var decks := {0: [], 1: []}
var card_ready := {0: {}, 1: {}}
var log := []
var events := []             # sucesos para la interfaz: [tipo, datos...]


func _init(p_map: String, p_first: int, p_allowed: Array, p_decks: Array) -> void:
	map_name = p_map
	terrain = R.build_terrain(p_map)
	for p in terrain:
		if R.BUILDINGS.contains(terrain[p]):
			owner[p] = -1
	var hqs := []
	for p in terrain:
		if terrain[p] == "H":
			hqs.append(p)
	hqs = R.sorted_cells(hqs)
	hq = {0: hqs[0], 1: hqs[1]}
	for p in terrain:
		if terrain[p] == "H" or terrain[p] == "Q":
			owner[p] = 0 if p.x < 6 else 1
	first = p_first
	current = p_first
	for s in [0, 1]:
		allowed[s] = []
		for t in p_allowed[s]:
			if t != "C" and not allowed[s].has(t):
				allowed[s].append(t)
		allowed[s].sort()
		decks[s] = p_decks[s].duplicate()
		card_ready[s] = {}
		for c in decks[s]:
			card_ready[s][c] = 0
	for p in terrain:
		if terrain[p] == "U" and R.dist(p, hq[0]) == R.dist(p, hq[1]):
			var cfg: Dictionary = R.TURRETS["plaza"]
			turrets[p] = {"hp": cfg.hp, "max": cfg.hp, "lo": cfg.lo, "hi": cfg.hi, "dmg": cfg.dmg,
				"armor": cfg.armor, "owner": -1, "off": -1, "kind": "plaza", "base": "U"}


# ------------------------------------------------------------------ unidades
func add_unit(side: int, t: String, pos, with_crew := true) -> TWUnit:
	next_id += 1
	var u := TWUnit.new(next_id, side, t, pos)
	units[u.id] = u
	if pos != null:
		assert(not occ.has(pos), "casilla ocupada")
		occ[pos] = u.id
	if R.VEHICLES.contains(t) and with_crew:
		next_id += 1
		var c := TWUnit.new(next_id, side, "P", null)
		c.carrier = u.id
		c.home = u.id
		units[c.id] = c
		u.crew = c.id
	return u


func add_char(v: TWUnit) -> TWUnit:
	next_id += 1
	var c := TWUnit.new(next_id, v.side, "C", null)
	c.carrier = v.id
	units[c.id] = c
	v.char_id = c.id
	return c


func category_of(t: String) -> String:
	if R.VEHICLES.contains(t):
		return "veh"
	if t == "P":
		return "crew"
	if t == "C":
		return "char"
	return "foot"


func unit_category(u: TWUnit) -> String:
	return category_of(u.training[0] if u.training != null else u.t)


func count(side: int, cat: String) -> int:
	var n := 0
	for u in units.values():
		if u.side == side and unit_category(u) == cat:
			n += 1
	for p in orders:
		if orders[p][0] == side and category_of(orders[p][1]) == cat:
			n += 1
	return n


func room(side: int, t: String) -> bool:
	var cat := category_of(t)
	return not R.CAPS.has(cat) or count(side, cat) < R.CAPS[cat]


func cost(t: String) -> int:
	return R.UNIT[t][7]


func worth(t: String) -> int:
	if t == "P":
		return 1
	if t == "C":
		return 4
	return cost(t)


func on_board(side := -1) -> Array:
	var out := []
	for u in units.values():
		if u.pos != null and (side < 0 or u.side == side):
			out.append(u)
	return out


func is_vehicle(u: TWUnit) -> bool:
	return R.VEHICLES.contains(u.t)


func activatable(side: int) -> Array:
	var out := []
	for u in on_board(side):
		if (not is_vehicle(u) or u.crew >= 0 or u.char_id >= 0) and u.training == null:
			out.append(u)
	return out


func at(p):
	if occ.has(p):
		return units[occ[p]]
	return null


func _drop_capture_of(uid: int) -> void:
	for p in capture.keys():
		if capture[p][1] == uid:
			capture.erase(p)


func _remove(u: TWUnit) -> void:
	if u.pos != null:
		occ.erase(u.pos)
	units.erase(u.id)
	_drop_capture_of(u.id)


# ------------------------------------------------------------------ movimiento (C6)
func move_cost(p: Vector2i, mclass: int) -> int:
	return R.MOVE_COST[terrain[p]][mclass]


func passable(p: Vector2i, mclass: int) -> bool:
	return move_cost(p, mclass) >= 0


static func _pop_min(pq: Array) -> Array:
	var bi := 0
	for i in range(1, pq.size()):
		var a: Array = pq[i]
		var b: Array = pq[bi]
		if a[0] < b[0] or (a[0] == b[0] and R.pos_less(a[1], b[1])):
			bi = i
	var item: Array = pq[bi]
	pq.remove_at(bi)
	return item


## Casillas finales alcanzables -> coste. Incluye la casilla actual (mover 0).
func reach(u: TWUnit) -> Dictionary:
	var k: int = R.UNIT[u.t][1]
	var mov: int = R.UNIT[u.t][3]
	var best := {u.pos: 0}
	var ends := {u.pos: 0}
	var pq := [[0, u.pos]]
	while pq.size() > 0:
		var item := _pop_min(pq)
		var d: int = item[0]
		var p: Vector2i = item[1]
		if d > best[p]:
			continue
		if p != u.pos and terrain[p] == "r":       # C6.3
			continue
		for q in R.neighbors(p):
			var c := move_cost(q, k)
			if c < 0 or d + c > mov:
				continue
			var other = at(q)
			if other != null and other.side != u.side:  # C6.2
				continue
			if terrain[q] == "r" and other != null:
				continue
			if d + c < best.get(q, 99):
				best[q] = d + c
				pq.append([d + c, q])
				if other == null:
					ends[q] = d + c
	return ends


func distances(sources: Array, mclass: int) -> Dictionary:
	var d := {}
	var pq := []
	for s in sources:
		d[s] = 0
		pq.append([0, s])
	while pq.size() > 0:
		var item := _pop_min(pq)
		var x: int = item[0]
		var p: Vector2i = item[1]
		if x > d[p]:
			continue
		for q in R.neighbors(p):
			var c := move_cost(q, mclass)
			if c >= 0 and x + c < d.get(q, 999):
				d[q] = x + c
				pq.append([x + c, q])
	return d


## C9.5: ¿queda camino para orugas entre los dos cuarteles generales?
func tracks_connected(overrides: Dictionary) -> bool:
	var saved := {}
	for p in overrides:
		saved[p] = terrain[p]
		terrain[p] = overrides[p]
	var ok := distances([hq[0]], 2).has(hq[1])
	for p in saved:
		terrain[p] = saved[p]
	return ok


# ------------------------------------------------------------------ combate (C7)
func damage(att: TWUnit, dfn: TWUnit, counter := false) -> int:
	var base: int = R.DAMAGE[att.t][R.UNIT[dfn.t][0]]
	if counter:
		base -= 1
	if base <= 0:
		return 0
	var cover: bool = R.UNIT[dfn.t][0] == "pie" and R.COVER.contains(terrain[dfn.pos])
	return maxi(1, base + (1 if att.veteran or att.char_id >= 0 else 0) - (1 if cover else 0))


func can_attack(att: TWUnit, dfn: TWUnit, from_pos: Vector2i) -> bool:
	if dfn.side == att.side or R.DAMAGE[att.t][R.UNIT[dfn.t][0]] <= 0:
		return false
	var lo: int = R.UNIT[att.t][5]
	var hi: int = R.UNIT[att.t][6]
	if att.t == "R":
		if from_pos != att.pos or att.moved:
			return false
		if terrain[att.pos] == "C":
			hi += 1
	var dd := R.dist(from_pos, dfn.pos)
	return lo <= dd and dd <= hi


func _hit(att: TWUnit, dfn: TWUnit) -> void:
	var d := damage(att, dfn)
	dfn.hp -= d
	events.append(["hit", att.id, dfn.id, d])
	if dfn.hp <= 0:
		_kill(dfn, att)
		return
	if att.t != "R" and dfn.t != "R" and R.dist(att.pos, dfn.pos) == 1:   # C7.4
		var c := damage(dfn, att, true)
		if c > 0:
			att.hp -= c
			events.append(["hit", dfn.id, att.id, c])
			if att.hp <= 0:
				_kill(att, dfn)


func _kill(u: TWUnit, killer: TWUnit, credit := -1) -> void:
	if killer != null:
		killer.veteran = true
		credit = killer.side
	if credit >= 0 and credit != u.side:
		destroyed[credit] += worth(u.t)
	var pos = u.pos
	var side := u.side
	var riders := []
	if is_vehicle(u):
		for i in [u.crew, u.char_id]:
			if i >= 0:
				riders.append(units[i])
	_remove(u)
	events.append(["kill", u.id, u.t, pos])
	if u.t == "C":
		_char_died(side)
	for crew in riders:                                # C8.5 y A8
		var free := []
		for q in R.neighbors(pos):
			if not occ.has(q) and passable(q, 0):
				free.append(q)
		if free.size() > 0:
			var enemies := on_board(1 - side)
			var best_q = null
			var best_d := -1
			for q in free:
				var md := 99
				if enemies.size() > 0:
					md = 999
					for e in enemies:
						md = mini(md, R.dist(q, e.pos))
				if best_q == null or md > best_d or (md == best_d and R.pos_less(best_q, q)):
					best_q = q
					best_d = md
			crew.carrier = -1
			crew.pos = best_q
			crew.hp = R.CHAR_EJECT_HP if crew.t == "C" else 1
			crew.acted = true
			occ[best_q] = crew.id
			events.append(["eject", crew.id, best_q])
		else:
			units.erase(crew.id)
			if credit >= 0 and credit != side:
				destroyed[credit] += worth(crew.t)
			if crew.t == "C":
				_char_died(side)
	_check_elimination()


func _char_died(side: int) -> void:
	supplies[1 - side] = mini(R.SUPPLY_CAP, supplies[1 - side] + R.CHAR_BOUNTY)


func _check_elimination() -> void:                  # C12.3 y A3
	for s in [0, 1]:
		if winner == NO_WINNER and activatable(s).is_empty():
			_finish(1 - s, "eliminacion")


func _finish(w: int, h: String) -> void:
	if winner == NO_WINNER:
		winner = w
		how = h


# ------------------------------------------------------------------ objetivos posibles
func attack_targets(u: TWUnit, from_pos: Vector2i) -> Array:
	var out := []
	for e in on_board(1 - u.side):
		if can_attack(u, e, from_pos):
			out.append(e)
	return out


func struct_targets(u: TWUnit, from_pos: Vector2i) -> Array:
	var out := []
	if u.t == "T" or u.t == "A" or u.t == "I":         # C9.1 y C9.2
		for q in R.neighbors(from_pos):
			var ch: String = terrain[q]
			if (ch == "#" and u.t == "T") or ch == "X":
				out.append(q)
	if u.t == "R" and from_pos == u.pos and not u.moved:
		var hi := 3 + (1 if terrain[u.pos] == "C" else 0)
		for q in terrain:
			var ch: String = terrain[q]
			var dd := R.dist(q, u.pos)
			if dd >= 2 and dd <= hi and (ch == "#" or ch == "X" or (ch == "P" and not occ.has(q))):
				if ch == "P" and not tracks_connected({q: "~"}):
					continue
				out.append(q)
	return out


func barricade_cells(u: TWUnit, from_pos: Vector2i) -> Array:   # C9.4
	if u.t != "I" or u.barricades <= 0:
		return []
	var out := []
	for q in R.neighbors(from_pos):
		if occ.has(q) or not (terrain[q] == "." or terrain[q] == "="):
			continue
		if tracks_connected({q: "X"}):
			out.append(q)
	return out


func can_capture(u: TWUnit, p: Vector2i) -> bool:          # C10.1 y A5
	return R.FOOT.contains(u.t) and owner.has(p) and owner[p] != u.side


func repair_targets(u: TWUnit, p: Vector2i) -> Array:      # C8.6
	var out := []
	for q in R.neighbors(p):
		var v = at(q)
		if v == null or v.side != u.side or not is_vehicle(v) or v.hp >= R.UNIT[v.t][2]:
			continue
		if u.t == "I" or (u.t == "P" and u.home == v.id):
			out.append(v.id)
	return out


func hack_targets(u: TWUnit, p: Vector2i) -> Array:        # C8.10
	if u.t != "K" or not room(u.side, "T"):
		return []
	var out := []
	for v in on_board(1 - u.side):
		if is_vehicle(v) and v.crew < 0 and v.char_id < 0 and R.dist(p, v.pos) <= R.HACK_RANGE:
			out.append(v.id)
	return out


func train_types(u: TWUnit, p: Vector2i) -> Array:         # C8.9
	if u.t != "P" or owner.get(p, -2) != u.side or not (terrain[p] == "H" or terrain[p] == "Q"):
		return []
	var out := []
	for t in allowed[u.side]:
		if "FAIK".contains(t) and supplies[u.side] >= cost(t) and room(u.side, t):
			out.append(t)
	return out


func board_targets(u: TWUnit, p: Vector2i) -> Array:       # C8.4
	if not R.FOOT.contains(u.t):
		return []
	var out := []
	for q in R.neighbors(p):
		if not occ.has(q):
			continue
		var v: TWUnit = units[occ[q]]
		if v.side != u.side or not is_vehicle(v):
			continue
		if (u.t == "C" and v.char_id < 0) or (u.t != "C" and v.crew < 0):
			out.append(v.id)
	return out


func turret_targets(u: TWUnit, from_pos: Vector2i) -> Array:
	if R.DAMAGE[u.t]["bli"] <= 0:
		return []
	var lo: int = R.UNIT[u.t][5]
	var hi: int = R.UNIT[u.t][6]
	if u.t == "R":
		if from_pos != u.pos or u.moved:
			return []
		if terrain[u.pos] == "C":
			hi += 1
	var out := []
	for q in turrets:
		var t: Dictionary = turrets[q]
		var dd := R.dist(from_pos, q)
		if t.hp > 0 and t.owner != u.side and lo <= dd and dd <= hi:
			out.append(q)
	return out


func engineer_turret_actions(u: TWUnit, p: Vector2i) -> Array:   # C8.11
	if u.t != "I":
		return []
	var out := []
	for q in [p] + R.neighbors(p):
		if not turrets.has(q):
			continue
		var t: Dictionary = turrets[q]
		if t.hp > 0 and t.owner != u.side and t.off < turn + 1:
			out.append(["sabotage", q])
		elif t.owner == u.side and t.hp < t.max and (t.hp > 0 or t.kind == "plaza"):
			out.append(["repair_turret", q])
	return out


func turret_damage(u: TWUnit, q: Vector2i) -> int:
	return maxi(1, R.DAMAGE[u.t]["bli"] + (1 if u.veteran or u.char_id >= 0 else 0) - turrets[q].armor)


# ------------------------------------------------------------------ acciones legales
static func act(kind: String, unit := -1, dest = null, sub := "none", target = null) -> Dictionary:
	return {"kind": kind, "unit": unit, "dest": dest, "sub": sub, "target": target}


static func action_key(a: Dictionary) -> String:
	var tg = a.target
	var ts := "-"
	if tg is Vector2i:
		ts = R.cell_name(tg)
	elif tg != null:
		ts = str(tg)
	return "%s|%d|%s|%s|%s" % [a.kind, a.unit, R.cell_name(a.dest), a.sub, ts]


func legal_actions() -> Array:
	var s := current
	var acts := [act("end")]
	for u in on_board(s):
		if u.acted or u.training != null or u.stun == turn or (is_vehicle(u) and u.crew < 0 and u.char_id < 0):
			continue
		if R.UNIT[u.t][4] > pm:
			continue
		for e in reach(u):
			if e != u.pos:
				acts.append(act("activate", u.id, e))
			for en in attack_targets(u, e):
				acts.append(act("activate", u.id, e, "attack", en.id))
			if can_capture(u, e):
				acts.append(act("activate", u.id, e, "capture"))
			for v in repair_targets(u, e):
				acts.append(act("activate", u.id, e, "repair", v))
			for v in board_targets(u, e):
				acts.append(act("activate", u.id, e, "board", v))
			for q in struct_targets(u, e):
				acts.append(act("activate", u.id, e, "struct", q))
			for q in barricade_cells(u, e):
				acts.append(act("activate", u.id, e, "barricade", q))
			for t in train_types(u, e):
				acts.append(act("activate", u.id, e, "train", t))
			if pm >= R.HACK_PM:
				for v in hack_targets(u, e):
					acts.append(act("activate", u.id, e, "hack", v))
			for q in turret_targets(u, e):
				acts.append(act("activate", u.id, e, "attack_turret", q))
			for st in engineer_turret_actions(u, e):
				acts.append(act("activate", u.id, e, st[0], st[1]))
	for v in on_board(s):                         # C8.2: desembarcar, 0 PM
		if is_vehicle(v) and (v.crew >= 0 or v.char_id >= 0):
			for q in R.neighbors(v.pos):
				if not occ.has(q) and passable(q, 0):
					if v.crew >= 0:
						acts.append(act("dismount", v.id, q))
					if v.char_id >= 0:
						acts.append(act("dismount", v.id, q, "char"))
	if pm >= 1:                                   # C11
		for p in owner:
			if owner[p] != s or orders.has(p) or not (terrain[p] == "H" or terrain[p] == "Q"):
				continue
			for t in allowed[s]:
				if R.VEHICLES.contains(t) and terrain[p] == "H":
					continue
				if cost(t) <= supplies[s] and room(s, t):
					acts.append(act("produce", -1, p, "none", t))
	acts.append_array(card_actions())
	return acts


func is_legal(a: Dictionary) -> bool:
	var key := action_key(a)
	for b in legal_actions():
		if action_key(b) == key:
			return true
	return false


# ------------------------------------------------------------------ cartas (C15)
func card_available(c: String) -> bool:
	var d: Array = R.CARDS[c]
	return pm >= d[0] and round >= d[2] and card_ready[current].get(c, 99) <= turn


func area(center: Vector2i) -> Array:
	var out := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var q := Vector2i(center.x + dx, center.y + dy)
			if q.x >= 0 and q.x < R.W and q.y >= 1 and q.y <= R.H:
				out.append(q)
	return out


func card_actions() -> Array:
	var s := current
	var acts := []
	var enemies := on_board(1 - s)
	var mine_b := []
	for p in owner:
		if owner[p] == s:
			mine_b.append(p)
	for c in decks[s]:
		if not card_available(c):
			continue
		match c:
			"marcha":
				for u in on_board(s):
					if u.acted and u.stun != turn and (not is_vehicle(u) or u.crew >= 0 or u.char_id >= 0):
						for e in reach(u):
							if e != u.pos:
								acts.append(act("card", u.id, e, c))
			"reparacion":
				for v in on_board(s):
					if is_vehicle(v) and v.hp < R.UNIT[v.t][2]:
						acts.append(act("card", v.id, v.pos, c))
			"torreta", "misiles":
				var n := 0
				for q in turrets:
					if turrets[q].owner == s and turrets[q].kind != "plaza":
						n += 1
				if n >= 3:
					continue
				var cells := {}
				for p in mine_b:
					for q in R.neighbors(p):
						cells[q] = true
				for q in R.sorted_cells(cells.keys()):
					if not occ.has(q) and not turrets.has(q) and ".=Br".contains(terrain[q]) and tracks_connected({q: "O"}):
						acts.append(act("card", -1, q, c))
			"refuerzo":
				var h: Vector2i = hq[s]
				var spots := [h] + R.sorted_cells(R.neighbors(h))
				var any_free := false
				for q in spots:
					if not occ.has(q) and passable(q, 0):
						any_free = true
				if owner[h] == s and any_free:
					for t in allowed[s]:
						if "FAIK".contains(t) and room(s, t):
							acts.append(act("card", -1, h, c, t))
			"hackeo":
				for q in turrets:
					if turrets[q].hp > 0 and turrets[q].owner != s:
						acts.append(act("card", -1, q, c))
			"pem":
				var centers := {}
				for e in enemies:
					if is_vehicle(e):
						centers[e.pos] = true
				for q in turrets:
					if turrets[q].hp > 0 and turrets[q].owner != s:
						centers[q] = true
				for q in R.sorted_cells(centers.keys()):
					acts.append(act("card", -1, q, c))
			"aereo", "saturacion":
				var cs := {}
				for e in enemies:
					cs[e.pos] = true
				for q in R.sorted_cells(cs.keys()):
					acts.append(act("card", -1, q, c))
			"paracaidistas":
				if not room(s, "F"):
					continue
				var epos := {}
				for e in enemies:
					epos[e.pos] = true
				var cells := {}
				for p in owner:
					if owner[p] != s:
						cells[p] = true
						for q in R.neighbors(p):
							cells[q] = true
				for q in R.sorted_cells(cells.keys()):
					if occ.has(q) or turrets.has(q) or not passable(q, 0):
						continue
					var near := false
					for nq in R.neighbors(q):
						if epos.has(nq):
							near = true
					if not near:
						acts.append(act("card", -1, q, c))
	return acts


func _card_damage(u: TWUnit, d: int, s: int) -> void:
	u.hp -= d
	events.append(["hit", -1, u.id, d])
	if u.hp <= 0:
		_kill(u, null, s)


func _place_turret(q: Vector2i, kind: String, own: int) -> void:
	var cfg: Dictionary = R.TURRETS[kind]
	turrets[q] = {"hp": cfg.hp, "max": cfg.hp, "lo": cfg.lo, "hi": cfg.hi, "dmg": cfg.dmg, "armor": cfg.armor,
		"owner": own, "off": -1, "kind": kind, "base": terrain[q]}
	terrain[q] = "O"


func _apply_card(a: Dictionary, s: int) -> void:
	var c: String = a.sub
	var d: Array = R.CARDS[c]
	pm -= d[0]
	card_ready[s][c] = turn + 2 * d[1]
	events.append(["card", s, c, a.dest])
	match c:
		"marcha":
			var u: TWUnit = units[a.unit]
			_drop_capture_of(u.id)
			occ.erase(u.pos)
			u.pos = a.dest
			occ[a.dest] = u.id
		"reparacion":
			var v: TWUnit = units[a.unit]
			v.hp = mini(R.UNIT[v.t][2], v.hp + 3)
		"torreta", "misiles":
			_place_turret(a.dest, c, s)
		"refuerzo":
			var h: Vector2i = hq[s]
			for q in [h] + R.sorted_cells(R.neighbors(h)):
				if not occ.has(q) and passable(q, 0):
					var u := add_unit(s, a.target, q)
					u.acted = true
					break
		"hackeo":
			turrets[a.dest].off = turn + 2
		"pem":
			for q in area(a.dest):
				var e = at(q)
				if e != null and e.side != s:
					e.stun = turn + 1
				if turrets.has(q) and turrets[q].owner != s:
					turrets[q].off = turn + 2
		"aereo":
			for q in [a.dest] + R.neighbors(a.dest):
				var e = at(q)
				if e != null and e.side != s:
					_card_damage(e, 4 if q == a.dest else 2, s)
		"saturacion":
			for q in area(a.dest):
				var e = at(q)
				if e != null and e.side != s:
					_card_damage(e, 2, s)
		"paracaidistas":
			var u := add_unit(s, "F", a.dest)
			u.acted = true
	_check_elimination()


# ------------------------------------------------------------------ aplicar
func apply(a: Dictionary, check := true) -> void:
	if check and not is_legal(a):
		push_error("acción ilegal: " + action_key(a))
		assert(false, "acción ilegal: " + action_key(a))
	var s := current
	log.append(a)
	match a.kind:
		"end":
			end_turn()
			return
		"dismount":
			var v: TWUnit = units[a.unit]
			var c: TWUnit
			if a.sub == "char":
				c = units[v.char_id]
				v.char_id = -1
			else:
				c = units[v.crew]
				v.crew = -1
			c.carrier = -1
			c.pos = a.dest
			occ[a.dest] = c.id
			return
		"card":
			_apply_card(a, s)
			return
		"produce":
			var t: String = a.target
			pm -= 1
			supplies[s] -= cost(t)
			orders[a.dest] = [s, t, turn + 2 * (R.UNIT[t][8] + R.BUILD_EXTRA)]
			return
	var u: TWUnit = units[a.unit]
	pm -= R.HACK_PM if a.sub == "hack" else R.UNIT[u.t][4]
	u.acted = true
	if a.dest != u.pos:
		events.append(["move", u.id, u.pos, a.dest])
		_drop_capture_of(u.id)
		occ.erase(u.pos)
		u.pos = a.dest
		occ[a.dest] = u.id
		u.moved = true
	match a.sub:
		"attack":
			_hit(u, units[a.target])
		"capture":
			_capture(u)
		"repair":
			var v: TWUnit = units[a.target]
			v.hp = mini(R.UNIT[v.t][2], v.hp + (2 if u.t == "I" else 1))
		"board":
			var v: TWUnit = units[a.target]
			_drop_capture_of(u.id)
			occ.erase(u.pos)
			u.pos = null
			u.carrier = v.id
			if u.t == "C":
				v.char_id = u.id
			else:
				u.home = v.id
				v.crew = u.id
		"struct":
			_destroy(a.target)
		"attack_turret":
			var t: Dictionary = turrets[a.target]
			var d := turret_damage(u, a.target)
			t.hp = maxi(0, t.hp - d)
			events.append(["turret_hit", u.id, a.target, d])
			if t.hp == 0 and t.kind != "plaza":
				terrain[a.target] = t.base
				turrets.erase(a.target)
		"sabotage":
			turrets[a.target].off = turn + 2
		"repair_turret":
			var t: Dictionary = turrets[a.target]
			t.hp = 3 if t.hp == 0 else mini(t.max, t.hp + 2)
		"hack":
			var v: TWUnit = units[a.target]
			v.side = s
			v.acted = true
		"train":
			supplies[s] -= cost(a.target)
			u.training = [a.target, turn + 2]
		"barricade":
			terrain[a.target] = "X"
			u.barricades -= 1


func _capture(u: TWUnit) -> void:
	var p: Vector2i = u.pos
	var c = capture.get(p)
	if c == null or c[1] != u.id:
		c = [u.side, u.id, 0]
	c[2] += 2 if (u.t == "F" or u.t == "C") else 1    # el fusilero y el personaje capturan 2
	if c[2] >= 4:
		var prev: int = owner[p]
		owner[p] = u.side
		if turrets.has(p):
			turrets[p].owner = u.side
		if terrain[p] == "U":
			var bonus := R.CITY_FIRST if prev == -1 else R.CITY_RETAKE
			supplies[u.side] = mini(R.SUPPLY_CAP, supplies[u.side] + bonus)
		capture.erase(p)
		events.append(["capture", u.side, p])
		if orders.has(p) and orders[p][0] == prev:   # C11.4
			orders.erase(p)
		if terrain[p] == "H":                          # C12.1
			_finish(u.side, "captura_CG")
	else:
		capture[p] = c


func _destroy(q: Vector2i) -> void:
	match terrain[q]:
		"#":
			terrain[q] = "r"
		"X":
			terrain[q] = "."
		"P":
			terrain[q] = "~"


# ------------------------------------------------------------------ turnos (C4)
func pm_rule() -> Array:
	var p := 5
	var k := 1
	for row in R.PM_SCHEDULE:
		if round >= row[0]:
			p = row[1]
			k = row[2]
	return [p, k]


func start_turn() -> void:
	var s := current
	var income := R.INCOME_BASE
	for p in owner:
		if owner[p] == s and terrain[p] == "U":
			income += R.INCOME_CITY
	supplies[s] = mini(R.SUPPLY_CAP, supplies[s] + income)
	var mine := 0
	for p in owner:
		if owner[p] == s:
			mine += 1
	dom_streak[s] = dom_streak[s] + 1 if mine >= R.DOMINATION else 0
	if dom_streak[s] >= 2:
		_finish(s, "dominio")
	for p in owner:
		if owner[p] == s and terrain[p] == "U":
			var u = at(p)
			if u != null and u.side == s:
				u.hp = mini(R.UNIT[u.t][2], u.hp + 1)
	for q in turrets:
		var t: Dictionary = turrets[q]
		if t.kind == "plaza" and t.owner == s and t.hp > 0 and t.hp < t.max:
			t.hp = mini(t.max, t.hp + R.PLAZA_REGEN)
	for u in units.values():
		if u.side == s and u.training != null and u.training[1] <= turn:
			u.t = u.training[0]
			u.hp = R.UNIT[u.t][2]
			u.barricades = 2 if u.t == "I" else 0
			u.home = -1
			u.training = null
	for p in R.sorted_cells(orders.keys()):
		var o: Array = orders[p]
		if o[0] == s and o[2] <= turn:
			var spot = null
			if not occ.has(p):
				spot = p
			else:
				for q in R.sorted_cells(R.neighbors(p)):
					if not occ.has(q) and passable(q, R.UNIT[o[1]][1]):
						spot = q
						break
			if spot != null:
				var crewed := count(s, "crew") < R.CAPS["crew"]
				add_unit(s, o[1], spot, crewed)
				orders.erase(p)
	for u in units.values():
		if u.side == s:
			u.acted = false
			u.moved = false
	pm = pm_rule()[0] + saved_pm[s]
	saved_pm[s] = 0


func _turrets_fire(s: int) -> void:
	for q in R.sorted_cells(turrets.keys()):
		if not turrets.has(q):
			continue
		var t: Dictionary = turrets[q]
		if t.hp <= 0 or t.owner == s or turn <= t.off or winner != NO_WINNER:
			continue
		var best: TWUnit = null
		for u in on_board(s):
			var dd := R.dist(u.pos, q)
			if dd < t.lo or dd > t.hi:
				continue
			if best == null:
				best = u
				continue
			var db := R.dist(best.pos, q)
			if dd < db or (dd == db and (u.hp < best.hp or (u.hp == best.hp and u.id < best.id))):
				best = u
		if best == null:
			continue
		var cover: bool = R.UNIT[best.t][0] == "pie" and R.COVER.contains(terrain[best.pos])
		var d := maxi(1, t.dmg - (1 if cover else 0))
		best.hp -= d
		events.append(["turret_fire", q, best.id, d])
		if best.hp <= 0:
			_kill(best, null, t.owner)


func end_turn() -> void:
	var s := current
	_turrets_fire(s)
	saved_pm[s] = mini(pm_rule()[1], pm)
	turn += 1
	if s != first:
		round += 1
	current = 1 - s
	if round > R.ROUNDS and winner == NO_WINNER:
		_tiebreak()


func buildings_of(side: int) -> int:
	var n := 0
	for p in owner:
		if owner[p] == side:
			n += 1
	return n


func alive_value(side: int) -> int:
	var v := 0
	for u in units.values():
		if u.side == side:
			v += worth(u.t)
	return v


## Quién va ganando según el desempate (edificios, valor destruido, valor vivo): 0, 1 o -1 si empatan.
func standing() -> int:
	var key := []
	for x in [0, 1]:
		key.append([buildings_of(x), destroyed[x], alive_value(x)])
	for i in range(3):
		if key[0][i] != key[1][i]:
			return 0 if key[0][i] > key[1][i] else 1
	return -1


func _tiebreak() -> void:                          # C12.5
	var key := []
	for x in [0, 1]:
		key.append([buildings_of(x), destroyed[x], alive_value(x)])
	var w := standing()
	var h := "valor_vivo"
	if key[0][0] != key[1][0]:
		h = "edificios"
	elif destroyed[0] != destroyed[1]:
		h = "valor_destruido"
	_finish(w, ("ronda_limite_" + h) if w >= 0 else "empate")


# ------------------------------------------------------------------ utilidades
static func _opt(x) -> String:
	if x == null or (x is int and x == -1):
		return "N"
	return str(x)


## Estado completo en texto; coincide carácter a carácter con canonical() de export_golden.py.
func canonical() -> String:
	var lines := []
	var w := "N" if winner == NO_WINNER else str(winner)
	var h := "N" if how == "" else how
	lines.append("T%d R%d C%d PM%d S%d,%d SP%d,%d W%s H%s DS%d,%d D%d,%d" % [turn, round, current, pm,
		supplies[0], supplies[1], saved_pm[0], saved_pm[1], w, h, dom_streak[0], dom_streak[1],
		destroyed[0], destroyed[1]])
	var ter := ""
	for r in range(1, 9):
		for c in range(12):
			ter += terrain[Vector2i(c, r)]
	lines.append(ter)
	var parts := []
	for p in R.sorted_cells(owner.keys()):
		parts.append("%s:%s" % [R.cell_name(p), "N" if owner[p] == -1 else str(owner[p])])
	lines.append(" ".join(parts))
	parts = []
	for p in R.sorted_cells(capture.keys()):
		parts.append("%s:%d:%d:%d" % [R.cell_name(p), capture[p][0], capture[p][1], capture[p][2]])
	lines.append(" ".join(parts))
	parts = []
	for p in R.sorted_cells(orders.keys()):
		parts.append("%s:%d:%s:%d" % [R.cell_name(p), orders[p][0], orders[p][1], orders[p][2]])
	lines.append(" ".join(parts))
	for u in units.values():
		var tr := "-" if u.training == null else "%s@%d" % [u.training[0], u.training[1]]
		lines.append("%d:%d:%s:%d:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%d" % [u.id, u.side, u.t, u.hp,
			R.cell_name(u.pos), "1" if u.veteran else "0", _opt(u.crew), _opt(u.char_id), _opt(u.carrier),
			_opt(u.home), tr, _opt(u.stun), "1" if u.acted else "0", "1" if u.moved else "0", u.barricades])
	parts = []
	for q in R.sorted_cells(turrets.keys()):
		var t: Dictionary = turrets[q]
		parts.append("%s:%d:%d:%s:%d:%s" % [R.cell_name(q), t.hp, t.max, "N" if t.owner == -1 else str(t.owner),
			t.off, t.kind])
	lines.append(" ".join(parts))
	for x in [0, 1]:
		parts = []
		var names: Array = card_ready[x].keys()
		names.sort()
		for c in names:
			parts.append("%s:%d" % [c, card_ready[x][c]])
		lines.append(" ".join(parts))
	return "\n".join(lines)
