extends Control
## Dibuja el tablero, las unidades, las torretas y los resaltados. Los toques los recibe BoardCamera.

const R = preload("res://core/tw_rules.gd")
const Art = preload("res://ui/art.gd")
const S := 72                                   # tamaño de casilla en píxeles

const SIDE_COLOR := [Color("2fa36b"), Color("e39b2d")]   # Brigada Jade, Legión Ámbar
const NEUTRAL := Color("e8e8e8")

var game: TWGame
var selected := -1                 # id de la unidad seleccionada
var marks := {}                    # casilla -> Color de resaltado
var target_marks := {}             # casilla -> Color (objetivos)

# Animaciones: unidades «fantasma» que se mueven o explotan, unidades ocultas mientras se anima su
# movimiento y efectos con duración (disparos, números de daño, explosiones, anillos).
var speed := 1.0                   # 1 = velocidad normal; las pruebas automáticas lo suben
var ghosts := []                   # {u: TWUnit (copia), c: Vector2 centro, k: escala}
var hidden_units := {}                   # id -> true
var effects := []                  # {kind, t0, dur, ...}


func _ready() -> void:
	custom_minimum_size = Vector2(R.W * S, R.H * S)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS    # el arte de 256 px se ve nítido al reducirlo


func cell_rect(p: Vector2i) -> Rect2:
	return Rect2(p.x * S, (R.H - p.y) * S, S, S)


func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	for p in game.terrain:
		var rect := cell_rect(p)
		for t in terrain_layers(p):
			draw_texture_rect(t, rect, false)
		if game.owner.has(p):
			var bt := _building_tex(p)
			if bt != null:
				draw_texture_rect(bt, rect, false)
		draw_rect(rect, Color(0, 0, 0, 0.16), false, 1)
	# coordenadas (A-L abajo, 1-8 a la izquierda dentro de cada casilla del borde)
	for c in range(R.W):
		draw_string_outline(font, Vector2(c * S + S - 14, R.H * S - 4), R.COLS[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(c * S + S - 14, R.H * S - 4), R.COLS[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	for r in range(1, R.H + 1):
		draw_string_outline(font, Vector2(2, (R.H - r) * S + S / 2.0 + 4), str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(2, (R.H - r) * S + S / 2.0 + 4), str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	# progreso de captura
	for p in game.capture:
		var c: Array = game.capture[p]
		var rect := cell_rect(p)
		draw_rect(Rect2(rect.position + Vector2(6, S - 10), Vector2((S - 12) * c[2] / 4.0, 6)), SIDE_COLOR[c[0]])
	# torretas: la de una plaza va en la esquina del edificio; las de las cartas ocupan la casilla
	for q in game.turrets:
		var t: Dictionary = game.turrets[q]
		var rect := cell_rect(q)
		var tt: Texture2D = Art.tex("torretas/destruida") if t.hp <= 0 else \
			Art.tex("torretas/%s_%s" % [Art.side_name(t.owner), Art.TURRET_FILE[t.kind]])
		var off: bool = game.turn <= t.off
		var tr := Rect2(rect.position + Vector2(S * 0.28, -S * 0.12), Vector2(S * 0.62, S * 0.62)) if t.kind == "plaza" \
			else rect.grow(-S * 0.04)
		if tt != null:
			draw_texture_rect(tt, tr, false, Color(0.55, 0.6, 0.9) if off else Color.WHITE)
		var center := rect.position + Vector2(S - 10, 10)
		draw_circle(center, 10, Color(0.1, 0.1, 0.1, 0.85))
		draw_string(font, center + Vector2(-10, 5), str(t.hp), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color.WHITE)
	# resaltados
	for p in marks:
		draw_rect(cell_rect(p).grow(-2), marks[p], true)
	for p in target_marks:
		draw_rect(cell_rect(p).grow(-4), target_marks[p], false, 4)
	# unidades
	for u in game.on_board():
		if not hidden_units.has(u.id):
			_draw_unit(u, font, cell_rect(u.pos).get_center())
	for gh in ghosts:
		draw_set_transform(gh.c, 0.0, Vector2(gh.k, gh.k))
		_draw_unit(gh.u, font, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	_draw_effects(font)


func _draw_unit(u: TWUnit, font: Font, c: Vector2) -> void:
	var rect := Rect2(c - Vector2(S, S) / 2, Vector2(S, S))
	var dim := u.acted and game != null and u.side == game.current
	var tex := Art.unit(u.t, u.side)
	var size := S * 0.94
	var r := Rect2(c - Vector2(size, size) / 2 + Vector2(0, -S * 0.03), Vector2(size, size))
	if u.side == 1:                                    # Ámbar mira hacia la izquierda (hacia Jade)
		r.size.x = -size                               # ancho negativo: Godot la voltea en el mismo sitio
	draw_texture_rect(tex, r, false, Color(0.55, 0.55, 0.55) if dim else Color.WHITE)
	# vida, tripulación, personaje y estados, encima del dibujo
	var hp_pos := rect.position + Vector2(S - 20, S - 4)
	draw_string_outline(font, hp_pos, str(u.hp), HORIZONTAL_ALIGNMENT_RIGHT, 18, 16, 5, Color.BLACK)
	draw_string(font, hp_pos, str(u.hp), HORIZONTAL_ALIGNMENT_RIGHT, 18, 16, Color.WHITE)
	if R.VEHICLES.contains(u.t):
		var dot := rect.position + Vector2(8, S - 9)
		if u.crew >= 0:
			draw_circle(dot, 5, Color.BLACK)
			draw_circle(dot, 3.5, Color.WHITE)
		if u.char_id >= 0:
			draw_circle(dot + Vector2(12, 0), 5, Color.BLACK)
			draw_circle(dot + Vector2(12, 0), 3.5, Color("ffd84a"))
	if u.veteran:
		draw_string_outline(font, rect.position + Vector2(4, 16), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(font, rect.position + Vector2(4, 16), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd84a"))
	if game != null and u.stun >= game.turn:
		draw_string_outline(font, rect.position + Vector2(4, 34), "PEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
		draw_string(font, rect.position + Vector2(4, 34), "PEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8fd3ff"))
	if u.training != null:
		draw_string_outline(font, rect.position + Vector2(4, 34), "↑" + u.training[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(font, rect.position + Vector2(4, 34), "↑" + u.training[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if u.id == selected:
		draw_rect(rect.grow(-1), Color.WHITE, false, 3)


# ------------------------------------------------------------------ terreno con arte
func _at(p: Vector2i) -> String:
	return game.terrain.get(p, "")


## Bits de los vecinos (N=1, E=2, S=4, O=8) cuyo terreno está en chars.
func _mask(p: Vector2i, chars: String) -> int:
	var m := 0
	for d in [[Vector2i(0, 1), 1], [Vector2i(1, 0), 2], [Vector2i(0, -1), 4], [Vector2i(-1, 0), 8]]:
		var ch := _at(p + d[0])
		if ch != "" and chars.contains(ch):
			m |= d[1]
	return m


## Capas de terreno de una casilla (de abajo arriba): llanura y, encima, el elemento del terreno.
func terrain_layers(p: Vector2i) -> Array:
	var ch := _at(p)
	if ch == "O":
		ch = game.turrets[p].base if game.turrets.has(p) else "."
	var plain: Texture2D = Art.tex("terreno/llanura_2" if (p.x * 7 + p.y * 3) % 5 == 0 else "terreno/llanura")
	match ch:
		"B":
			return [Art.tex("terreno/bosque")]
		"C":
			return [Art.tex("terreno/colina")]
		"#":
			return [Art.tex("terreno/muro")]
		"r":
			return [Art.tex("terreno/ruinas")]
		"X":
			return [plain, Art.tex("terreno/barricada")]
		"=":
			var m := _mask(p, "=PHQU")
			if m in [0, 2, 8]:                         # aislado o final: tramo recto
				m = 10
			elif m in [1, 4]:
				m = 5
			return [Art.tex("terreno/camino_%d" % m)]
		"~", "P":
			var layers := [_water_tex(p)]
			if ch == "P":
				layers.append(Art.tex("terreno/puente_v" if _bridge_vertical(p) else "terreno/puente_h"))
			return layers
	return [plain]


## Agua: cuarto de lago si la casilla forma parte de un bloque de 2×2; si no, la pieza de río.
func _water_tex(p: Vector2i) -> Texture2D:
	var m := _mask(p, "~P")
	for c in [[1 | 2, Vector2i(1, 1), "ne"], [2 | 4, Vector2i(1, -1), "se"], [4 | 8, Vector2i(-1, -1), "so"], [8 | 1, Vector2i(-1, 1), "no"]]:
		if m & c[0] == c[0] and "~P".contains(_at(p + c[1])) and _at(p + c[1]) != "":
			return Art.tex("terreno/lago_" + c[2])
	return Art.tex("terreno/rio_%d" % m)


## La pasarela va en el eje con menos agua alrededor (si empatan, en el del camino).
func _bridge_vertical(p: Vector2i) -> bool:
	var dry := func(q: Vector2i) -> int:
		var ch := _at(q)
		return 0 if ch == "" or "~P".contains(ch) else (2 if ch == "=" else 1)
	var v: int = dry.call(p + Vector2i(0, 1)) + dry.call(p + Vector2i(0, -1))
	var h: int = dry.call(p + Vector2i(1, 0)) + dry.call(p + Vector2i(-1, 0))
	return v >= h


func _building_tex(p: Vector2i) -> Texture2D:
	var o: int = game.owner[p]
	var kind: String = {"H": "cg", "Q": "cuartel", "U": "ciudad"}.get(game.terrain[p], "ciudad")
	if kind == "ciudad" and game.turrets.has(p) and game.turrets[p].kind == "plaza":
		kind = "plaza"
	if o < 0 and kind in ["cg", "cuartel"]:
		kind = "ciudad"
	return Art.tex("edificios/%s_%s" % [Art.side_name(o), kind])


# ------------------------------------------------------------------ animaciones
func center(p: Vector2i) -> Vector2:
	return cell_rect(p).get_center()


func _process(_delta: float) -> void:
	if effects.is_empty() and ghosts.is_empty():
		return
	var now := Time.get_ticks_msec()
	effects = effects.filter(func(e): return now - e.t0 < e.dur * 1000.0)
	queue_redraw()


func add_effect(kind: String, dur: float, data: Dictionary) -> void:
	data.kind = kind
	data.t0 = Time.get_ticks_msec()
	data.dur = dur / speed
	effects.append(data)
	queue_redraw()


func wait(t: float) -> void:
	await get_tree().create_timer(t / speed).timeout


## Mueve una copia de la unidad casilla a casilla por el camino (como mucho 0,8 s).
func move_ghost(u: TWUnit, path: Array) -> void:
	var gh := {"u": u, "c": center(path[0]), "k": 1.0}
	ghosts.append(gh)
	var step := minf(0.13, 0.8 / maxf(1, path.size() - 1))
	var tw := create_tween()
	tw.set_speed_scale(speed)
	for i in range(1, path.size()):
		tw.tween_method(func(v: Vector2): gh.c = v, center(path[i - 1]), center(path[i]), step)
	await tw.finished
	ghosts.erase(gh)
	queue_redraw()


## Proyectil de a a b y destello al llegar.
func shot(a: Vector2, b: Vector2, col := Color("fff2a8")) -> void:
	add_effect("shot", 0.22, {"a": a, "b": b, "col": col})
	await wait(0.22)
	add_effect("flash", 0.25, {"at": b})


## Bomba que cae sobre b (cartas).
func bomb(b: Vector2) -> void:
	add_effect("bomb", 0.3, {"at": b})
	await wait(0.3)
	add_effect("flash", 0.25, {"at": b})


func number(at: Vector2, text: String, col := Color("ff5050")) -> void:
	add_effect("number", 0.8, {"at": at, "text": text, "col": col})


## Explosión; si se da la copia de la unidad destruida, se encoge mientras tanto.
func boom(at: Vector2, u: TWUnit = null) -> void:
	add_effect("boom", 0.55, {"at": at})
	if u != null:
		var gh := {"u": u, "c": at, "k": 1.0}
		ghosts.append(gh)
		var tw := create_tween()
		tw.set_speed_scale(speed)
		tw.tween_method(func(v: float): gh.k = v, 1.0, 0.1, 0.4)
		await tw.finished
		ghosts.erase(gh)
	else:
		await wait(0.4)


## Anillo que se expande (captura, carta, expulsión); size en casillas.
func ring(at: Vector2, col: Color, size := 1.0, dur := 0.5) -> void:
	add_effect("ring", dur, {"at": at, "col": col, "size": size})


## Dibuja el fotograma que toca de una hoja de animación horizontal (fotogramas cuadrados).
func _sheet(path: String, frames: int, p: float, at: Vector2, size: float) -> bool:
	var t := Art.tex(path)
	if t == null:
		return false
	var f := mini(frames - 1, int(p * frames))
	var fw := t.get_width() / frames
	draw_texture_rect_region(t, Rect2(at - Vector2(size, size) / 2, Vector2(size, size)), Rect2(f * fw, 0, fw, t.get_height()))
	return true


## Bandera del bando que aparece al completar una captura.
func flag(at: Vector2, side: int) -> void:
	add_effect("flag", 0.9, {"at": at, "side": Art.SIDE[side]})


## Onda del PEM sobre la zona (size en casillas).
func pem(at: Vector2, size := 1.6) -> void:
	add_effect("pem", 0.6, {"at": at, "size": size})


func _draw_effects(font: Font) -> void:
	var now := Time.get_ticks_msec()
	for e in effects:
		var p := clampf((now - e.t0) / (e.dur * 1000.0), 0.0, 1.0)
		match e.kind:
			"shot":
				var head: Vector2 = e.a.lerp(e.b, p)
				var tail: Vector2 = e.a.lerp(e.b, maxf(0.0, p - 0.25))
				draw_line(tail, head, Color(e.col, 0.5), 3)
				var pt := Art.tex("efectos/proyectil")
				if pt != null:
					draw_set_transform(head, (e.b - e.a).angle(), Vector2.ONE)
					draw_texture_rect(pt, Rect2(Vector2(-S * 0.45, -S * 0.22), Vector2(S * 0.6, S * 0.44)), false, e.col.lightened(0.3))
					draw_set_transform(Vector2.ZERO)
				else:
					draw_circle(head, 6, e.col)
			"flash":
				if not _sheet("efectos/impacto", 4, p, e.at, S * 0.9):
					draw_circle(e.at, 10 + 26 * p, Color(1, 1, 0.85, 0.8 * (1.0 - p)))
			"bomb":
				var y := lerpf(e.at.y - S * 2.5, e.at.y, p * p)
				var bt := Art.tex("efectos/bomba")
				if bt != null:
					draw_texture_rect(bt, Rect2(Vector2(e.at.x - S * 0.3, y - S * 0.45), Vector2(S * 0.6, S * 0.6)), false)
				else:
					draw_circle(Vector2(e.at.x, y), 9, Color("2b2b2b"))
			"flag":
				var ft := Art.tex("efectos/bandera_" + e.side)
				var k := minf(1.0, p * 4.0)
				var a := 1.0 - maxf(0.0, p - 0.75) / 0.25
				if ft != null:
					var sz: float = S * 0.8 * k
					draw_texture_rect(ft, Rect2(e.at - Vector2(sz * 0.35, sz * 0.95), Vector2(sz, sz)), false, Color(1, 1, 1, a))
			"pem":
				var pm := Art.tex("efectos/pem")
				var sz: float = S * (0.6 + 2.6 * e.size * p / 1.6)
				if pm != null:
					draw_texture_rect(pm, Rect2(e.at - Vector2(sz, sz) / 2, Vector2(sz, sz)), false, Color(1, 1, 1, 1.0 - p * p))
			"number":
				var pos: Vector2 = e.at + Vector2(-30, -10 - 34 * p)
				var col := Color(e.col, 1.0 - maxf(0.0, p - 0.6) / 0.4)
				draw_string_outline(font, pos, e.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 26, 6, Color(0, 0, 0, col.a))
				draw_string(font, pos, e.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 26, col)
			"boom":
				if not _sheet("efectos/explosion", 8, p, e.at, S * 1.6):
					draw_circle(e.at, 8 + 34 * p, Color(1.0, 0.55, 0.1, 0.85 * (1.0 - p)))
			"ring":
				var r: float = S * 0.3 + S * 0.55 * e.size * p
				draw_arc(e.at, r, 0, TAU, 48, Color(e.col, 1.0 - p), 6)
