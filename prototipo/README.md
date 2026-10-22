# Tactic Wars — prototipo de la capa 0 (Godot 4.3)

Primer prototipo jugable de la capa 0 con las reglas del **Reglamento capa 0 v2** (22-10-2026):
mapa Cuatro plazas, 4 equipos + 2 tropas a pie + personaje, torretas en las plazas, cartas,
hacker, evolución de la tripulación, economía, escalada de PM, límites, dominio y desempate.

## Estructura

| Archivo | Qué hace |
|---|---|
| `core/tw_rules.gd` | Datos de las reglas: mapa, unidades, tabla de daño, cartas, torretas, economía. |
| `core/tw_unit.gd` | Una unidad. |
| `core/tw_game.gd` | Motor de reglas: acciones legales, aplicar acciones, turnos, victoria. Traducción directa del simulador de Python. |
| `core/tw_setup.gd` | Creación de partidas, zona de despliegue y despliegue automático. |
| `core/tw_bot.gd`, `core/tw_rng.gd` | IA: traducción exacta de los bots del simulador, con el mismo generador de azar. |
| `ui/setup_screen.gd` | Pantalla de preparación: ejército, equipo del personaje, 3 cartas y rival. |
| `ui/main.tscn`, `ui/main.gd` | Despliegue y pantalla de partida: barra superior, panel de acciones, cartas, registro y fin de partida. |
| `ui/board_view.gd` | Dibujo del tablero, las unidades, las torretas y los resaltados. |
| `tests/run_golden.gd` | Pruebas: vuelve a jugar partidas del simulador y compara el estado turno a turno. |
| `tests/golden/` | 24 partidas de referencia exportadas con `tactic_wars_sim/export_golden.py`. |
| `tests/run_bots.gd`, `tests/bot_golden/` | Pruebas de la IA: 24 partidas bot contra bot que deben salir idénticas a las de Python. |
| `tests/bench_bot.gd` | Mide el tiempo que tarda la IA en decidir cada acción. |

## Cómo se juega en el prototipo

**Preparación (sec. 3 del reglamento).** Se sortea quién juega primero. Cada jugador elige 4 equipos y
2 tropas a pie (con los botones − y +, o partiendo de un ejército recomendado), el equipo en el que empieza
su personaje y 3 cartas. Jade elige también el rival: la IA o un segundo jugador en el mismo móvil.

**Despliegue.** Cada jugador coloca sus unidades a 3 casillas o menos de su CG o de su cuartel: elige una
unidad en el panel y toca una casilla resaltada. Puede moverlas tocándolas otra vez, colocar el resto de
forma automática o quitarlas todas. Con dos jugadores, el móvil se pasa entre uno y otro con una pantalla
intermedia para que ninguno vea lo que eligió el otro. La IA elige al azar uno de los ejércitos
recomendados y 3 cartas, y despliega de forma automática.

**Partida.**

- Juegas con la Brigada Jade (verde) contra la Legión Ámbar (naranja), que mueve la IA (la misma que jugó las
  partidas del simulador).
- Toca una unidad propia: se resaltan las casillas a las que puede ir y, con borde, sus objetivos
  (rojo: unidades enemigas; azul: torretas o estructuras). Toca una casilla: si hay una sola acción se
  hace al momento; si hay varias, elige en el panel.
- Toca tu cuartel general o tu cuartel (o dos veces una unidad que esté encima) para fabricar.
- Las cartas están en el panel derecho; al elegir una se resaltan sus casillas posibles.
- Terminar turno guarda los PM permitidos y dispara las torretas.

## Pruebas

```sh
godot --headless --path . --import                       # la primera vez
godot --headless --path . --script res://tests/run_golden.gd
godot --headless --path . --script res://tests/run_bots.gd
```

El motor acepta cada acción de las 24 partidas de referencia, llega exactamente al mismo estado que
Python al final de cada turno y genera la misma lista de acciones legales al inicio de cada turno.
La IA de Godot, con la misma semilla, juega exactamente las mismas 24 partidas que los bots de Python.

Prueba de la interfaz (necesita pantalla; en un servidor, con `xvfb-run`):

```sh
godot --path . -- --autoplay --shot=final.png      # partida completa con toques simulados
godot --path . -- --demo=4 --select=E5 --shot=a.png  # captura con una unidad seleccionada
godot --path . -- --setup-test=play                  # preparación y despliegue pulsando botones, contra la IA
godot --path . -- --setup-test=hotseat               # lo mismo con dos jugadores en el mismo móvil
godot --path . -- --setup-test=setup --shot=p.png    # captura de la pantalla de preparación (o =deploy)
```

Las opciones `--demo`, `--autoplay` y `--select` empiezan una partida rápida con ejércitos fijos, sin preparación.

## Pendiente

1. Exportación a Android y prueba en el móvil.
2. Animaciones de movimiento y combate (máximo 3 s), reloj de 25 s, sonido.
3. Arte definitivo (ahora son formas y letras).

## Exportar a Android

`export_presets.cfg` ya trae el perfil «Android» (APK sin Gradle, arm64-v8a y armeabi-v7a, paquete
`com.tacticwars.capa0`, pantalla completa en horizontal, icono en `icons/`). En un ordenador con el editor:

1. Editor → Gestionar plantillas de exportación → descargar las de 4.3.
2. Editor → Configuración del editor → Exportar → Android: ruta del Android SDK (con `build-tools` y
   `platform-tools`) y keystore de depuración (el editor puede crearlo).
3. Proyecto → Exportar → Android → Exportar proyecto (o el botón de desplegar con el móvil conectado por USB).

Desde la línea de comandos: `godot --headless --path . --export-debug "Android" build/tactic_wars.apk`.

`tools/android/MiniApkSigner.java` es un sustituto mínimo de `apksigner` (basado en la librería apksig de
Maven Central) que se usó para firmar la APK en un entorno sin acceso al Android SDK. Firma solo con el
esquema v2, que vale para Android 7.0 o superior. Con el SDK normal no hace falta.
