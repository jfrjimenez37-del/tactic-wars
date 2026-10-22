extends SceneTree
## Mide cuánto tarda la IA en elegir cada acción (para estimar la espera en el móvil).
func _init() -> void:
	var total := 0
	var n := 0
	var worst := 0
	for k in range(4):
		var g := TWSetup.new_game("equilibrado4", "hacker4", ["aereo", "reparacion", "torreta"], ["hackeo", "misiles", "pem"], k % 2)
		var bots := [TWBot.new(g, 0, "normal", k), TWBot.new(g, 1, "normal", k + 50)]
		while g.winner == TWGame.NO_WINNER and g.turn < 200:
			g.start_turn()
			if g.winner != TWGame.NO_WINNER:
				break
			var b: TWBot = bots[g.current]
			b.begin_turn()
			while g.winner == TWGame.NO_WINNER and g.current == b.side:
				var t0 := Time.get_ticks_usec()
				var a := b.choose()
				var dt := Time.get_ticks_usec() - t0
				total += dt
				n += 1
				worst = maxi(worst, dt)
				g.apply(a, false)
	print("decisiones: %d, media %.1f ms, peor %.1f ms" % [n, total / 1000.0 / n, worst / 1000.0])
	quit()
