extends RefCounted
## Tutorial: 7 lecciones cortas, cada una con su escenario en el mapa Cuatro plazas. En cada paso se
## resalta lo que hay que tocar y solo se permite la acción que se enseña.
##
## Tipos de paso: button (pulsar «Siguiente»), select (tocar una unidad), building (tocar un edificio),
## card (elegir una carta), action (hacer una acción que cumpla allow), end (terminar el turno),
## final (fin del tutorial).

const ALL_TYPES := ["F", "A", "I", "K", "J", "T", "R"]

var lesson := -1
var step := 0
var tags := {}                 # nombre -> id de unidad del escenario
var game: TWGame
var lessons: Array


func _init() -> void:
	lessons = [
		{"units": [[0, "J", Vector2i(3, 2), "jeep"], [0, "F", Vector2i(1, 3), ""]], "steps": [
			{"type": "button", "text": "Bienvenido a TACTIC WARS. Mandas la Brigada Jade (verde) contra la Legión Ámbar (naranja). En 7 lecciones cortas aprenderás lo básico."},
			{"type": "select", "tag": "jeep", "text": "Lección 1 de 7 · Mover. Toca tu jeep (resaltado en amarillo)."},
			{"type": "action", "allow": func(a): return a.kind == "activate" and a.unit == tags.jeep and a.sub == "none",
				"text": "Las casillas claras son las que alcanza este turno: el jeep es rápido (6 de movimiento). Toca una para moverlo."},
			{"type": "button", "text": "Cada unidad que actúa gasta PM (puntos de mando): el jeep 1, el tanque y la artillería 2. Tienes 5 PM por turno (6 desde la ronda 8 y 7 desde la 14) y puedes guardar alguno para el turno siguiente."},
		]},
		{"units": [[0, "T", Vector2i(5, 3), "tanque"], [1, "J", Vector2i(7, 3), "objetivo"]], "steps": [
			{"type": "select", "tag": "tanque", "text": "Lección 2 de 7 · Atacar. Toca tu tanque."},
			{"type": "action", "allow": func(a): return a.kind == "activate" and a.unit == tags.tanque and a.sub == "attack",
				"hint_tag": "objetivo", "text": "El jeep enemigo tiene borde rojo: lo puedes atacar. Toca una casilla clara a su lado (o el propio jeep) y elige «Atacar»."},
			{"type": "button", "text": "¡Destruido! El daño depende de quién ataca a quién: el tanque hace 4 a los vehículos ligeros. Si el atacado sobrevive y está al lado, contraataca. Quien destruye una unidad se vuelve veterano (V): +1 de daño."},
		]},
		{"units": [[0, "F", Vector2i(5, 2), "fusilero"], [0, "J", Vector2i(1, 3), ""]], "steps": [
			{"type": "select", "tag": "fusilero", "text": "Lección 3 de 7 · Capturar. Los edificios dan suministros y cuentan para ganar. Toca tu fusilero."},
			{"type": "action", "allow": func(a): return a.kind == "activate" and a.unit == tags.fusilero and a.sub == "capture",
				"hint_cell": Vector2i(6, 2), "text": "Toca la plaza resaltada y elige «Capturar»."},
			{"type": "button", "text": "Captura en marcha: 2 de 4 puntos (el fusilero y el personaje suman 2 por turno; las demás tropas, 1). Si sigue ahí el próximo turno, la plaza será tuya. La primera vez que conquistas una ciudad ganas 5 suministros."},
			{"type": "end", "text": "Las 4 plazas del centro tienen torreta: al terminar el turno de cada bando dispara a su enemigo más cercano a 2 casillas o menos (las neutrales, a los dos bandos). Pulsa «Terminar turno» y mira."},
			{"type": "button", "text": "La torreta ha disparado a tu fusilero. Conviene llegar a las plazas con apoyo, atacar antes la torreta (6 PV y blindaje 1) o que un ingeniero la sabotee."},
		]},
		{"units": [[0, "T", Vector2i(2, 3), ""], [0, "F", Vector2i(3, 1), ""]], "supplies": 8, "steps": [
			{"type": "building", "cell": Vector2i(1, 2), "text": "Lección 4 de 7 · Fabricar. Toca tu cuartel (resaltado)."},
			{"type": "action", "allow": func(a): return a.kind == "produce",
				"text": "Elige qué fabricar. Cada unidad cuesta suministros y tarda en salir: las tropas a pie y el jeep, 2 turnos; el tanque y la artillería, 3."},
			{"type": "button", "text": "Encargo hecho: la unidad saldrá en el cuartel. Los suministros llegan así: +1 por turno, +5 la primera vez que conquistas una ciudad (+2 si se la quitas al rival) y +1 por turno por cada ciudad tuya. Como mucho, 6 vehículos y 4 tropas a pie."},
		]},
		{"units": [[0, "T", Vector2i(3, 3), ""], [1, "T", Vector2i(6, 6), "objetivo"], [1, "F", Vector2i(6, 5), ""]],
			"round": 5, "deck": ["aereo", "marcha", "reparacion"], "steps": [
			{"type": "card", "card": "aereo", "text": "Lección 5 de 7 · Cartas. Cada jugador lleva 3. Pulsa «Ataque aéreo» en el panel de la derecha."},
			{"type": "action", "allow": func(a): return a.kind == "card" and a.sub == "aereo", "hint_tag": "objetivo",
				"text": "Toca la casilla del tanque enemigo: 4 de daño a esa unidad y 2 a las enemigas que tenga al lado."},
			{"type": "button", "text": "Las cartas cuestan PM, después se recargan durante unas rondas y algunas solo se pueden usar desde cierta ronda (el ataque aéreo, desde la 4)."},
		]},
		{"units": [[0, "T*", Vector2i(3, 2), "tanque"]], "steps": [
			{"type": "select", "tag": "tanque", "text": "Lección 6 de 7 · Tripulación y personaje. Cada vehículo lleva una tripulación (punto blanco) y uno lleva además a tu personaje (punto amarillo). Toca el tanque."},
			{"type": "action", "allow": func(a): return a.kind == "dismount" and a.sub == "none",
				"text": "Pulsa «Desembarcar tripulación…» en el panel y elige una casilla."},
			{"type": "button", "text": "Una tripulación a pie puede capturar edificios o volver al cuartel a evolucionar a otra tropa. Un vehículo vacío no puede actuar y el hacker enemigo puede robarlo. El personaje (4 PV) captura 2 puntos por turno; si lo destruyen, el rival gana 3 suministros."},
		]},
		{"units": [[0, "T", Vector2i(2, 3), ""]], "steps": [
			{"type": "button", "text": "Lección 7 de 7 · Cómo se gana. Hay tres formas: dominio (empezar dos turnos seguidos tuyos con 7 de los 10 edificios), capturar el cuartel general enemigo o eliminar todas sus unidades."},
			{"type": "button", "text": "Si en la ronda 20 nadie ha ganado, gana quien tenga más edificios; si empatan, quien haya destruido más valor y, después, quien conserve más. ¡Eso es todo!"},
			{"type": "final", "text": "Tutorial terminado. ¿Juegas una partida de práctica contra la IA en Fácil?"},
		]},
	]


func current() -> Dictionary:
	return lessons[lesson].steps[step]


## Crea el escenario de la lección n (siempre empieza jugando Jade). Ámbar tiene además unidades lejos
## para que la partida no termine por eliminación.
func build(n: int) -> TWGame:
	lesson = n
	step = 0
	tags = {}
	var L: Dictionary = lessons[n]
	var deck: Array = L.get("deck", [])
	var g := TWGame.new("Cuatro plazas", 0, [ALL_TYPES, ALL_TYPES], [deck, []])
	var units: Array = L.units + [[1, "T", Vector2i(10, 6), ""], [1, "F", Vector2i(10, 8), ""]]
	for e in units:
		var v := g.add_unit(e[0], e[1][0], e[2])
		if e[1].ends_with("*"):
			g.add_char(v)
		if e[3] != "":
			tags[e[3]] = v.id
	if L.has("round"):
		g.round = L.round
	g.start_turn()
	if L.has("supplies"):
		g.supplies[0] = L.supplies
	game = g
	return g


## Casillas que hay que resaltar en el paso actual.
func hints() -> Array:
	var s := current()
	var out := []
	if s.has("tag") and game.units.has(tags.get(s.tag, -1)):
		out.append(game.units[tags[s.tag]].pos)
	if s.has("hint_tag") and game.units.has(tags.get(s.hint_tag, -1)):
		out.append(game.units[tags[s.hint_tag]].pos)
	if s.has("cell"):
		out.append(s.cell)
	if s.has("hint_cell"):
		out.append(s.hint_cell)
	return out.filter(func(p): return p != null)


func allows(a: Dictionary) -> bool:
	var s := current()
	if a.kind == "end":
		return s.type == "end"
	return s.type == "action" and s.allow.call(a)


## Avisa de algo que ha hecho el jugador; devuelve true si el paso queda cumplido.
func notify(kind: String, value = null) -> bool:
	var s := current()
	var done := false
	match s.type:
		"select":
			done = kind == "select" and value == tags.get(s.tag, -2)
		"building":
			done = kind == "building" and value == s.cell
		"card":
			done = kind == "card" and value == s.card
		"action":
			done = kind == "action" and s.allow.call(value)
		"end":
			done = kind == "end"
		"button":
			done = kind == "button"
	return done


## Pasa al paso siguiente; devuelve "step", "lesson" (hay que montar la lección siguiente) o "done".
func advance() -> String:
	step += 1
	if step < lessons[lesson].steps.size():
		return "step"
	if lesson + 1 < lessons.size():
		return "lesson"
	return "done"
