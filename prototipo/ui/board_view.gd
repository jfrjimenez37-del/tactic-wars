extends Control
## Dibuja el tablero, las unidades, las torretas y los resaltados. Los toques los recibe BoardCamera.

const R = preload("res://core/tw_rules.gd")
const S := 72                                   # tamaño de casilla en píxeles

const TERRAIN_COLOR := {
	".": Color("8db360"), "=": Color("c9b48a"), "B": Color("3f7d3a"), "C": Color("a08b5b"),
	"~": Color("4f86c6"), "P": Color("8b6b45"), "#": Color("555555"), "r": Color("7a7067"),
	"X": Color("6e4b2a"), "O": Color("8db360"), "H": Color("b9b9b9"), "Q": Color("b9b9b9"), "U": Color("c8c8c8"),
}
const SIDE_COLOR := [Color("2fa36b"), Color("e39b2d")]   # Brigada Jade, Legión Ámbar
const NEUTRAL := Color("e8e8e8")
const UNIT_LABEL := {"F": "F", "A": "AT", "I": "In", "K": "Hk", "P": "Tr", "C": "★", "J": "J", "T": "T", "R": "Ar"}

var game: TWGame
var selected := -1                 # id de la unidad seleccionada
var marks := {}                    # casilla -> Color de resaltado
var target_marks := {}             # casilla -> Color (objetivos)


func _ready() -> void:
	custom_minimum_size = Vector2(R.W * S, R.H * S)


func cell_rect(p: Vector2i) -> Rect2:
	return Rect2(p.x * S, (R.H - p.y) * S, S, S)


func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	for p in game.terrain:
		var rect := cell_rect(p)
		var ch: String = game.terrain[p]
		draw_rect(rect, TERRAIN_COLOR.get(ch, Color.MAGENTA))
		match ch:
			"B":
				draw_circle(rect.get_center() + Vector2(-12, 6), 10, Color("2e5e2b"))
				draw_circle(rect.get_center() + Vector2(10, -6), 12, Color("2e5e2b"))
			"C":
				draw_colored_polygon(PackedVector2Array([rect.position + Vector2(10, 60), rect.position + Vector2(36, 18),
					rect.position + Vector2(62, 60)]), Color("8a744a"))
			"~":
				for k in range(3):
					draw_line(rect.position + Vector2(8, 18 + k * 18), rect.position + Vector2(64, 18 + k * 18), Color("7fb0e6"), 2)
			"P":
				draw_rect(Rect2(rect.position + Vector2(0, 22), Vector2(S, 28)), Color("a5835a"))
			"#":
				draw_rect(rect.grow(-8), Color("777777"))
			"r":
				draw_rect(Rect2(rect.position + Vector2(10, 30), Vector2(20, 30)), Color("958a7f"))
				draw_rect(Rect2(rect.position + Vector2(40, 40), Vector2(22, 20)), Color("958a7f"))
			"X":
				draw_line(rect.position + Vector2(10, 10), rect.position + Vector2(62, 62), Color("3b2614"), 6)
				draw_line(rect.position + Vector2(62, 10), rect.position + Vector2(10, 62), Color("3b2614"), 6)
		if game.owner.has(p):
			var o: int = game.owner[p]
			var col: Color = NEUTRAL if o < 0 else SIDE_COLOR[o]
			draw_rect(rect.grow(-3), col, false, 5)
			var letter: String = {"H": "CG", "Q": "Cu", "U": ""}[ch]
			if letter != "":
				draw_string(font, rect.position + Vector2(4, 16), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
		draw_rect(rect, Color(0, 0, 0, 0.25), false, 1)
	# coordenadas (A-L abajo, 1-8 a la izquierda dentro de cada casilla del borde)
	for c in range(R.W):
		draw_string(font, Vector2(c * S + S - 14, R.H * S - 4), R.COLS[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.55))
	for r in range(1, R.H + 1):
		draw_string(font, Vector2(2, (R.H - r) * S + S / 2.0 + 4), str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.55))
	# progreso de captura
	for p in game.capture:
		var c: Array = game.capture[p]
		var rect := cell_rect(p)
		draw_rect(Rect2(rect.position + Vector2(6, S - 10), Vector2((S - 12) * c[2] / 4.0, 6)), SIDE_COLOR[c[0]])
	# torretas
	for q in game.turrets:
		var t: Dictionary = game.turrets[q]
		var rect := cell_rect(q)
		var col: Color = NEUTRAL if t.owner < 0 else SIDE_COLOR[t.owner]
		if t.hp <= 0:
			col = Color(0.3, 0.3, 0.3)
		var off: bool = game.turn <= t.off
		var center := rect.position + Vector2(S - 16, 16)
		draw_circle(center, 13, Color(0.15, 0.15, 0.15))
		draw_circle(center, 10, col.darkened(0.5) if off else col)
		draw_string(font, center + Vector2(-10, 5), str(t.hp), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color.BLACK)
	# resaltados
	for p in marks:
		draw_rect(cell_rect(p).grow(-2), marks[p], true)
	for p in target_marks:
		draw_rect(cell_rect(p).grow(-4), target_marks[p], false, 4)
	# unidades
	for u in game.on_board():
		_draw_unit(u, font)


func _draw_unit(u: TWUnit, font: Font) -> void:
	var rect := cell_rect(u.pos)
	var c := rect.get_center()
	var col: Color = SIDE_COLOR[u.side]
	var dim := u.acted and u.side == game.current
	if dim:
		col = col.darkened(0.45)
	var is_veh := R.VEHICLES.contains(u.t)
	if is_veh:
		var body := Rect2(c - Vector2(24, 20), Vector2(48, 40))
		draw_rect(body, col)
		draw_rect(body, Color.BLACK, false, 2)
		if u.crew >= 0:
			draw_circle(body.position + Vector2(8, 8), 4, Color.WHITE)
		if u.char_id >= 0:
			draw_circle(body.position + Vector2(18, 8), 4, Color("ffd84a"))
	else:
		draw_circle(c, 20, col)
		draw_arc(c, 20, 0, TAU, 32, Color.BLACK, 2)
	draw_string(font, c + Vector2(-24, 6), UNIT_LABEL.get(u.t, u.t), HORIZONTAL_ALIGNMENT_CENTER, 48, 18, Color.BLACK)
	draw_string(font, rect.position + Vector2(S - 22, S - 6), str(u.hp), HORIZONTAL_ALIGNMENT_RIGHT, 18, 14, Color.WHITE)
	if u.veteran:
		draw_string(font, rect.position + Vector2(4, S - 6), "V", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd84a"))
	if u.stun >= game.turn:
		draw_string(font, rect.position + Vector2(4, 30), "PEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	if u.training != null:
		draw_string(font, rect.position + Vector2(4, 30), "↑" + u.training[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if u.id == selected:
		draw_rect(rect.grow(-1), Color.WHITE, false, 3)
