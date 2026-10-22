class_name TWUnit
extends RefCounted
## Una unidad de la capa 0. -1 significa «ninguno» en los campos de identificador.

var id: int
var side: int
var t: String
var hp: int
var pos = null              # Vector2i o null si va dentro de un vehículo
var veteran := false
var crew := -1              # id de la tropa que lo tripula (vehículos)
var acted := false
var moved := false
var barricades := 0
var carrier := -1           # id del vehículo en el que va (tropas a pie)
var home := -1              # vehículo de origen de una tripulación (C8.6)
var char_id := -1           # id del personaje que va dentro (vehículos)
var training = null         # [tipo, turno en que termina] mientras la tripulación evoluciona
var stun := -1              # turno en que no puede actuar (PEM)


func _init(p_id: int, p_side: int, p_t: String, p_pos, p_hp: int = -1) -> void:
	id = p_id
	side = p_side
	t = p_t
	pos = p_pos
	hp = TWRules.UNIT[t][2] if p_hp < 0 else p_hp
	barricades = 2 if t == "I" else 0
