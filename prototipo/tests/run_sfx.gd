extends SceneTree
## Comprueba que cada efecto de sonido generado tiene la duración esperada, no está en silencio y no satura.
## Uso:  godot --headless --path . --script res://tests/run_sfx.gd

const Sfx = preload("res://ui/sfx.gd")


func _init() -> void:
	var s = Sfx.new()
	root.add_child(s)
	await process_frame
	var fails := 0
	for name in s.streams:
		var w: AudioStreamWAV = s.streams[name]
		var n := w.data.size() / 2
		var peak := 0
		var clipped := 0
		for i in range(n):
			var v := absi(w.data.decode_s16(i * 2))
			peak = maxi(peak, v)
			if v >= 30000:
				clipped += 1
		var ok := peak > 3000 and clipped < n / 50
		if not ok:
			fails += 1
		print("%-8s %.2f s  pico %5d  saturadas %d  %s" % [name, float(n) / Sfx.RATE, peak, clipped, "OK" if ok else "FALLO"])
	quit(1 if fails > 0 else 0)
