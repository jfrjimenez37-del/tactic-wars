extends SceneTree
## Comprueba que la IA de Godot (TWBot) juega exactamente las mismas partidas que HeuristicBot del
## simulador con el generador LCG: mismas acciones, en el mismo orden, y el mismo estado final.
## Uso:  godot --headless --path . --script res://tests/run_bots.gd

const R = preload("res://core/tw_rules.gd")


func _init() -> void:
	var files := []
	for f in DirAccess.open("res://tests/bot_golden").get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		var err := _run_file("res://tests/bot_golden/" + f)
		if err == "":
			print("OK     ", f)
		else:
			failed += 1
			print("FALLO  ", f, "\n", err)
	print("%d partidas, %d fallos, %.1f s" % [files.size(), failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 else 0)


## Clave de una acción del registro de Python, en el mismo formato que TWGame.action_key.
static func _py_key(e: Array) -> String:
	var unit := -1 if e[2] == null else int(e[2])
	var dest: String = "-" if e[3] == null else e[3]
	var tg: String = "-" if e[5] == null else (str(int(e[5])) if e[5] is float else str(e[5]))
	return "%s|%d|%s|%s|%s" % [e[1], unit, dest, e[4], tg]


func _run_file(path: String) -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var g := TWGame.new(data.map, int(data.first), data.allowed, data.decks)
	for st in data.setup:
		if st[0] == "unit":
			g.add_unit(int(st[1]), st[2], R.cell(st[3]), bool(st[4]))
		else:
			g.add_char(g.units[int(st[1])])
	var bots := [
		TWBot.new(g, 0, "normal", int(data.bot_seeds[0]), data.noise, data.threshold),
		TWBot.new(g, 1, "normal", int(data.bot_seeds[1]), data.noise, data.threshold),
	]
	while g.winner == TWGame.NO_WINNER and g.turn < 200:
		g.start_turn()
		if g.winner == TWGame.NO_WINNER:
			bots[g.current].play_turn()
	var n := mini(g.log.size(), data.log.size())
	for i in range(n):
		var exp := _py_key(data.log[i])
		var got := TWGame.action_key(g.log[i])
		if exp != got:
			return "acción %d distinta\n    Python: %s\n    Godot:  %s" % [i + 1, exp, got]
	if g.log.size() != data.log.size():
		return "número de acciones distinto: Python %d, Godot %d" % [data.log.size(), g.log.size()]
	var a: PackedStringArray = data.final.split("\n")
	var b := g.canonical().split("\n")
	for i in range(maxi(a.size(), b.size())):
		var x: String = a[i] if i < a.size() else "<nada>"
		var y: String = b[i] if i < b.size() else "<nada>"
		if x != y:
			return "estado final distinto, línea %d\n    Python: %s\n    Godot:  %s" % [i + 1, x, y]
	return ""
