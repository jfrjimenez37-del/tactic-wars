extends Control
## Pantalla de partida: tablero, barra superior, panel de acciones y cartas.
## Modo de juego: Jade (humano) contra Ámbar (humano o IA).

const R = preload("res://core/tw_rules.gd")
const BoardView = preload("res://ui/board_view.gd")
const SetupScreen = preload("res://ui/setup_screen.gd")
const BoardCamera = preload("res://ui/board_camera.gd")
const Art = preload("res://ui/art.gd")
const Sfx = preload("res://ui/sfx.gd")
const FONT := 21              # tamaño de letra base (legible en el móvil)
const PANEL_W := 420
const TURN_TIME := 25.0       # C13: 25 s por turno y 60 s de reserva por partida
const RESERVE_TIME := 60.0
const SIDE_NAME := ["Brigada Jade", "Legión Ámbar"]

var game: TWGame
var board: Control            # BoardView, dentro de la cámara
var camera: Control           # BoardCamera
var top_label: Label
var clock_label: Label
var clock_on := false
var sfx: Node
var sound_button: Button
var anim := true              # animar las acciones (las pruebas rápidas lo desactivan)
var busy := false             # hay una animación en marcha: no se aceptan toques
var ending := false           # se está pasando el turno (hasta que empieza el siguiente)
var last_tick := -1
var anim_max := 0.0           # animación más larga hasta ahora, en segundos a velocidad normal (pruebas)
var anim_count := 0
var turn_left := TURN_TIME
var reserve := [RESERVE_TIME, RESERVE_TIME]
var info_label: Label
var actions_box: VBoxContainer
var cards_box: VBoxContainer
var log_label: Label
var end_button: Button
var overlay: Control
var overlay_box: PanelContainer
var vs_ai := true
var phase := "play"           # setup | deploy | play
var first := 0                # quién juega primero (sorteo)
var choices := [{}, {}]       # por bando: {army, deck}
var cells := [[], []]         # por bando: casilla de cada unidad del ejército
var dep_side := 0             # despliegue: bando que coloca, casillas, unidad elegida y zona
var dep_cells := []
var dep_sel := -1
var dep_zone := []
var dep_preview: TWGame
var pass_button: Button      # «Estoy listo» de la pantalla de pasar el móvil
var screen: Control           # pantalla que tapa el tablero (preparación o «pasa el móvil»)
var bots := []                # TWBot de cada bando (Ámbar en partida; los dos en pruebas)

var mode := "idle"            # idle | unit | building | card | dismount
var sel_unit := -1
var sel_cell = null
var sel_card := ""
var sel_sub := ""
var pending := []             # acciones posibles en el modo actual
var history := []


func _ready() -> void:
	_build_ui()
	var args := OS.get_cmdline_user_args()
	var quick := false
	for a in args:
		if a.begins_with("--demo=") or a == "--autoplay" or a.begins_with("--select="):
			quick = true
	for a in args:
		if a.begins_with("--demo="):
			anim = false
		if a == "--autoplay" or a.begins_with("--setup-test="):
			board.speed = 3.0
	if quick:
		_new_game()
	else:
		_start_setup()
	for a in args:
		if a.begins_with("--setup-test="):
			await _setup_test(a.substr(13))
	for a in args:
		if a.begins_with("--demo="):
			_demo(int(a.substr(7)))
	for a in args:
		if a == "--autoplay":
			await _autoplay()
	for a in args:
		if a.begins_with("--select="):
			_on_cell(R.cell(a.substr(9)))
	for a in args:
		if a.begins_with("--anim-shot="):
			await _anim_shot(a.substr(12), args)
	for a in args:
		if a.begins_with("--shot="):
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(a.substr(7))
			get_tree().quit()


func _build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = FONT
	var bg := ColorRect.new()
	bg.color = Color("1e2328")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	top_label = Label.new()
	top_label.add_theme_font_size_override("font_size", FONT + 2)
	top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_label.clip_text = true
	top.add_child(top_label)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", FONT + 4)
	top.add_child(clock_label)
	sound_button = Button.new()
	sound_button.text = "Sonido: sí"
	sound_button.focus_mode = Control.FOCUS_NONE
	sound_button.custom_minimum_size = Vector2(150, 0)
	sound_button.pressed.connect(func():
		sfx.enabled = not sfx.enabled
		sound_button.text = "Sonido: sí" if sfx.enabled else "Sonido: no")
	top.add_child(sound_button)
	sfx = Sfx.new()
	add_child(sfx)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	camera = BoardCamera.new()
	camera.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera.cell_clicked.connect(_on_cell)
	camera.on_focus = _focus_cell
	body.add_child(camera)
	board = camera.board
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W + 24, 0)
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(PANEL_W, 0)
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	end_button = Button.new()
	end_button.text = "Terminar turno"
	end_button.custom_minimum_size = Vector2(PANEL_W, 56)
	end_button.pressed.connect(_on_end_turn)
	vb.add_child(end_button)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(PANEL_W, 0)
	vb.add_child(info_label)
	actions_box = VBoxContainer.new()
	vb.add_child(actions_box)
	vb.add_child(HSeparator.new())
	var cl := Label.new()
	cl.text = "Cartas"
	vb.add_child(cl)
	cards_box = VBoxContainer.new()
	vb.add_child(cards_box)
	vb.add_child(HSeparator.new())
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(PANEL_W, 0)
	log_label.add_theme_font_size_override("font_size", FONT - 3)
	vb.add_child(log_label)
	overlay = Control.new()                  # fin de partida: fondo oscurecido y un panel centrado
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_box = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2a3036")
	box.set_corner_radius_all(10)
	box.set_content_margin_all(24)
	overlay_box.add_theme_stylebox_override("panel", box)
	center.add_child(overlay_box)


## Partida rápida con ejércitos fijos (para las pruebas automáticas).
func _new_game() -> void:
	game = TWSetup.new_game("equilibrado4", "hacker4", ["aereo", "reparacion", "torreta"],
		["hackeo", "misiles", "pem"], 0)
	board.game = game
	bots = [TWBot.new(game, 0, "normal", randi()), TWBot.new(game, 1, "normal", randi())]
	history = ["Empieza la partida. Juega la " + SIDE_NAME[game.current] + "."]
	overlay.visible = false
	_reset_selection()
	camera.center_on(_focus_cell(), false)


func _reset_selection() -> void:
	mode = "idle"
	sel_unit = -1
	sel_cell = null
	sel_card = ""
	pending = []
	_refresh()


# ------------------------------------------------------------------ textos
func unit_name(u: TWUnit) -> String:
	return "%s (%s)" % [R.NAMES[u.t], SIDE_NAME[u.side].split(" ")[1]]


func action_label(a: Dictionary) -> String:
	var cellname := R.cell_name(a.dest)
	match a.kind:
		"end":
			return "termina su turno"
		"produce":
			return "Fabricar %s — %d sum., %d turnos" % [R.NAMES[a.target], R.UNIT[a.target][7], R.UNIT[a.target][8] + R.BUILD_EXTRA]
		"dismount":
			return ("Desembarcar personaje en " if a.sub == "char" else "Desembarcar tripulación en ") + cellname
		"card":
			var nm: String = R.CARD_NAMES[a.sub]
			if a.sub == "marcha":
				return "%s: mover %s a %s" % [nm, R.NAMES[game.units[a.unit].t], cellname]
			if a.sub == "refuerzo":
				return "%s: %s" % [nm, R.NAMES[a.target]]
			return "%s en %s" % [nm, cellname]
	var u: TWUnit = game.units[a.unit]
	match a.sub:
		"none":
			return "Mover a " + cellname
		"attack":
			var en: TWUnit = game.units[a.target]
			return "Atacar %s en %s (%d de daño)" % [R.NAMES[en.t], R.cell_name(en.pos), game.damage(u, en)]
		"capture":
			return "Capturar el edificio de " + cellname
		"repair":
			return "Reparar " + R.NAMES[game.units[a.target].t]
		"board":
			return "Subir a " + R.NAMES[game.units[a.target].t]
		"struct":
			return "Destruir estructura en " + R.cell_name(a.target)
		"barricade":
			return "Construir barricada en " + R.cell_name(a.target)
		"train":
			return "Evolucionar a %s (%d sum.)" % [R.NAMES[a.target], R.UNIT[a.target][7]]
		"hack":
			return "Hackear " + R.NAMES[game.units[a.target].t]
		"attack_turret":
			return "Atacar torreta en %s (%d de daño)" % [R.cell_name(a.target), game.turret_damage(u, a.target)]
		"sabotage":
			return "Sabotear torreta en " + R.cell_name(a.target)
		"repair_turret":
			return "Reparar torreta en " + R.cell_name(a.target)
	return action_label_fallback(a)


func action_label_fallback(a: Dictionary) -> String:
	return TWGame.action_key(a)


# ------------------------------------------------------------------ refresco
func _refresh() -> void:
	var s := game.current
	var pr := game.pm_rule()
	top_label.text = "Ronda %d/%d · %s · PM %d (guarda %d) · Sum. %d | %d · Edif. %d-%d" % [
		mini(game.round, R.ROUNDS), R.ROUNDS, SIDE_NAME[s], game.pm, pr[1], game.supplies[0], game.supplies[1],
		game.buildings_of(0), game.buildings_of(1)]
	top_label.add_theme_color_override("font_color", BoardView.SIDE_COLOR[s].lightened(0.35))
	board.selected = sel_unit
	board.marks = {}
	board.target_marks = {}
	for a in pending:
		if a.dest != null:
			board.marks[a.dest] = Color(1, 1, 1, 0.28)
		if a.kind == "activate" and a.sub == "attack":
			board.target_marks[game.units[a.target].pos] = Color("ff4040")
		elif a.target is Vector2i:
			board.target_marks[a.target] = Color("40c0ff")
	board.queue_redraw()
	_fill_info()
	_fill_cards()
	log_label.text = "\n".join(history.slice(maxi(0, history.size() - 8)))
	end_button.disabled = game.winner != TWGame.NO_WINNER or not _is_human(game.current)
	if game.winner != TWGame.NO_WINNER:
		_show_winner()


func _fill_info() -> void:
	for c in actions_box.get_children():
		c.queue_free()
	match mode:
		"unit":
			var u: TWUnit = game.units[sel_unit]
			var txt := "%s · %d/%d PV · %d PM" % [unit_name(u), u.hp, R.UNIT[u.t][2], R.UNIT[u.t][4]]
			if u.crew >= 0:
				txt += " · con tripulación"
			if u.char_id >= 0:
				txt += " · lleva al personaje"
			if u.veteran:
				txt += " · veterano"
			if u.acted:
				txt += "\nYa actuó este turno."
			info_label.text = txt + "\nToca una casilla resaltada para mover o actuar."
			var subs := []
			for a in game.legal_actions():
				if a.kind == "dismount" and a.unit == sel_unit and not subs.has(a.sub):
					subs.append(a.sub)
					_add_button("Desembarcar" + (" personaje" if a.sub == "char" else " tripulación") + "…",
						_start_dismount.bind(a.sub))
			if sel_cell != null:
				_list_actions_at(sel_cell)
		"building":
			info_label.text = "Edificio en %s. Elige qué fabricar." % R.cell_name(sel_cell)
			for a in pending:
				_add_button(action_label(a), _do.bind(a))
		"card", "dismount":
			info_label.text = "Elige una casilla resaltada." if mode == "dismount" else \
				"%s: elige una casilla resaltada." % R.CARD_NAMES[sel_card]
			if sel_cell != null:
				_list_actions_at(sel_cell)
		_:
			if not _is_human(game.current):
				info_label.text = "Juega la %s (IA)…" % SIDE_NAME[game.current]
			else:
				info_label.text = "Turno de la %s. Toca una unidad propia, un cuartel propio o una carta." % SIDE_NAME[game.current]
	if mode != "idle":
		_add_button("Cancelar selección", _reset_selection)


func _list_actions_at(p: Vector2i) -> void:
	for a in pending:
		if a.dest == p:
			_add_button(action_label(a), _do.bind(a))


func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(PANEL_W, 48)
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(cb)
	actions_box.add_child(b)


func _fill_cards() -> void:
	for c in cards_box.get_children():
		c.queue_free()
	var s := game.current
	for c in game.decks[s]:
		var d: Array = R.CARDS[c]
		var b := Button.new()
		var ready_turn: int = game.card_ready[s][c]
		var status := ""
		if game.round < d[2]:
			status = " · desde la ronda %d" % d[2]
		elif ready_turn > game.turn:
			var n := int(ceil((ready_turn - game.turn) / 2.0))
			status = " · lista en %d ronda%s" % [n, "" if n == 1 else "s"]
		b.text = "%s (%d PM)%s" % [R.CARD_NAMES[c], d[0], ("\n" + status.substr(3)) if status != "" else ""]
		b.custom_minimum_size = Vector2(PANEL_W, 76)
		b.icon = Art.card(c)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not game.card_available(c) or game.winner != TWGame.NO_WINNER or not _is_human(game.current)
		b.pressed.connect(_start_card.bind(c))
		cards_box.add_child(b)


# ------------------------------------------------------------------ interacción
func _on_cell(p: Vector2i) -> void:
	if busy or ending:
		return
	if phase == "deploy":
		_deploy_cell(p)
		return
	if phase != "play" or game.winner != TWGame.NO_WINNER or (vs_ai and game.current == 1):
		return
	if mode in ["unit", "card", "dismount"]:
		var here := []
		for a in pending:
			if a.dest == p:
				here.append(a)
		if here.size() == 1:
			_do(here[0])
			return
		if here.size() > 1:
			sel_cell = p
			_refresh()
			return
	var u = game.at(p)
	if u != null and u.side == game.current:
		if mode == "unit" and sel_unit == u.id and game.owner.has(p):
			_select_building(p)
			return
		sfx.play("select")
		mode = "unit"
		sel_unit = u.id
		sel_cell = null
		pending = []
		for a in game.legal_actions():
			if a.kind == "activate" and a.unit == u.id:
				pending.append(a)
		_refresh()
		return
	if game.owner.has(p) and game.owner[p] == game.current:
		_select_building(p)
		return
	if u != null:
		info_label.text = "%s · %d/%d PV%s" % [unit_name(u), u.hp, R.UNIT[u.t][2], " · veterano" if u.veteran else ""]
	if u == null:
		_reset_selection()


func _select_building(p: Vector2i) -> void:
	mode = "building"
	sel_cell = p
	sel_unit = -1
	pending = []
	for a in game.legal_actions():
		if a.kind == "produce" and a.dest == p:
			pending.append(a)
	if pending.is_empty():
		history.append("Ese edificio no puede fabricar ahora (encargo pendiente, sin PM, sin suministros o en el límite).")
	_refresh()


func _start_card(c: String) -> void:
	mode = "card"
	sel_card = c
	sel_unit = -1
	sel_cell = null
	pending = []
	for a in game.legal_actions():
		if a.kind == "card" and a.sub == c:
			pending.append(a)
	_refresh()


func _start_dismount(sub: String) -> void:
	var vid := sel_unit
	mode = "dismount"
	sel_cell = null
	pending = []
	for a in game.legal_actions():
		if a.kind == "dismount" and a.unit == vid and a.sub == sub:
			pending.append(a)
	_refresh()


func _do(a: Dictionary) -> void:
	var who: String = SIDE_NAME[game.current].split(" ")[1]
	var label := action_label(a)
	var pre := _snapshot()
	var path := []
	if a.unit >= 0 and a.dest != null and (a.kind == "activate" or a.sub == "marcha") and game.units[a.unit].pos != null \
			and a.dest != game.units[a.unit].pos:
		path = game.path_to(game.units[a.unit], a.dest)
	game.events = []
	game.apply(a)
	var evs := game.events.duplicate()
	history.append("%s: %s" % [who, label])
	_report_events()
	_reset_selection()
	if anim and phase == "play":
		_animate(a, evs, pre, path)


## Copia de las unidades antes de una acción (para animar las que se mueven, mueren o salen de un vehículo).
func _snapshot() -> Dictionary:
	var out := {}
	for u in game.units.values():
		var c := TWUnit.new(u.id, u.side, u.t, u.pos, u.hp)
		c.crew = u.crew
		c.char_id = u.char_id
		c.veteran = u.veteran
		c.carrier = u.carrier
		out[u.id] = c
	return out


func _idle() -> void:
	while busy:
		await get_tree().process_frame


## Anima una acción ya aplicada a partir de sus sucesos: movimiento, disparos, daño, explosiones, capturas
## y cartas. Dura como mucho 3 s (sec. 9 del reglamento): si hay muchos sucesos, se acelera.
func _animate(a: Dictionary, evs: Array, pre: Dictionary, path: Array) -> void:
	busy = true
	var t_start := Time.get_ticks_msec()
	var est := minf(0.8, 0.13 * maxi(0, path.size() - 1))
	if a.kind == "dismount" or a.sub in ["board", "struct", "repair", "repair_turret", "sabotage", "hack", "barricade", "train"]:
		est += 0.4
	for e in evs:
		est += {"hit": 0.52, "kill": 0.42, "turret_fire": 0.52, "turret_hit": 0.52, "capture": 0.42, "card": 0.37}.get(e[0], 0.05)
	var base_speed: float = board.speed
	board.speed = base_speed * maxf(1.0, est / 2.6)          # margen para no pasar de 3 s
	var at := {}                                          # dónde está cada unidad durante la animación
	for id in pre:
		var u: TWUnit = pre[id]
		if u.pos != null:
			at[id] = u.pos
		elif u.carrier >= 0 and pre.has(u.carrier) and pre[u.carrier].pos != null:
			at[id] = pre[u.carrier].pos
	var mover: int = a.unit if path.size() > 1 else -1
	var statics := {}
	var ejected := []
	for e in evs:
		if e[0] == "kill" and e[1] != mover and pre.has(e[1]) and at.has(e[1]):
			statics[e[1]] = {"u": pre[e[1]], "c": board.center(at[e[1]]), "k": 1.0}
			board.ghosts.append(statics[e[1]])
		elif e[0] == "eject":
			board.hidden_units[e[1]] = true
			ejected.append(e[1])
	# 1. movimiento
	if mover >= 0:
		board.hidden_units[mover] = true
		sfx.play("move")
		await board.move_ghost(pre[mover], path)
		board.hidden_units.erase(mover)
		at[mover] = path[-1]
		for e in evs:
			if e[0] == "kill" and e[1] == mover:
				statics[mover] = {"u": pre[mover], "c": board.center(path[-1]), "k": 1.0}
				board.ghosts.append(statics[mover])
	if a.kind == "dismount":
		var v: TWUnit = pre[a.unit]
		var rid: int = v.char_id if a.sub == "char" else v.crew
		board.hidden_units[rid] = true
		sfx.play("select")
		await board.move_ghost(pre[rid], [v.pos, a.dest])
		board.hidden_units.erase(rid)
	elif a.kind == "activate" and a.sub == "board":
		await board.move_ghost(pre[a.unit], [at[a.unit], game.units[a.target].pos])
	elif a.kind == "produce":
		sfx.play("select")
		board.ring(board.center(a.dest), BoardView.SIDE_COLOR[game.current])
	elif a.kind == "activate":
		var tgt = a.target
		var col := {"repair": Color("6cff8a"), "repair_turret": Color("6cff8a"), "sabotage": Color("ff5050"),
			"hack": BoardView.SIDE_COLOR[game.current], "barricade": Color("b07a3c"), "train": Color("ffd84a")}
		if col.has(a.sub):
			var cell = tgt if tgt is Vector2i else (game.units[tgt].pos if tgt is int and game.units.has(tgt) else a.dest)
			if cell != null:
				sfx.play("card" if a.sub == "hack" else "select")
				board.ring(board.center(cell), col[a.sub])
				await board.wait(0.3)
		elif a.sub == "struct":
			sfx.play("boom")
			await board.boom(board.center(tgt))
	# 2. sucesos en orden
	for e in evs:
		match e[0]:
			"hit":
				if not at.has(e[2]):
					continue
				var to: Vector2 = board.center(at[e[2]])
				if e[1] >= 0 and at.has(e[1]):
					sfx.play("shot")
					await board.shot(board.center(at[e[1]]), to)
				else:
					sfx.play("shot", -4.0)
					await board.bomb(to)
				board.number(to, "-%d" % e[3])
				await board.wait(0.28)
			"kill":
				var pos: Vector2 = board.center(e[3]) if e[3] != null else (board.center(at[e[1]]) if at.has(e[1]) else Vector2.ZERO)
				if statics.has(e[1]):
					board.ghosts.erase(statics[e[1]])
				sfx.play("boom")
				await board.boom(pos, pre.get(e[1]))
			"eject":
				board.hidden_units.erase(e[1])
				board.ring(board.center(e[2]), Color.WHITE, 0.6, 0.35)
			"turret_fire", "turret_hit":
				var q: Vector2i = e[1] if e[0] == "turret_fire" else e[2]
				var shooter = q if e[0] == "turret_fire" else at.get(e[1])
				var target = at.get(e[2]) if e[0] == "turret_fire" else q
				if shooter == null or target == null:
					continue
				sfx.play("shot")
				await board.shot(board.center(shooter), board.center(target), Color("9fe3ff") if e[0] == "turret_fire" else Color("fff2a8"))
				board.number(board.center(target), "-%d" % e[3], Color("ff9a3c") if e[0] == "turret_hit" else Color("ff5050"))
				await board.wait(0.28)
			"capture":
				sfx.play("capture")
				board.ring(board.center(e[2]), BoardView.SIDE_COLOR[e[1]], 1.2, 0.6)
				board.flag(board.center(e[2]), e[1])
				board.number(board.center(e[2]), "¡Capturado!", BoardView.SIDE_COLOR[e[1]].lightened(0.4))
				await board.wait(0.4)
			"card":
				sfx.play("card")
				var c: String = e[2]
				var col: Color = Color("6fb7ff") if c in ["pem", "hackeo"] else (Color("ff9a3c") if c in ["aereo", "saturacion"] else BoardView.SIDE_COLOR[e[1]])
				if e[3] != null and c == "pem":
					board.pem(board.center(e[3]))
				elif e[3] != null:
					board.ring(board.center(e[3]), col, 1.6 if c in ["saturacion", "aereo"] else 1.0, 0.5)
				await board.wait(0.35)
	for id in ejected:
		board.hidden_units.erase(id)
	for gh in statics.values():
		board.ghosts.erase(gh)
	board.speed = base_speed
	anim_max = maxf(anim_max, (Time.get_ticks_msec() - t_start) / 1000.0 * base_speed)
	anim_count += 1
	busy = false
	_refresh()


func _report_events() -> void:
	for e in game.events:
		match e[0]:
			"kill":
				history.append("  %s destruido en %s" % [R.NAMES[e[2]], R.cell_name(e[3])])
			"capture":
				history.append("  %s captura %s" % [SIDE_NAME[e[1]], R.cell_name(e[2])])
			"turret_fire":
				history.append("  Torreta de %s dispara (%d de daño)" % [R.cell_name(e[1]), e[3]])
	game.events = []


func _on_end_turn() -> void:
	if game.winner != TWGame.NO_WINNER or busy or ending:
		return
	ending = true
	_do(TWGame.act("end"))
	await _idle()
	if game.winner == TWGame.NO_WINNER:
		game.start_turn()
		sfx.play("turn", -6.0)
		history.append("— Turno de la %s (ronda %d) —" % [SIDE_NAME[game.current], game.round])
		_turn_started()
		ending = false
		_refresh()
		if vs_ai and game.current == 1:
			await get_tree().create_timer(0.3).timeout
			_ai_turn()
	else:
		ending = false
		_refresh()


func _ai_turn() -> void:
	var guard := 0
	bots[1].begin_turn()
	while game.winner == TWGame.NO_WINNER and game.current == 1 and guard < 60:
		guard += 1
		var a: Dictionary = bots[1].choose()
		if a.kind == "end":
			break
		var where = a.dest if a.dest != null else (game.units[a.unit].pos if a.unit >= 0 else null)
		if where != null and not camera.is_cell_visible(where):      # la cámara sigue a la IA
			camera.center_on(where)
			await get_tree().create_timer(0.35).timeout
		_do(a)
		await _idle()
		await get_tree().create_timer(0.2 / board.speed).timeout
	_on_end_turn()


func _is_human(side: int) -> bool:
	return not vs_ai or side == 0


## Casilla del personaje del bando que juega (o que despliega); si no está, su cuartel general.
func _focus_cell():
	var g: TWGame = dep_preview if phase == "deploy" else game
	if g == null:
		return null
	var s: int = dep_side if phase == "deploy" else (game.current if _is_human(game.current) else 0)
	for u in g.units.values():
		if u.side == s and u.t == "C":
			var p = u.pos if u.pos != null else g.units[u.carrier].pos
			if p != null:
				return p
	return g.hq[s]


## Al empezar el turno de una persona: reloj a 25 s y cámara sobre su personaje.
func _turn_started() -> void:
	turn_left = TURN_TIME
	if _is_human(game.current):
		camera.center_on(_focus_cell())


## C13: 25 s por turno y después la reserva de la partida; con los dos agotados, el turno termina.
func _process(delta: float) -> void:
	if clock_label == null:
		return
	if phase != "play" or game == null or not clock_on or game.winner != TWGame.NO_WINNER or screen != null:
		clock_label.text = ""
		return
	var s := game.current
	if not _is_human(s):
		clock_label.text = ""
		return
	if busy or ending:                        # el reloj se para mientras se anima una acción
		return
	if turn_left > 0.0:
		turn_left = maxf(0.0, turn_left - delta)
	else:
		reserve[s] = maxf(0.0, reserve[s] - delta)
	var left: float = turn_left if turn_left > 0.0 else reserve[s]
	if left <= 5.0 and ceili(left) != last_tick:
		last_tick = ceili(left)
		sfx.play("tick")
	clock_label.text = ("%d s" if turn_left > 0.0 else "Reserva %d s") % ceili(left)
	clock_label.add_theme_color_override("font_color",
		Color("ff5a5a") if left <= 5.0 else (Color("ffb347") if left <= 10.0 or turn_left <= 0.0 else Color.WHITE))
	if turn_left <= 0.0 and reserve[s] <= 0.0:
		history.append("%s: se agota el tiempo." % SIDE_NAME[s].split(" ")[1])
		_reset_selection()
		_on_end_turn()


## Prueba de la interfaz: el bando Jade juega tocando la pantalla (clics simulados) con la IA
## y comprueba que cada toque produce la acción elegida; Ámbar juega con la IA. Termina al acabar la partida.
func _autoplay() -> void:
	var mismatches := 0
	var steps := 0
	var jade_turn := -1
	while game.winner == TWGame.NO_WINNER and steps < 3000:
		steps += 1
		if game.current == 1 or busy or ending:
			await get_tree().process_frame
			continue
		if game.turn != jade_turn:
			jade_turn = game.turn
			bots[0].begin_turn()
		var a: Dictionary = bots[0].choose()
		if a.kind == "end":
			await _on_end_turn()
			continue
		var before := game.log.size()
		_reset_selection()
		match a.kind:
			"activate":
				_on_cell(game.units[a.unit].pos)
				_on_cell(a.dest)
			"produce":
				_select_building(a.dest)
			"card":
				_start_card(a.sub)
				_on_cell(a.dest)
			"dismount":
				_on_cell(game.units[a.unit].pos)
				_start_dismount(a.sub)
				_on_cell(a.dest)
		if game.log.size() == before:
			for b in pending:
				if TWGame.action_key(b) == TWGame.action_key(a):
					_do(b)
					break
		if game.log.size() == before or TWGame.action_key(game.log[-1]) != TWGame.action_key(a):
			mismatches += 1
			print("La interfaz no reprodujo: ", TWGame.action_key(a))
			_do(a)
	await _idle()
	print("Autojuego terminado: %s, %s, %d acciones, %d discrepancias, %d animaciones, la más larga %.2f s" % [
		"empate" if game.winner < 0 else SIDE_NAME[game.winner], game.how, game.log.size(), mismatches, anim_count, anim_max])


func _demo(n: int) -> void:
	## Juega n turnos con la IA en ambos bandos (para capturas de pantalla y pruebas).
	for i in range(n):
		if game.winner != TWGame.NO_WINNER:
			break
		var guard := 0
		bots[game.current].begin_turn()
		while guard < 60:
			guard += 1
			var a: Dictionary = bots[game.current].choose()
			if a.kind == "end":
				break
			_do(a)
		_do(TWGame.act("end"))
		if game.winner == TWGame.NO_WINNER:
			game.start_turn()
	_reset_selection()


func _show_winner() -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	var banner := TextureRect.new()
	banner.texture = Art.tex("ui/victoria" if game.winner >= 0 else "ui/derrota")
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.custom_minimum_size = Vector2(560, 180)
	vb.add_child(banner)
	if game.winner >= 0:
		var flag := TextureRect.new()
		flag.texture = Art.tex("retratos/%s_personaje" % Art.SIDE[game.winner])
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.custom_minimum_size = Vector2(560, 150)
		vb.add_child(flag)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", FONT + 9)
	var how := {"dominio": "por dominio", "captura_CG": "capturando el cuartel general", "eliminacion": "por eliminación",
		"ronda_limite_edificios": "por edificios en la ronda 20", "ronda_limite_valor_destruido": "por valor destruido",
		"ronda_limite_valor_vivo": "por valor de las unidades vivas"}
	if game.winner < 0:
		l.text = "Empate"
	else:
		l.text = "Gana la %s %s" % [SIDE_NAME[game.winner], how.get(game.how, "")]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	vb.add_theme_constant_override("separation", 18)
	var b := Button.new()
	b.text = "Nueva partida"
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(_start_setup)
	vb.add_child(b)
	overlay_box.add_child(vb)
	overlay.visible = true


# ------------------------------------------------------------------ preparación y despliegue (sec. 3)
func _start_setup() -> void:
	overlay.visible = false
	first = randi() % 2                      # se sortea quién juega primero
	choices = [{}, {}]
	cells = [[], []]
	_show_setup(0, true)


func _show_setup(side: int, ask_rival: bool) -> void:
	phase = "setup"
	_clear_screen()
	var sc := SetupScreen.new()
	screen = sc
	add_child(sc)
	sc.setup(side, first, ask_rival)
	sc.done.connect(_on_setup_done.bind(side))


func _clear_screen() -> void:
	if screen != null:
		screen.queue_free()
		screen = null


## Pantalla para pasar el móvil al otro jugador sin que vea lo que ha elegido el primero.
func _pass_screen(text: String, next: Callable) -> void:
	_clear_screen()
	var sc := Control.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1e2328")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.add_child(center)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(600, 0)
	vb.add_theme_constant_override("separation", 20)
	center.add_child(vb)
	var logo := TextureRect.new()
	logo.texture = Art.tex("ui/logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(600, 220)
	vb.add_child(logo)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FONT + 6)
	vb.add_child(l)
	var b := Button.new()
	pass_button = b
	b.text = "Estoy listo"
	b.custom_minimum_size = Vector2(600, 56)
	b.pressed.connect(func():
		_clear_screen()
		next.call())
	vb.add_child(b)
	screen = sc
	add_child(sc)


## Orden: Jade elige; con dos jugadores, Ámbar elige y despliega, y después despliega Jade.
func _on_setup_done(army: Array, deck: Array, ai: bool, clock: bool, side: int) -> void:
	choices[side] = {"army": army, "deck": deck}
	_clear_screen()
	if side == 0:
		vs_ai = ai
		clock_on = clock
		if vs_ai:
			choices[1] = {"army": TWSetup.random_army(), "deck": TWSetup.random_deck()}
			cells[1] = _auto_all(1)
			_start_deploy(0)
		else:
			_pass_screen("Pásale el móvil a la Legión Ámbar para que prepare su ejército.", _show_setup.bind(1, false))
	else:
		_start_deploy(1)


func _preview(side: int, placed: Array) -> TWGame:
	var allowed := []
	var decks := []
	for s in [0, 1]:
		allowed.append(TWSetup.allowed_of(choices[s].get("army", [])))
		decks.append(choices[s].get("deck", []))
	var g := TWGame.new("Cuatro plazas", first, allowed, decks)
	for i in range(placed.size()):
		if placed[i] != null:
			TWSetup.place(g, side, choices[side].army[i], placed[i])
	return g


func _auto_all(side: int) -> Array:
	var n: int = choices[side].army.size()
	var empty := []
	empty.resize(n)
	var auto := TWSetup.auto_cells(_preview(side, empty), side, choices[side].army, range(n))
	var out := []
	for i in range(n):
		out.append(auto.get(i))
	return out


func _start_deploy(side: int) -> void:
	phase = "deploy"
	dep_side = side
	dep_cells = []
	dep_cells.resize(choices[side].army.size())
	dep_sel = 0
	_refresh_deploy()
	camera.center_on(dep_preview.hq[side], false)


func _unit_label(item: String) -> String:
	return R.NAMES[item[0]] + (" ★" if item.ends_with("*") else "")


func _refresh_deploy() -> void:
	var army: Array = choices[dep_side].army
	dep_preview = _preview(dep_side, dep_cells)
	dep_zone = TWSetup.deployment_zone(dep_preview, dep_side)
	board.game = dep_preview
	board.selected = -1
	board.marks = {}
	board.target_marks = {}
	if dep_sel >= 0:
		for p in dep_zone:
			if TWSetup.can_deploy(dep_preview, dep_side, army[dep_sel][0], p, dep_zone):
				board.marks[p] = Color(1, 1, 1, 0.3)
		if dep_cells[dep_sel] != null:
			board.target_marks[dep_cells[dep_sel]] = Color("ffd84a")
	board.queue_redraw()
	top_label.text = "Despliegue · %s · coloca tus unidades a 3 casillas o menos de tu CG o de tu cuartel" % SIDE_NAME[dep_side]
	for c in actions_box.get_children():
		c.queue_free()
	var left := dep_cells.count(null)
	info_label.text = ("Elige una unidad y toca una casilla resaltada. Toca una unidad ya colocada para moverla." +
		("\nFaltan %d unidades." % left if left > 0 else "\nTodas colocadas."))
	for i in range(army.size()):
		var where: String = "" if dep_cells[i] == null else " — " + R.cell_name(dep_cells[i])
		var b := Button.new()
		b.text = _unit_label(army[i]) + where
		b.icon = Art.unit(army[i][0], dep_side)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		SetupScreen.style_toggle(b, BoardView.SIDE_COLOR[dep_side])
		b.button_pressed = i == dep_sel
		b.custom_minimum_size = Vector2(PANEL_W, 48)
		b.pressed.connect(func():
			dep_sel = i
			_refresh_deploy())
		actions_box.add_child(b)
	_add_button("Colocar el resto automáticamente", _deploy_auto)
	_add_button("Quitar todas", _deploy_clear)
	var ready := Button.new()
	ready.text = "Listo"
	ready.custom_minimum_size = Vector2(PANEL_W, 48)
	ready.disabled = left > 0
	ready.pressed.connect(_deploy_done)
	actions_box.add_child(ready)
	for c in cards_box.get_children():
		c.queue_free()
	for c in choices[dep_side].deck:
		var l := Label.new()
		l.text = "· " + R.CARD_NAMES[c]
		cards_box.add_child(l)
	end_button.visible = false
	log_label.text = ""


func _deploy_cell(p: Vector2i) -> void:
	var j := dep_cells.find(p)
	if j >= 0:
		dep_sel = j
	elif dep_sel >= 0 and TWSetup.can_deploy(dep_preview, dep_side, choices[dep_side].army[dep_sel][0], p, dep_zone):
		dep_cells[dep_sel] = p
		dep_sel = dep_cells.find(null)
	_refresh_deploy()


func _deploy_auto() -> void:
	var todo := []
	for i in range(dep_cells.size()):
		if dep_cells[i] == null:
			todo.append(i)
	var auto := TWSetup.auto_cells(dep_preview, dep_side, choices[dep_side].army, todo)
	for i in auto:
		dep_cells[i] = auto[i]
	dep_sel = dep_cells.find(null)
	_refresh_deploy()


func _deploy_clear() -> void:
	dep_cells.fill(null)
	dep_sel = 0
	_refresh_deploy()


func _deploy_done() -> void:
	if dep_cells.has(null):
		return
	cells[dep_side] = dep_cells.duplicate()
	if dep_side == 1:
		phase = "between"
		_pass_screen("Pásale el móvil a la Brigada Jade para que despliegue.", _start_deploy.bind(0))
	else:
		_begin_play()


func _army_text(side: int) -> String:
	var parts := []
	for item in choices[side].army:
		parts.append(_unit_label(item))
	var cards := []
	for c in choices[side].deck:
		cards.append(R.CARD_NAMES[c])
	return "%s: %s · cartas: %s" % [SIDE_NAME[side], ", ".join(parts), ", ".join(cards)]


func _begin_play() -> void:
	game = TWSetup.build([choices[0].army, choices[1].army], [choices[0].deck, choices[1].deck], cells, first)
	board.game = game
	bots = [TWBot.new(game, 0, "normal", randi()), TWBot.new(game, 1, "normal", randi())]
	phase = "play"
	end_button.visible = true
	overlay.visible = false
	history = [_army_text(0), _army_text(1), "Sorteo: empieza la %s." % SIDE_NAME[first]]
	reserve = [RESERVE_TIME, RESERVE_TIME]
	_turn_started()
	if not _is_human(game.current):
		camera.center_on(_focus_cell(), false)
	_reset_selection()
	if vs_ai and game.current == 1:
		await get_tree().create_timer(0.3).timeout
		_ai_turn()


## Pruebas de la preparación pulsando los botones como lo haría un jugador.
## stage: setup (se queda en la pantalla), deploy (se queda a mitad del despliegue), play (empieza la partida)
## o hotseat (dos jugadores en el mismo móvil hasta empezar la partida).
func _setup_test(stage: String) -> void:
	await get_tree().process_frame
	var sc: Control = screen
	sc._on_preset("hacker4")
	sc._change("T", -1)
	sc._change("J", 1)
	sc._set_hero("J")
	for c in ["aereo", "marcha", "pem"]:
		sc.card_buttons[c].pressed.emit()
	if stage == "hotseat":
		sc.rival_buttons[1].pressed.emit()
	if stage == "clock":
		sc.clock_button.pressed.emit()
	if stage == "setup":
		return
	sc.continue_button.pressed.emit()
	if stage == "hotseat":
		pass_button.pressed.emit()                             # «Estoy listo»
		await get_tree().process_frame
		screen._on_preset("rapido4")
		screen._random_cards()
		screen.continue_button.pressed.emit()
		_deploy_auto()
		_deploy_done()
		pass_button.pressed.emit()
	_on_cell(board.marks.keys()[0])                          # coloca la primera unidad a mano
	_on_cell(board.marks.keys()[3])
	if stage == "deploy":
		return
	_deploy_auto()
	_deploy_done()
	if stage == "clock":
		await _clock_test()
		return
	var types := []
	for u in game.on_board(0):
		types.append(u.t + ("*" if u.char_id > 0 else ""))
	print("Preparación: fase %s, rival %s, Jade %s, cartas %s | Ámbar %s, cartas %s, empieza %d" % [
		phase, "IA" if vs_ai else "humano", ",".join(types), ",".join(game.decks[0]),
		",".join(choices[1].army), ",".join(game.decks[1]), first])
	if vs_ai and game.current == 1:
		var frames := 0
		while game.current == 1 and game.winner == TWGame.NO_WINNER and frames < 2000:
			frames += 1
			await get_tree().process_frame
		print("La IA abrió la partida: %d acciones, ahora juega la %s" % [game.log.size(), SIDE_NAME[game.current]])


## Con el reloj activado: agota los 25 s y casi toda la reserva, y comprueba que el turno pasa solo.
func _clock_test() -> void:
	while game.current != 0:
		await get_tree().process_frame
	var turn0 := game.turn
	await get_tree().create_timer(1.2).timeout
	var ticking: bool = turn_left < TURN_TIME and reserve[0] == RESERVE_TIME
	turn_left = 0.0
	reserve[0] = 0.8
	await get_tree().process_frame
	await get_tree().process_frame
	var shows: String = clock_label.text
	await get_tree().create_timer(1.5).timeout
	print("Reloj: activo %s, cuenta %s, muestra «%s», turno pasado %s, reserva %.1f, aviso %s" % [clock_on, ticking, shows,
		game.turn > turn0, reserve[0], history.any(func(h): return h.contains("se agota el tiempo"))])


## Captura a mitad de un ataque: juega sin animar hasta que Jade puede atacar y anima ese ataque.
## --anim-at=S fija el momento de la captura (segundos desde el inicio de la acción).
func _anim_shot(path: String, args: Array) -> void:
	var at_s := 0.95
	for a in args:
		if a.begins_with("--anim-at="):
			at_s = float(a.substr(10))
	anim = false
	var attack = null
	for i in range(60):
		if game.current == 0:
			for a in game.legal_actions():
				if a.kind == "activate" and a.sub == "attack" and a.dest != game.units[a.unit].pos:
					attack = a
					break
		if attack != null:
			break
		bots[game.current].begin_turn()
		var guard := 0
		while guard < 60:
			guard += 1
			var a: Dictionary = bots[game.current].choose()
			if a.kind == "end":
				break
			_do(a)
		_do(TWGame.act("end"))
		game.start_turn()
	_reset_selection()
	if attack == null:
		print("No se encontró un ataque")
		return
	camera.center_on(attack.dest, false)
	await get_tree().process_frame
	anim = true
	board.speed = 1.0
	_do(attack)
	await get_tree().create_timer(at_s).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	await _idle()
	print("Captura de animación: ", action_label_fallback(attack))
	get_tree().quit()
