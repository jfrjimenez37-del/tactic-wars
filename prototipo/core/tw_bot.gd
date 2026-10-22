class_name TWBot
extends RefCounted
## IA de la capa 0: traducción directa de HeuristicBot (tw_sim/bots.py). Puntúa cada acción legal
## (daño, captura, riesgo de la casilla, avance, producción, terreno, cartas) y juega la mejor
## mientras supere el umbral. Con la misma semilla elige exactamente las mismas jugadas que en Python.

const R = preload("res://core/tw_rules.gd")
const VALUE := {"F": 2.5, "A": 2.5, "I": 2.5, "P": 1.5, "J": 3.0, "T": 6.0, "R": 5.0, "C": 4.0, "K": 3.0}
const BUILDING_VALUE := {"H": 40.0, "Q": 8.0, "U": 5.0}
const STYLES := {
	"normal": {"risk": 1.0, "pos": 0.6, "cap": 1.0, "atk": 1.0, "prod": 1.0},
	"agresivo": {"risk": 0.5, "pos": 0.9, "cap": 1.0, "atk": 1.4, "prod": 1.0},
	"prudente": {"risk": 1.6, "pos": 0.4, "cap": 1.0, "atk": 0.9, "prod": 1.0},
	"economico": {"risk": 1.0, "pos": 0.6, "cap": 1.6, "atk": 0.8, "prod": 1.3},
}

var g: TWGame
var side: int
var base_w: Dictionary
var w: Dictionary
var rng: TWRng
var noise: float
var threshold: float


func _init(p_game: TWGame, p_side: int, style := "normal", seed := 0, p_noise := 0.3, p_threshold := 0.4) -> void:
	g = p_game
	side = p_side
	base_w = STYLES[style].duplicate()
	w = base_w.duplicate()
	rng = TWRng.new(seed)
	noise = p_noise
	threshold = p_threshold


## A partir de la ronda 8, si va perdiendo en el desempate, arriesga más.
func _adapt() -> void:
	w = base_w.duplicate()
	if g.round >= 8:
		if g.standing() != side:
			w.risk = w.risk * 0.5
			w.pos = w.pos * 1.6
			w.atk = w.atk * 1.2
			w.cap = w.cap * 1.3
		else:
			w.risk = w.risk * 1.3


func _threat() -> Dictionary:
	var per := {}
	for e in g.activatable(1 - side):
		var cells := {}
		if e.t == "R":
			var hi := 4 if g.terrain[e.pos] == "C" else 3
			for q in g.terrain:
				var dd := R.dist(q, e.pos)
				if dd >= 2 and dd <= hi:
					cells[q] = true
		else:
			for p in g.reach(e):
				for q in R.neighbors(p):
					cells[q] = true
		for q in cells:
			for cl in ["pie", "lig", "bli"]:
				if R.DAMAGE[e.t][cl] > 0:
					_push(per, q, cl, float(R.DAMAGE[e.t][cl] + (1 if e.veteran else 0)))
	for tq in g.turrets:
		var t: Dictionary = g.turrets[tq]
		if t.hp > 0 and t.owner != side and t.off < g.turn:
			for q in g.terrain:
				var dd := R.dist(q, tq)
				if dd >= t.lo and dd <= t.hi:
					for cl in ["pie", "lig", "bli"]:
						_push(per, q, cl, t.dmg * 0.8)
	var th := {}
	for q in per:
		var row := {"pie": 0.0, "lig": 0.0, "bli": 0.0}
		for cl in per[q]:
			var lst: Array = per[q][cl]
			lst.sort()
			lst.reverse()
			var rest := 0.0
			for i in range(1, mini(3, lst.size())):
				rest += lst[i]
			row[cl] = lst[0] + 0.5 * rest
		th[q] = row
	return th


static func _push(per: Dictionary, q: Vector2i, cl: String, v: float) -> void:
	if not per.has(q):
		per[q] = {}
	if not per[q].has(cl):
		per[q][cl] = []
	per[q][cl].append(v)


func _th(ctx: Dictionary, q: Vector2i, cl: String) -> float:
	var th: Dictionary = ctx.th
	return th[q][cl] if th.has(q) else 0.0


func _context() -> Dictionary:
	var s := side
	var enemies := g.on_board(1 - s)
	var targets := []
	var home := []
	for p in g.owner:
		if g.owner[p] != s:
			targets.append(p)
		elif g.terrain[p] == "H" or g.terrain[p] == "Q":
			home.append(p)
	var en_pos := []
	for e in enemies:
		en_pos.append(e.pos)
	en_pos.append(g.hq[1 - s])
	var capturing := []
	for p in g.capture:
		var c: Array = g.capture[p]
		if c[0] != s and g.owner[p] == s:
			capturing.append(c[1])
	return {
		"th": _threat(), "enemies": enemies,
		"dm_foot": g.distances(targets, 0) if targets.size() > 0 else {},
		"dm": {0: g.distances(en_pos, 0), 1: g.distances(en_pos, 1), 2: g.distances(en_pos, 2)},
		"hq_tracks": g.distances([g.hq[s]], 2),
		"dm_home": g.distances(home, 0),
		"capturing": capturing,
	}


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ------------------------------------------------------------------ puntuación
func score(a: Dictionary, ctx: Dictionary) -> float:
	var s := side
	match a.kind:
		"end":
			return 0.0
		"produce":
			var t: String = a.target
			var sc: float = VALUE[t] * 0.9 * w.prod - 1.0
			var mine := 0
			for u in g.on_board(s):
				if "FAIK".contains(u.t):
					mine += 1
			if "FAIK".contains(t) and mine < 3:
				sc += 2.0
			if t == "A":
				var tanks := 0
				for e in ctx.enemies:
					if e.t == "T":
						tanks += 1
				if tanks >= 2:
					sc += 1.5
			if t == "F":
				sc += 0.5
			return sc
		"card":
			return _card_score(a, ctx)
		"dismount":
			var v: TWUnit = g.units[a.unit]
			if a.sub != "char" and v.char_id <= 0:
				for e in ctx.enemies:
					if e.t == "K" and R.dist(e.pos, v.pos) <= 2 + R.UNIT["K"][3]:
						return -3.0
			if g.owner.has(a.dest) and g.owner[a.dest] != s:
				var bv: float = BUILDING_VALUE[g.terrain[a.dest]]
				return 0.25 * bv * w.cap + (2 if g.owner[a.dest] == 1 - s else 0) - _th(ctx, a.dest, "pie") * 0.4 - 0.2
			return -1.0
	var u: TWUnit = g.units[a.unit]
	var cl: String = R.UNIT[u.t][0]
	var e: Vector2i = a.dest
	var risk: float = _th(ctx, e, cl) * VALUE[u.t] / R.UNIT[u.t][2] * w.risk
	var before: int
	var after: int
	if u.t == "P" and g.supplies[s] >= 2:
		before = ctx.dm_home.get(u.pos, 30)
		after = ctx.dm_home.get(e, 30)
	elif u.t == "K":
		before = ctx.dm[0].get(u.pos, 30)
		after = ctx.dm[0].get(e, 30)
	elif R.FOOT.contains(u.t):
		before = ctx.dm_foot.get(u.pos, 30)
		after = ctx.dm_foot.get(e, 30)
	else:
		var dm: Dictionary = ctx.dm[R.UNIT[u.t][1]]
		before = dm.get(u.pos, 30)
		after = dm.get(e, 30)
		if u.t == "R":
			before = absi(before - 3)
			after = absi(after - 3)
	var base: float = (before - after) * 0.25 * w.pos * (0.6 if u.t == "R" else 1.0) - 0.6 * risk
	match a.sub:
		"none":
			return base
		"attack":
			var en: TWUnit = g.units[a.target]
			var old = u.pos
			u.pos = e
			var d := g.damage(u, en)
			var sc: float = d * VALUE[en.t] / R.UNIT[en.t][2] * w.atk
			if d >= en.hp:
				sc += VALUE[en.t] * 0.8 + (0.5 if R.VEHICLES.contains(en.t) and en.crew > 0 else 0.0)
			elif u.t != "R" and en.t != "R" and R.dist(e, en.pos) == 1:
				var c := g.damage(en, u, true)
				sc -= c * VALUE[u.t] / R.UNIT[u.t][2] + (VALUE[u.t] * 0.8 if c >= u.hp else 0.0)
			u.pos = old
			if ctx.capturing.has(en.id):
				sc += 4
			return base + sc
		"capture":
			var c = g.capture.get(e)
			var have: int = c[2] if c != null and c[1] == u.id else 0
			var add := 2 if (u.t == "F" or u.t == "C") else 1
			var bv: float = BUILDING_VALUE[g.terrain[e]]
			var need := 4
			var sc: float = float(add) / need * bv * w.cap + (bv if have + add >= need else 0.0) + (2 if g.owner[e] == 1 - s else 0)
			if have + add >= need:
				var mine := g.buildings_of(s)
				var theirs := g.buildings_of(1 - s)
				if mine + 1 >= R.DOMINATION:
					sc += 15
				if g.owner[e] == 1 - s and theirs >= R.DOMINATION - 1:
					sc += 15
			if g.terrain[e] == "U" and have + add >= need:
				sc += (R.CITY_FIRST if g.owner[e] == -1 else R.CITY_RETAKE) * 0.5
			return base + sc
		"repair":
			var v: TWUnit = g.units[a.target]
			var amt := mini(R.UNIT[v.t][2] - v.hp, 2 if u.t == "I" else 1)
			return base + amt * VALUE[v.t] / R.UNIT[v.t][2] * 1.2
		"board":
			return base + VALUE[g.units[a.target].t] * 0.6
		"struct":
			var q: Vector2i = a.target
			var ch: String = g.terrain[q]
			if ch == "#":
				return base + maxi(0, _path_gain(q, "r", true)) * 0.6 - 0.5
			if ch == "P":
				return base + _bridge_value(q, ctx) - 0.5
			return base + 0.5
		"attack_turret":
			var t: Dictionary = g.turrets[a.target]
			var d := g.turret_damage(u, a.target)
			return base + d * 5.0 / t.max * w.atk + (4.0 if d >= t.hp else 0.0) + (1.0 if t.owner == 1 - s else 0.0)
		"sabotage":
			var t: Dictionary = g.turrets[a.target]
			var near := 0.0
			for m in g.on_board(s):
				if R.dist(m.pos, a.target) <= t.hi + 2:
					near += VALUE[m.t]
			return base + minf(4.0, near * 0.3) - 0.5
		"repair_turret":
			var t: Dictionary = g.turrets[a.target]
			return base + (3.0 if t.hp == 0 else mini(2, t.max - t.hp) * 0.8)
		"hack":
			var v: TWUnit = g.units[a.target]
			return base + VALUE[v.t] * v.hp / R.UNIT[v.t][2] * 2.0
		"train":
			var t: String = a.target
			var tanks := 0
			for x in ctx.enemies:
				if x.t == "T":
					tanks += 1
			var sc: float = (VALUE[t] - VALUE["P"]) * 2.0 + (1.5 if t == "A" and tanks >= 2 else 0.0)
			sc -= g.cost(t) * 0.5
			return base + sc
		"barricade":
			return base + _barricade_value(a.target, ctx) - 0.8
	return base


func _card_score(a: Dictionary, ctx: Dictionary) -> float:
	var s := side
	var c: String = a.sub
	var cost: float = R.CARDS[c][0] * 0.6
	var enemies: Array = ctx.enemies
	match c:
		"marcha":
			return score(TWGame.act("activate", a.unit, a.dest, "none"), ctx) - 0.4
		"reparacion":
			var v: TWUnit = g.units[a.unit]
			return mini(3, R.UNIT[v.t][2] - v.hp) * VALUE[v.t] / R.UNIT[v.t][2] * 1.2 - cost
		"torreta", "misiles":
			var near := 0
			for e in enemies:
				if R.dist(e.pos, a.dest) <= 4:
					near += 1
			return 1.2 + 0.7 * near + (0.5 if c == "misiles" else 0.0) - cost
		"refuerzo":
			var mine := 0
			for m in g.on_board(s):
				if "FAIK".contains(m.t):
					mine += 1
			return VALUE[a.target] * 0.9 + (2.0 if mine < 2 else 0.0) - cost
		"hackeo":
			var t: Dictionary = g.turrets[a.dest]
			var near := 0.0
			for m in g.on_board(s):
				if R.dist(m.pos, a.dest) <= t.hi + 2:
					near += VALUE[m.t]
			return minf(4.0, near * 0.3) - cost
		"pem":
			var val := 0.0
			for e in enemies:
				if R.VEHICLES.contains(e.t) and _cheb(e.pos, a.dest) <= 1:
					val += VALUE[e.t] * 0.4
			var tv := 0.0
			for q in g.turrets:
				var t: Dictionary = g.turrets[q]
				if t.hp > 0 and t.owner != s and _cheb(q, a.dest) <= 1:
					tv += 1.5
			val += tv
			return val - cost
		"aereo", "saturacion":
			var val := 0.0
			for e in enemies:
				var dd := _cheb(e.pos, a.dest)
				var d := 0
				if c == "aereo":
					d = 4 if e.pos == a.dest else (2 if R.dist(e.pos, a.dest) == 1 else 0)
				else:
					d = 2 if dd <= 1 else 0
				if d != 0:
					val += mini(d, e.hp) * VALUE[e.t] / R.UNIT[e.t][2] * w.atk + (VALUE[e.t] * 0.8 if d >= e.hp else 0.0)
			return val - cost
		"paracaidistas":
			var best := 0.0
			for p in g.owner:
				if g.owner[p] != s and R.dist(p, a.dest) <= 1:
					best = maxf(best, BUILDING_VALUE[g.terrain[p]] * 0.3 * w.cap)
			return best + 1.0 - cost
	return -1.0


func _path_gain(q: Vector2i, new_ch: String, own: bool) -> int:
	var target: Vector2i = g.hq[1 - side] if own else g.hq[side]
	var start: Vector2i = g.hq[side] if own else g.hq[1 - side]
	var before: int = g.distances([target], 2).get(start, 99)
	var saved: String = g.terrain[q]
	g.terrain[q] = new_ch
	var after: int = g.distances([target], 2).get(start, 99)
	g.terrain[q] = saved
	return before - after


func _bridge_value(q: Vector2i, ctx: Dictionary) -> float:
	var before: Dictionary = ctx.hq_tracks
	var saved: String = g.terrain[q]
	g.terrain[q] = "~"
	var after := g.distances([g.hq[side]], 2)
	g.terrain[q] = saved
	var gain := 0
	for e in ctx.enemies:
		if R.VEHICLES.contains(e.t):
			gain += mini(after.get(e.pos, 40), 40) - before.get(e.pos, 40)
	var mine := 0
	for m in g.on_board(side):
		if R.VEHICLES.contains(m.t):
			mine += mini(after.get(m.pos, 40), 40) - before.get(m.pos, 40)
	return (gain - mine) * 0.25


func _barricade_value(q: Vector2i, ctx: Dictionary) -> float:
	var enemies := []
	for e in ctx.enemies:
		if R.VEHICLES.contains(e.t) and R.dist(e.pos, g.hq[side]) <= 10:
			enemies.append(e)
	if enemies.is_empty():
		return -1.0
	var saved: String = g.terrain[q]
	g.terrain[q] = "X"
	var after := g.distances([g.hq[side]], 2)
	g.terrain[q] = saved
	var before: Dictionary = ctx.hq_tracks
	var gain := 0
	for e in enemies:
		gain += mini(after.get(e.pos, 40), 40) - before.get(e.pos, 40)
	var mine := 0
	for m in g.on_board(side):
		if R.VEHICLES.contains(m.t):
			mine += mini(after.get(m.pos, 40), 40) - before.get(m.pos, 40)
	return (gain - 0.5 * mine) * 0.3


# ------------------------------------------------------------------ turno
## Elige la siguiente acción del turno (la interfaz la aplica y la anima).
func choose() -> Dictionary:
	var acts := g.legal_actions()
	var ctx := _context()
	var best = null
	var best_sc := 0.0
	for a in acts:
		var sc := score(a, ctx) + (rng.uniform(-noise, noise) if a.kind != "end" else 0.0)
		if best == null or sc > best_sc:
			best = a
			best_sc = sc
	if best.kind != "end" and best_sc < threshold:
		return TWGame.act("end")
	return best


func begin_turn() -> void:
	_adapt()


## Juega el turno completo (para pruebas y para el modo sin animaciones).
func play_turn() -> void:
	begin_turn()
	while g.winner == TWGame.NO_WINNER and g.current == side:
		g.apply(choose(), false)
