extends SceneTree
## Prueba de la cámara del tablero con eventos simulados: un toque elige casilla, arrastrar mueve el
## tablero sin elegir nada y pellizcar con dos dedos cambia el zoom.
## Uso:  godot --headless --path . --script res://tests/run_camera.gd

const BoardCamera = preload("res://ui/board_camera.gd")

var clicked := []


func _mouse(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	return e


func _motion(pos: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e


func _touch(i: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	return e


func _drag(i: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	return e


func _init() -> void:
	var cam = BoardCamera.new()
	cam.size = Vector2(900, 640)
	root.add_child(cam)
	await process_frame
	cam.board.game = TWSetup.new_game("equilibrado4", "hacker4", [], [], 0)
	cam._on_resized()
	cam.cell_clicked.connect(func(c): clicked.append(c))
	var fails := 0
	# 1. toque: elige la casilla que hay debajo
	cam.center_on(Vector2i(5, 4), false)
	var p: Vector2 = cam.board.position + cam.board.cell_rect(Vector2i(5, 4)).get_center() * cam.zoom
	cam._gui_input(_mouse(p, true))
	cam._gui_input(_mouse(p, false))
	if clicked != [Vector2i(5, 4)]:
		fails += 1
		print("FALLO toque: ", clicked)
	# 2. arrastre: mueve el tablero y no elige casilla
	clicked.clear()
	var before: Vector2 = cam.board.position
	cam._gui_input(_mouse(Vector2(450, 300), true))
	for k in range(10):
		cam._gui_input(_motion(Vector2(450 - k * 10, 300), Vector2(-10, 0)))
	cam._gui_input(_mouse(Vector2(350, 300), false))
	if not clicked.is_empty() or cam.board.position.x >= before.x:
		fails += 1
		print("FALLO arrastre: ", clicked, " ", before, " -> ", cam.board.position)
	# 3. pellizco: separar los dedos amplía, juntarlos reduce (hasta ver el mapa entero)
	var z0: float = cam.zoom
	cam._gui_input(_touch(0, Vector2(400, 300), true))
	cam._gui_input(_touch(1, Vector2(500, 300), true))
	cam._gui_input(_drag(1, Vector2(600, 300)))
	var z1: float = cam.zoom
	for k in range(20):
		cam._gui_input(_drag(1, Vector2(590 - k * 9, 300)))
	var z2: float = cam.zoom
	cam._gui_input(_touch(1, Vector2(420, 300), false))
	cam._gui_input(_touch(0, Vector2(400, 300), false))
	cam._gui_input(_mouse(Vector2(400, 300), false))
	if not (z1 > z0 and z2 < z1 and absf(z2 - cam.fit_zoom()) < 0.01) or not clicked.is_empty():
		fails += 1
		print("FALLO pellizco: ", z0, " ", z1, " ", z2, " ajuste ", cam.fit_zoom(), " ", clicked)
	# 4. botón Mapa: alterna mapa entero / vista ampliada; el tablero nunca deja huecos
	cam.zoom_at(BoardCamera.DEFAULT_ZOOM, cam.size / 2)
	cam.toggle_map()
	var full: bool = absf(cam.zoom - cam.fit_zoom()) < 0.01
	cam.toggle_map()
	if not full or absf(cam.zoom - BoardCamera.DEFAULT_ZOOM) > 0.01:
		fails += 1
		print("FALLO botón Mapa")
	print("Cámara: %s (zoom %.2f, ajuste %.2f)" % ["OK" if fails == 0 else "%d fallos" % fails, cam.zoom, cam.fit_zoom()])
	quit(1 if fails > 0 else 0)
