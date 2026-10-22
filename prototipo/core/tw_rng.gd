class_name TWRng
extends RefCounted
## Generador de números aleatorios mínimo, idéntico a tw_sim/lcg.py del simulador.

var state: int


func _init(seed: int) -> void:
	state = seed & 0xFFFFFFFF


func randf_unit() -> float:
	state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
	return state / 4294967296.0


func uniform(a: float, b: float) -> float:
	return a + (b - a) * randf_unit()
