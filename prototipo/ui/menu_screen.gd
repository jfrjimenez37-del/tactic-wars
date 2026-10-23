extends Control
## Menú principal: continuar la partida guardada, nueva partida y ajustes (sonido y animaciones).

signal continue_game
signal new_game
signal settings_changed(sound: bool, anim_mode: String)

const Art = preload("res://ui/art.gd")
const ANIM_MODES := [["normal", "Normales"], ["rapidas", "Rápidas"], ["no", "Sin animaciones"]]

var sound := true
var anim_mode := "normal"
var main_box: VBoxContainer
var settings_box: VBoxContainer
var sound_button: Button
var anim_buttons := []
var continue_button: Button


## saved: resumen de la partida guardada («Ronda 5/20 · contra la IA (Normal)») o "" si no hay.
func setup(saved: String, p_sound: bool, p_anim: String) -> void:
	sound = p_sound
	anim_mode = p_anim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1e2328")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art_bg := TextureRect.new()
	art_bg.texture = Art.tex("ui/fondo_menu")
	art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art_bg)
	var shade := ColorRect.new()                      # oscurece el centro para que se lean los botones
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var logo := TextureRect.new()
	logo.texture = Art.tex("ui/logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(560, 250)
	col.add_child(logo)

	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	col.add_child(main_box)
	continue_button = _button("Continuar partida" + ("\n" + saved if saved != "" else ""), func(): continue_game.emit())
	continue_button.visible = saved != ""
	continue_button.custom_minimum_size.y = 80
	main_box.add_child(continue_button)
	main_box.add_child(_button("Nueva partida", func(): new_game.emit()))
	main_box.add_child(_button("Ajustes", func(): _show_settings(true)))

	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 12)
	settings_box.visible = false
	col.add_child(settings_box)
	sound_button = _button("", _toggle_sound)
	settings_box.add_child(sound_button)
	var l := Label.new()
	l.text = "Animaciones"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_box.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	settings_box.add_child(row)
	for m in ANIM_MODES:
		var b := _button(m[1], _set_anim.bind(m[0]))
		b.custom_minimum_size = Vector2(178, 60)
		b.toggle_mode = true
		row.add_child(b)
		anim_buttons.append(b)
	settings_box.add_child(_button("Volver", func(): _show_settings(false)))
	_update()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func _show_settings(on: bool) -> void:
	main_box.visible = not on
	settings_box.visible = on


func _toggle_sound() -> void:
	sound = not sound
	_update()
	settings_changed.emit(sound, anim_mode)


func _set_anim(m: String) -> void:
	anim_mode = m
	_update()
	settings_changed.emit(sound, anim_mode)


func _update() -> void:
	sound_button.text = "Sonido: " + ("sí" if sound else "no")
	for i in range(ANIM_MODES.size()):
		anim_buttons[i].button_pressed = ANIM_MODES[i][0] == anim_mode
