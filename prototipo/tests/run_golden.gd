extends SceneTree
## Vuelve a jugar las partidas de referencia del simulador de Python y comprueba que el motor de Godot
## acepta cada acción como legal y llega exactamente al mismo estado al final de cada turno.
## Uso:  godot --headless --path . --script res://tests/run_golden.gd

const R = preload("res://core/tw_rules.gd")


func _init() -> void:
	var dir := DirAccess.open("res://tests/golden")
	if dir == null:
		print("No hay partidas de referencia en res://tests/golden")
		quit(1)
		return
	var files := []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		var err := _run_file("res://tests/golden/" + f)
		if err == "":
			print("OK     ", f)
		else:
			failed += 1
			print("FALLO  ", f, "\n", err)
	print("%d partidas, %d fallos, %.1f s" % [files.size(), failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 else 0)


func _parse_action(e: Array) -> Dictionary:
	var kind: String = e[1]
	var unit := -1 if e[2] == null else int(e[2])
	var dest = null if e[3] == null else R.cell(e[3])
	var sub: String = e[4]
	var target = e[5]
	if target != null:
		if TWGame.CELL_SUBS.has(sub):
			target = R.cell(target)
		elif kind == "activate" and sub in ["attack", "repair", "board", "hack"]:
			target = int(target)
		else:
			target = str(target)
	return TWGame.act(kind, unit, dest, sub, target)


func _diff(expected: String, got: String) -> String:
	var a := expected.split("\n")
	var b := got.split("\n")
	for i in range(maxi(a.size(), b.size())):
		var x: String = a[i] if i < a.size() else "<nada>"
		var y: String = b[i] if i < b.size() else "<nada>"
		if x != y:
			return "  línea %d\n    Python: %s\n    Godot:  %s" % [i + 1, x, y]
	return ""


## Compara la lista completa de acciones legales al inicio del turno (número y huella SHA-1).
func _check_legal(g: TWGame, data: Dictionary, i: int) -> String:
	var keys := []
	for a in g.legal_actions():
		keys.append(TWGame.action_key(a))
	keys.sort()
	var exp: Array = data.legal[i]
	if keys.size() != int(exp[0]) or "\n".join(keys).sha1_text() != exp[1]:
		return "acciones legales distintas al inicio del turno %d: Python %d, Godot %d" % [i, int(exp[0]), keys.size()]
	return ""


func _run_file(path: String) -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var g := TWGame.new(data.map, int(data.first), data.allowed, data.decks)
	for st in data.setup:
		if st[0] == "unit":
			g.add_unit(int(st[1]), st[2], R.cell(st[3]), bool(st[4]))
		else:
			g.add_char(g.units[int(st[1])])
	var d := _diff(data.initial, g.canonical())
	if d != "":
		return "estado inicial distinto\n" + d
	g.start_turn()
	var lt := 0
	d = _check_legal(g, data, lt)
	if d != "":
		return d
	lt += 1
	var cp := 0
	var n := 0
	for e in data.log:
		var a := _parse_action(e)
		n += 1
		if not g.is_legal(a):
			return "acción %d ilegal en Godot: %s" % [n, TWGame.action_key(a)]
		g.apply(a, false)
		if a.kind == "end":
			d = _diff(data.checkpoints[cp], g.canonical())
			if d != "":
				return "estado distinto al final del turno %d (acción %d)\n%s" % [cp, n, d]
			cp += 1
			if g.winner == TWGame.NO_WINNER:
				g.start_turn()
				if g.winner == TWGame.NO_WINNER:
					d = _check_legal(g, data, lt)
					if d != "":
						return d
					lt += 1
	d = _diff(data.final, g.canonical())
	if d != "":
		return "estado final distinto\n" + d
	return ""
