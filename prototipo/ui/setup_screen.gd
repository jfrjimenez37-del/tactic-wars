extends Control
## Pantalla de preparación (sec. 3 del reglamento): cada jugador elige en secreto 4 equipos, 2 tropas a pie,
## el equipo en el que empieza su personaje y sus 3 cartas. Emite done al pulsar Continuar.

signal done(army: Array, deck: Array, vs_ai: bool)

const R = preload("res://core/tw_rules.gd")
const SIDE_NAME := ["Brigada Jade", "Legión Ámbar"]
const SIDE_COLOR := [Color("2fa36b"), Color("e39b2d")]
const VEHICLE_TYPES := ["T", "J", "R"]
const FOOT_TYPES := ["F", "A", "I", "K"]
const N_VEHICLES := 4
const N_FOOT := 2
const PRESET_NAMES := {"equilibrado4": "Equilibrado", "blindado4": "Blindado", "artilleria4": "Artillería",
	"rapido4": "Rápido", "infanteria4": "Infantería", "ingenieros4": "Ingenieros", "hacker4": "Hacker"}
const SHORT := {"T": "Tanque", "J": "Jeep", "R": "Artillería", "F": "Fusilero", "A": "Antitanque",
	"I": "Ingeniero", "K": "Hacker"}
const CARD_TEXT := {
	"marcha": "Una unidad que ya actuó vuelve a moverse, sin atacar.",
	"reparacion": "+3 PV a un vehículo propio.",
	"pem": "En una zona de 3×3, las unidades enemigas no actúan en su siguiente turno y las torretas ajenas dejan de disparar.",
	"torreta": "Torreta de 6 PV, alcance 1–2 y 2 de daño, en una casilla vacía junto a un edificio propio.",
	"refuerzo": "Una tropa a pie de las elegidas aparece en tu cuartel general.",
	"hackeo": "Una torreta enemiga o neutral deja de disparar hasta el final de tu siguiente turno.",
	"aereo": "4 de daño a la unidad enemiga de una casilla y 2 a las unidades enemigas contiguas.",
	"misiles": "Torreta de 5 PV, alcance 2–4 y 3 de daño, junto a un edificio propio.",
	"saturacion": "2 de daño a las unidades enemigas de una zona de 3×3.",
	"paracaidistas": "Un fusilero aparece en una casilla vacía sin enemigos al lado.",
}

var side := 0
var ask_rival := true
var vs_ai := true
var counts := {}
var hero := "T"
var deck := []

var count_labels := {}
var minus_buttons := {}
var plus_buttons := {}
var hero_box: HBoxContainer
var card_buttons := {}
var rival_buttons := []
var status_label: Label
var continue_button: Button


## first: quién ha salido en el sorteo para jugar primero (se muestra arriba).
func setup(p_side: int, first: int, p_ask_rival: bool) -> void:
	side = p_side
	ask_rival = p_ask_rival
	_load_preset("equilibrado4")
	_build(first)
	_update()


func _load_preset(key: String) -> void:
	counts = {}
	for t in VEHICLE_TYPES + FOOT_TYPES:
		counts[t] = 0
	for item in R.ARMIES[key]:
		counts[item[0]] += 1
		if item.ends_with("*"):
			hero = item[0]


## El ejército en el formato del motor: «T*» es el equipo que lleva al personaje.
func army() -> Array:
	var out := []
	for t in VEHICLE_TYPES:
		for i in range(counts[t]):
			out.append(t + ("*" if t == hero and i == 0 else ""))
	for t in FOOT_TYPES:
		for i in range(counts[t]):
			out.append(t)
	return out


func is_valid() -> bool:
	return _total(VEHICLE_TYPES) == N_VEHICLES and _total(FOOT_TYPES) == N_FOOT and counts[hero] > 0 \
		and deck.size() == 3


func _total(types: Array) -> int:
	var n := 0
	for t in types:
		n += counts[t]
	return n


# ------------------------------------------------------------------ construcción
## wrap > 0: ancho fijo con ajuste de línea.
func _label(text: String, size := 16, color := Color.WHITE, wrap := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap, 0)
	return l


## Parte un texto en líneas de como mucho n caracteres (los botones no ajustan bien solos).
static func _wrap(text: String, n: int) -> String:
	var lines := []
	var cur := ""
	for word in text.split(" "):
		if cur != "" and cur.length() + 1 + word.length() > n:
			lines.append(cur)
			cur = word
		else:
			cur = word if cur == "" else cur + " " + word
	lines.append(cur)
	return "\n".join(lines)


func _button(text: String, cb: Callable, min_size := Vector2(0, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(cb)
	return b


## Botón que se queda marcado (con el color del bando) mientras está elegido.
func _toggle(b: Button) -> Button:
	b.toggle_mode = true
	style_toggle(b, SIDE_COLOR[side])
	return b


static func style_toggle(b: Button, col: Color) -> void:
	for st in ["pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = col.darkened(0.35)
		box.border_color = col
		box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(st, box)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


func _build(first: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1e2328")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# cabecera: bando, sorteo y rival
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	var title := _label("Preparación · " + SIDE_NAME[side], 24, SIDE_COLOR[side])
	head.add_child(title)
	var draw := _label("Sorteo: juega primero la " + SIDE_NAME[first], 16, Color("c8c8c8"))
	draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(draw)
	if ask_rival:
		for opt in [[true, "Contra la IA"], [false, "2 jugadores (este móvil)"]]:
			var b := _toggle(_button(opt[1], _set_rival.bind(opt[0]), Vector2(200, 40)))
			head.add_child(b)
			rival_buttons.append(b)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# columna 1: ejércitos recomendados
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size = Vector2(290, 0)
	c1.add_theme_constant_override("separation", 6)
	cols.add_child(c1)
	c1.add_child(_label("Ejércitos recomendados", 18))
	for key in PRESET_NAMES:
		var parts := []
		for item in R.ARMIES[key]:
			parts.append(SHORT[item[0]] + ("★" if item.ends_with("*") else ""))
		var b := _button("%s\n%s" % [PRESET_NAMES[key], _wrap(", ".join(parts), 40)], _on_preset.bind(key), Vector2(290, 0))
		b.add_theme_font_size_override("font_size", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		c1.add_child(b)

	# columna 2: composición y personaje
	var c2 := VBoxContainer.new()
	c2.custom_minimum_size = Vector2(400, 0)
	c2.add_theme_constant_override("separation", 4)
	cols.add_child(c2)
	c2.add_child(_label("Equipos (%d)" % N_VEHICLES, 18))
	for t in VEHICLE_TYPES:
		c2.add_child(_count_row(t))
	c2.add_child(_label("Tropas a pie (%d)" % N_FOOT, 18))
	for t in FOOT_TYPES:
		c2.add_child(_count_row(t))
	c2.add_child(_label("El fusilero y el personaje capturan 2 puntos por turno; las demás tropas, 1.", 13, Color("b0b0b0"), 400))
	c2.add_child(_label("Personaje (4 PV, mov 3). Empieza dentro de:", 18))
	hero_box = HBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 8)
	c2.add_child(hero_box)
	c2.add_child(_label("Si lo destruyen, el rival gana %d suministros." % R.CHAR_BOUNTY, 13, Color("b0b0b0")))

	# columna 3: cartas
	var c3 := VBoxContainer.new()
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c3.add_theme_constant_override("separation", 6)
	cols.add_child(c3)
	var ch := HBoxContainer.new()
	c3.add_child(ch)
	var cl := _label("Cartas (elige 3)", 18)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cl)
	ch.add_child(_button("Al azar", _random_cards, Vector2(110, 34)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c3.add_child(scroll)
	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 4)
	scroll.add_child(cards)
	for c in R.CARDS:
		var d: Array = R.CARDS[c]
		var b := _button("%s · %d PM · desde la ronda %d · recarga %d\n%s" % [R.CARD_NAMES[c], d[0], d[2], d[1],
			_wrap(CARD_TEXT[c], 66)], _on_card.bind(c), Vector2(0, 0))
		_toggle(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		cards.add_child(b)
		card_buttons[c] = b

	# pie: estado y continuar
	var foot := HBoxContainer.new()
	root.add_child(foot)
	status_label = _label("", 16)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(status_label)
	continue_button = _button("Continuar al despliegue", _on_continue, Vector2(280, 48))
	foot.add_child(continue_button)


func _count_row(t: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var u: Array = R.UNIT[t]
	var name := _label(R.NAMES[t], 16)
	name.custom_minimum_size = Vector2(130, 0)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var stats := _label("%d PV · mov %d · %d sum." % [u[2], u[3], u[7]], 12, Color("b0b0b0"))
	stats.custom_minimum_size = Vector2(140, 0)
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stats)
	var minus := _button("−", _change.bind(t, -1), Vector2(44, 36))
	row.add_child(minus)
	var n := _label("0", 18)
	n.custom_minimum_size = Vector2(28, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	var plus := _button("+", _change.bind(t, 1), Vector2(44, 36))
	row.add_child(plus)
	count_labels[t] = n
	minus_buttons[t] = minus
	plus_buttons[t] = plus
	return row


# ------------------------------------------------------------------ interacción
func _set_rival(ai: bool) -> void:
	vs_ai = ai
	_update()


func _on_preset(key: String) -> void:
	_load_preset(key)
	_update()


func _change(t: String, delta: int) -> void:
	var group: Array = VEHICLE_TYPES if VEHICLE_TYPES.has(t) else FOOT_TYPES
	var cap := N_VEHICLES if group == VEHICLE_TYPES else N_FOOT
	if delta > 0 and _total(group) >= cap:
		return
	counts[t] = maxi(0, counts[t] + delta)
	if counts[hero] == 0:                     # el personaje pasa al primer equipo que quede
		for v in VEHICLE_TYPES:
			if counts[v] > 0:
				hero = v
				break
	_update()


func _set_hero(t: String) -> void:
	hero = t
	_update()


func _on_card(c: String) -> void:
	if deck.has(c):
		deck.erase(c)
	elif deck.size() < 3:
		deck.append(c)
	_update()


func _random_cards() -> void:
	deck = TWSetup.random_deck()
	_update()


func _on_continue() -> void:
	if is_valid():
		var d := deck.duplicate()
		d.sort()
		done.emit(army(), d, vs_ai)


func _update() -> void:
	for i in range(rival_buttons.size()):
		rival_buttons[i].button_pressed = (i == 0) == vs_ai
	for t in counts:
		count_labels[t].text = str(counts[t])
		var group: Array = VEHICLE_TYPES if VEHICLE_TYPES.has(t) else FOOT_TYPES
		var cap := N_VEHICLES if group == VEHICLE_TYPES else N_FOOT
		minus_buttons[t].disabled = counts[t] == 0
		plus_buttons[t].disabled = _total(group) >= cap
	for c in hero_box.get_children():
		c.queue_free()
	for t in VEHICLE_TYPES:
		if counts[t] > 0:
			var b := _toggle(_button(R.NAMES[t], _set_hero.bind(t), Vector2(128, 40)))
			b.button_pressed = t == hero
			hero_box.add_child(b)
	for c in card_buttons:
		card_buttons[c].button_pressed = deck.has(c)
		card_buttons[c].disabled = not deck.has(c) and deck.size() >= 3
	var missing := []
	var nv := N_VEHICLES - _total(VEHICLE_TYPES)
	var nf := N_FOOT - _total(FOOT_TYPES)
	if nv > 0:
		missing.append("%d equipo%s" % [nv, "s" if nv > 1 else ""])
	if nf > 0:
		missing.append("%d tropa%s a pie" % [nf, "s" if nf > 1 else ""])
	if deck.size() < 3:
		missing.append("%d carta%s" % [3 - deck.size(), "s" if 3 - deck.size() > 1 else ""])
	if missing.is_empty():
		status_label.text = "Listo. Al continuar colocarás tus unidades en el tablero."
	else:
		status_label.text = "Falta elegir: " + ", ".join(missing) + "."
	continue_button.disabled = not is_valid()
