extends Node
## Efectos de sonido generados por código al arrancar (sin archivos de audio): disparo, explosión,
## movimiento, captura, carta, cambio de turno, selección y tic del reloj.

const RATE := 22050

var enabled := true
var streams := {}
var players := []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 7
	streams = {
		"shot": _make(0.22, _shot), "boom": _make(0.8, _boom), "move": _make(0.4, _move),
		"capture": _make(0.45, _capture), "card": _make(0.35, _card), "turn": _make(0.3, _turn),
		"select": _make(0.05, func(t: float, _lp: Array) -> float: return sin(TAU * 900.0 * t) * exp(-t * 60.0) * 0.35),
		"tick": _make(0.04, func(t: float, _lp: Array) -> float: return sin(TAU * 1500.0 * t) * exp(-t * 90.0) * 0.4),
	}
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(name: String, volume_db := 0.0) -> void:
	if not enabled or not streams.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = volume_db
			p.play()
			return


## Genera la onda muestra a muestra; lp es un estado para filtrar ruido (filtro paso bajo de un polo).
func _make(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := [0.0, 0.0]
	for i in range(n):
		var v: float = f.call(float(i) / RATE, lp)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


func _shot(t: float, _lp: Array) -> float:
	return _noise() * exp(-t * 25.0) * 0.5 + sin(TAU * 110.0 * t) * exp(-t * 18.0) * 0.45


func _boom(t: float, lp: Array) -> float:
	lp[0] += 0.08 * (_noise() - lp[0])
	return lp[0] * exp(-t * 4.0) * 1.6 + sin(TAU * (55.0 - 20.0 * t) * t) * exp(-t * 5.0) * 0.6


func _move(t: float, lp: Array) -> float:
	lp[0] += 0.05 * (_noise() - lp[0])
	var env := minf(1.0, t / 0.05) * maxf(0.0, 1.0 - t / 0.4)
	return (sin(TAU * 80.0 * t) + 0.5 * sin(TAU * 160.0 * t) + lp[0] * 1.5) * env * 0.25


func _capture(t: float, _lp: Array) -> float:
	var f := 660.0 if t < 0.18 else 990.0
	var t0 := t if t < 0.18 else t - 0.18
	return (sin(TAU * f * t) + 0.3 * sin(TAU * 2.0 * f * t)) * exp(-t0 * 9.0) * 0.4


func _card(t: float, lp: Array) -> float:
	lp[1] += TAU * (300.0 + 1100.0 * t / 0.35) / RATE      # barrido de 300 a 1400 Hz
	return sin(lp[1]) * (1.0 - t / 0.35) * 0.4


func _turn(t: float, _lp: Array) -> float:
	var f := 523.0 if t < 0.12 else 784.0
	var t0 := t if t < 0.12 else t - 0.12
	return sin(TAU * f * t) * exp(-t0 * 14.0) * 0.35
