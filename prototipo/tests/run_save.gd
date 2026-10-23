extends SceneTree
## Prueba de la partida guardada: juega media partida con la IA, la guarda en JSON, la carga y comprueba
## que el estado es idéntico; después sigue jugando el original y la copia hasta el final con la IA y
## comprueba que terminan exactamente igual.
## Uso:  godot --headless --path . --script res://tests/run_save.gd

const R = preload("res://core/tw_rules.gd")


func _setup(data: Dictionary) -> TWGame:
	var g := TWGame.new(data.map, int(data.first), data.allowed, data.decks)
	for st in data.setup:
		if st[0] == "unit":
			g.add_unit(int(st[1]), st[2], R.cell(st[3]), bool(st[4]))
		else:
			g.add_char(g.units[int(st[1])])
	return g


func _play(g: TWGame, bots: Array, until_turn: int) -> void:
	while g.winner == TWGame.NO_WINNER and g.turn < until_turn:
		g.start_turn()
		if g.winner == TWGame.NO_WINNER:
			bots[g.current].play_turn()


func _init() -> void:
	var files := []
	for f in DirAccess.open("res://tests/bot_golden").get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	var fails := 0
	for f in files.slice(0, 8):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/bot_golden/" + f))
		var g := _setup(data)
		var bots := [TWBot.new(g, 0, "normal", int(data.bot_seeds[0])), TWBot.new(g, 1, "normal", int(data.bot_seeds[1]))]
		_play(g, bots, 17)                                  # a mitad de partida, al final de un turno
		var text := JSON.stringify(TWSave.to_dict(g))
		var g2 := TWSave.from_dict(JSON.parse_string(text))
		var same: bool = g2.canonical() == g.canonical() and g2.decks == g.decks and g2.allowed == g.allowed
		var bots2 := [TWBot.new(g2, 0, "normal", 0), TWBot.new(g2, 1, "normal", 0)]
		for s in [0, 1]:
			bots2[s].rng.state = bots[s].rng.state
		var n0 := g.log.size()
		_play(g, bots, 200)
		_play(g2, bots2, 200)
		var tail := []
		for a in g.log.slice(n0):
			tail.append(TWGame.action_key(a))
		var tail2 := []
		for a in g2.log:
			tail2.append(TWGame.action_key(a))
		var end_same := g.canonical() == g2.canonical() and tail == tail2
		if same and end_same:
			print("OK     %s  (%d bytes guardados, %d acciones después de cargar)" % [f, text.length(), tail.size()])
		else:
			fails += 1
			print("FALLO  %s  estado al cargar %s, final %s" % [f, same, end_same])
	print("Partida guardada: %s" % ("OK" if fails == 0 else "%d fallos" % fails))
	quit(1 if fails > 0 else 0)
