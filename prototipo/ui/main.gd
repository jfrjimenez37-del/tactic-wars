extends Control
## Pantalla de partida: tablero, barra superior, panel de acciones y cartas.
## Modo de juego: Jade (humano) contra Ámbar (humano o IA).

const R = preload("res://core/tw_rules.gd")
const BoardView = preload("res://ui/board_view.gd")
const SetupScreen = preload("res://ui/setup_screen.gd")
const SIDE_NAME := ["Brigada Jade", "Legión Ámbar"]

var game: TWGame
var board: Control
var top_label: Label
var info_label: Label
var actions_box: VBoxContainer
var cards_box: VBoxContainer
var log_label: Label
var end_button: Button
var overlay: PanelContainer
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
		if a.begins_with("--shot="):
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(a.substr(7))
			get_tree().quit()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1e2328")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	top_label = Label.new()
	top_label.position = Vector2(16, 12)
	top_label.add_theme_font_size_override("font_size", 20)
	add_child(top_label)
	board = BoardView.new()
	board.position = Vector2(16, 64)
	board.size = Vector2(R.W * BoardView.S, R.H * BoardView.S)
	board.cell_clicked.connect(_on_cell)
	add_child(board)
	var panel := PanelContainer.new()
	panel.position = Vector2(896, 56)
	panel.size = Vector2(368, 650)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 640)
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(340, 0)
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(340, 0)
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
	end_button = Button.new()
	end_button.text = "Terminar turno"
	end_button.custom_minimum_size = Vector2(340, 48)
	end_button.pressed.connect(_on_end_turn)
	vb.add_child(end_button)
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(340, 0)
	log_label.add_theme_font_size_override("font_size", 13)
	vb.add_child(log_label)
	overlay = PanelContainer.new()
	overlay.position = Vector2(300, 260)
	overlay.size = Vector2(560, 180)
	overlay.visible = false
	add_child(overlay)


## Partida rápida con ejércitos fijos (para las pruebas automáticas).
func _new_game() -> void:
	game = TWSetup.new_game("equilibrado4", "hacker4", ["aereo", "reparacion", "torreta"],
		["hackeo", "misiles", "pem"], 0)
	board.game = game
	bots = [TWBot.new(game, 0, "normal", randi()), TWBot.new(game, 1, "normal", randi())]
	history = ["Empieza la partida. Juega la " + SIDE_NAME[game.current] + "."]
	overlay.visible = false
	_reset_selection()


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
	top_label.text = "Ronda %d/%d · Turno: %s · PM %d (guardables %d) · Suministros Jade %d | Ámbar %d · Edificios %d-%d" % [
		mini(game.round, R.ROUNDS), R.ROUNDS, SIDE_NAME[s], game.pm, pr[1], game.supplies[0], game.supplies[1],
		game.buildings_of(0), game.buildings_of(1)]
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
	end_button.disabled = game.winner != TWGame.NO_WINNER
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
	b.custom_minimum_size = Vector2(340, 40)
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
			status = " · lista en %d rondas" % int(ceil((ready_turn - game.turn) / 2.0))
		b.text = "%s (%d PM)%s" % [R.CARD_NAMES[c], d[0], status]
		b.custom_minimum_size = Vector2(340, 40)
		b.disabled = not game.card_available(c) or game.winner != TWGame.NO_WINNER
		b.pressed.connect(_start_card.bind(c))
		cards_box.add_child(b)


# ------------------------------------------------------------------ interacción
func _on_cell(p: Vector2i) -> void:
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
	game.events = []
	game.apply(a)
	history.append("%s: %s" % [who, label])
	_report_events()
	_reset_selection()


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
	if game.winner != TWGame.NO_WINNER:
		return
	_do(TWGame.act("end"))
	if game.winner == TWGame.NO_WINNER:
		game.start_turn()
		history.append("— Turno de la %s (ronda %d) —" % [SIDE_NAME[game.current], game.round])
		_refresh()
		if vs_ai and game.current == 1:
			await get_tree().create_timer(0.3).timeout
			_ai_turn()


func _ai_turn() -> void:
	var guard := 0
	bots[1].begin_turn()
	while game.winner == TWGame.NO_WINNER and game.current == 1 and guard < 60:
		guard += 1
		var a: Dictionary = bots[1].choose()
		if a.kind == "end":
			break
		_do(a)
		await get_tree().create_timer(0.15).timeout
	_on_end_turn()


## Prueba de la interfaz: el bando Jade juega tocando la pantalla (clics simulados) con la IA
## y comprueba que cada toque produce la acción elegida; Ámbar juega con la IA. Termina al acabar la partida.
func _autoplay() -> void:
	var mismatches := 0
	var steps := 0
	var jade_turn := -1
	while game.winner == TWGame.NO_WINNER and steps < 3000:
		steps += 1
		if game.current == 1:
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
	print("Autojuego terminado: %s, %s, %d acciones, %d discrepancias" % [
		"empate" if game.winner < 0 else SIDE_NAME[game.winner], game.how, game.log.size(), mismatches])


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
	for c in overlay.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 26)
	var how := {"dominio": "por dominio", "captura_CG": "capturando el cuartel general", "eliminacion": "por eliminación",
		"ronda_limite_edificios": "por edificios en la ronda 20", "ronda_limite_valor_destruido": "por valor destruido",
		"ronda_limite_valor_vivo": "por valor de las unidades vivas"}
	if game.winner < 0:
		l.text = "Empate"
	else:
		l.text = "Gana la %s %s" % [SIDE_NAME[game.winner], how.get(game.how, "")]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	vb.add_child(l)
	var b := Button.new()
	b.text = "Nueva partida"
	b.pressed.connect(_start_setup)
	vb.add_child(b)
	overlay.add_child(vb)
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
	var vb := VBoxContainer.new()
	vb.position = Vector2(340, 260)
	vb.custom_minimum_size = Vector2(600, 0)
	vb.add_theme_constant_override("separation", 20)
	sc.add_child(vb)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	vb.add_child(l)
	var b := Button.new()
	b.text = "Estoy listo"
	b.custom_minimum_size = Vector2(600, 56)
	b.pressed.connect(func():
		_clear_screen()
		next.call())
	vb.add_child(b)
	screen = sc
	add_child(sc)


## Orden: Jade elige; con dos jugadores, Ámbar elige y despliega, y después despliega Jade.
func _on_setup_done(army: Array, deck: Array, ai: bool, side: int) -> void:
	choices[side] = {"army": army, "deck": deck}
	_clear_screen()
	if side == 0:
		vs_ai = ai
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
		b.toggle_mode = true
		SetupScreen.style_toggle(b, BoardView.SIDE_COLOR[dep_side])
		b.button_pressed = i == dep_sel
		b.custom_minimum_size = Vector2(340, 36)
		b.pressed.connect(func():
			dep_sel = i
			_refresh_deploy())
		actions_box.add_child(b)
	_add_button("Colocar el resto automáticamente", _deploy_auto)
	_add_button("Quitar todas", _deploy_clear)
	var ready := Button.new()
	ready.text = "Listo"
	ready.custom_minimum_size = Vector2(340, 48)
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
	if stage == "setup":
		return
	sc.continue_button.pressed.emit()
	if stage == "hotseat":
		screen.get_child(1).get_child(1).pressed.emit()        # «Estoy listo»
		await get_tree().process_frame
		screen._on_preset("rapido4")
		screen._random_cards()
		screen.continue_button.pressed.emit()
		_deploy_auto()
		_deploy_done()
		screen.get_child(1).get_child(1).pressed.emit()
	_on_cell(board.marks.keys()[0])                          # coloca la primera unidad a mano
	_on_cell(board.marks.keys()[3])
	if stage == "deploy":
		return
	_deploy_auto()
	_deploy_done()
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
