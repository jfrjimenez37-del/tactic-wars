extends Control
## Ventana sobre el tablero: se arrastra con un dedo, se amplía con dos (o con la rueda del ratón) y se
## puede centrar en una casilla. Un toque sin arrastrar elige la casilla (emite cell_clicked).

signal cell_clicked(cell: Vector2i)

const R = preload("res://core/tw_rules.gd")
const BoardView = preload("res://ui/board_view.gd")
const DEFAULT_ZOOM := 1.45
const MAX_ZOOM := 2.5
const DRAG_THRESHOLD := 14.0

var board: Control
var zoom := DEFAULT_ZOOM
var touches := {}              # dedo -> posición, para ampliar con dos dedos
var pinch_dist := 0.0
var gesture := false           # hubo arrastre o pellizco desde que se apoyó el dedo: no es un toque
var pressing := false
var press_pos := Vector2.ZERO
var tween: Tween
var buttons: HBoxContainer
var on_focus: Callable         # lo pone la pantalla de partida: casilla del personaje del bando que juega


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = BoardView.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.size = board_size()
	add_child(board)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)
	for b in [["−", func(): zoom_at(zoom / 1.25, size / 2)], ["+", func(): zoom_at(zoom * 1.25, size / 2)],
			["Mapa", toggle_map], ["★", func(): if on_focus.is_valid(): center_on(on_focus.call())]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(64, 56)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.1, 0.12, 0.14, 0.8)
		box.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", box)
		buttons.add_child(btn)
	resized.connect(_on_resized)


func board_size() -> Vector2:
	return Vector2(R.W, R.H) * BoardView.S


func fit_zoom() -> float:
	var bs := board_size()
	return minf(size.x / bs.x, size.y / bs.y)


func _on_resized() -> void:
	buttons.position = Vector2(size.x - buttons.get_combined_minimum_size().x - 8, 8)
	zoom = clampf(zoom, fit_zoom(), MAX_ZOOM)
	board.scale = Vector2(zoom, zoom)
	board.position = _clamped(board.position)


## Posición del tablero que no deja huecos a los lados (o lo centra si cabe entero).
func _clamped(p: Vector2) -> Vector2:
	var bs := board_size() * zoom
	var out := p
	out.x = (size.x - bs.x) / 2 if bs.x <= size.x else clampf(p.x, size.x - bs.x, 0)
	out.y = (size.y - bs.y) / 2 if bs.y <= size.y else clampf(p.y, size.y - bs.y, 0)
	return out


func _stop_tween() -> void:
	if tween != null and tween.is_running():
		tween.kill()


func zoom_at(new_zoom: float, pivot: Vector2) -> void:
	_stop_tween()
	new_zoom = clampf(new_zoom, fit_zoom(), MAX_ZOOM)
	var local := (pivot - board.position) / zoom
	zoom = new_zoom
	board.scale = Vector2(zoom, zoom)
	board.position = _clamped(pivot - local * zoom)


## Alterna entre ver el mapa entero y la vista ampliada.
func toggle_map() -> void:
	if zoom > fit_zoom() + 0.01:
		zoom_at(fit_zoom(), size / 2)
	else:
		zoom_at(DEFAULT_ZOOM, size / 2)
		if on_focus.is_valid():
			center_on(on_focus.call(), false)


func center_on(cell, animate := true) -> void:
	if cell == null:
		return
	_stop_tween()
	var target := _clamped(size / 2 - board.cell_rect(cell).get_center() * zoom)
	if animate and is_inside_tree():
		tween = create_tween()
		tween.tween_property(board, "position", target, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		board.position = target


## La casilla se ve entera dentro de la ventana (con un pequeño margen).
func is_cell_visible(cell: Vector2i) -> bool:
	var r: Rect2 = board.cell_rect(cell)
	var view := Rect2(-board.position / zoom, size / zoom).grow(-BoardView.S * 0.25)
	return view.encloses(r)


func cell_at(local: Vector2):
	var p := (local - board.position) / zoom
	var c := int(floor(p.x / BoardView.S))
	var r := R.H - int(floor(p.y / BoardView.S))
	if c >= 0 and c < R.W and r >= 1 and r <= R.H:
		return Vector2i(c, r)
	return null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() >= 2:
			gesture = true
			var pts := touches.values()
			pinch_dist = pts[0].distance_to(pts[1])
		return
	if event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			var pts := touches.values()
			var d: float = pts[0].distance_to(pts[1])
			if pinch_dist > 0.0:
				zoom_at(zoom * d / pinch_dist, (pts[0] + pts[1]) / 2)
			pinch_dist = d
		return
	if event is InputEventMagnifyGesture:
		zoom_at(zoom * event.factor, event.position)
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(zoom * 1.1, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(zoom / 1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				gesture = false
				press_pos = event.position
			else:
				if pressing and not gesture:
					var cell = cell_at(event.position)
					if cell != null:
						cell_clicked.emit(cell)
				pressing = false
		accept_event()
	elif event is InputEventMouseMotion and pressing:
		if not gesture and event.position.distance_to(press_pos) > DRAG_THRESHOLD:
			gesture = true
		if gesture and touches.size() < 2:
			_stop_tween()
			board.position = _clamped(board.position + event.relative)
		accept_event()
