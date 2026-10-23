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
| `core/tw_save.gd` | Guarda y recupera el estado completo de una partida (JSON). |
| `core/tw_bot.gd`, `core/tw_rng.gd` | IA: traducción exacta de los bots del simulador, con el mismo generador de azar. |
| `ui/menu_screen.gd` | Menú principal: continuar, nueva partida, tutorial y ajustes (sonido y animaciones). |
| `ui/tutorial.gd` | Tutorial: 7 lecciones con su escenario, casillas resaltadas y solo la acción que se enseña. |
| `ui/setup_screen.gd` | Pantalla de preparación: ejército, equipo del personaje, 3 cartas y rival. |
| `ui/main.tscn`, `ui/main.gd` | Despliegue y pantalla de partida: barra superior, panel de acciones, cartas, registro y fin de partida. |
| `ui/board_view.gd` | Dibujo del tablero, las unidades, las torretas y los resaltados. |
| `ui/board_camera.gd` | Cámara del tablero: arrastrar, ampliar con dos dedos o la rueda, centrar en una casilla. |
| `ui/sfx.gd` | Efectos de sonido generados por código (sin archivos de audio). |
| `ui/art.gd` | Carga del arte (`assets/arte/`): unidades, terreno, edificios, torretas, efectos, cartas e interfaz. |
| `assets/arte/` | Arte del juego, preparado con `../arte/preparar_arte.py` a partir de los 83 archivos entregados. |
| `tests/run_golden.gd` | Pruebas: vuelve a jugar partidas del simulador y compara el estado turno a turno. |
| `tests/golden/` | 24 partidas de referencia exportadas con `tactic_wars_sim/export_golden.py`. |
| `tests/run_bots.gd`, `tests/bot_golden/` | Pruebas de la IA: 24 partidas bot contra bot que deben salir idénticas a las de Python. |
| `tests/bench_bot.gd` | Mide el tiempo que tarda la IA en decidir cada acción. |
| `tests/run_camera.gd` | Prueba de la cámara con toques, arrastres y pellizcos simulados. |
| `tests/run_sfx.gd` | Comprueba que cada sonido generado tiene volumen y no satura. |
| `tests/run_save.gd` | Guarda a mitad de partida, carga y comprueba que el original y la copia terminan igual. |

## Cómo se juega en el prototipo

**Menú principal.** «Continuar partida» (si hay una guardada, con su ronda y rival), «Nueva partida» y
«Ajustes» (sonido; animaciones normales, rápidas o sin animaciones). La partida se guarda sola después
de cada acción y al empezar cada turno, así que se puede salir en cualquier momento (botón «Menú» o
«atrás» de Android) y seguir después. Al terminar la partida se borra la guardada.

**Tutorial** (en el menú). Siete lecciones cortas, cada una con su propio escenario en el mapa: mover,
atacar, capturar (y la torreta de las plazas), fabricar, cartas, tripulación y personaje, y cómo se gana.
La casilla que hay que tocar late en amarillo y solo se permite la acción de la lección. Al terminar,
propone una partida de práctica contra la IA en Fácil.

**Dificultad de la IA** (en la preparación, contra la IA). Medida en el simulador, 200 partidas por
nivel contra la IA normal:

| Nivel | Cómo juega | Gana a la Normal |
|---|---|---|
| Fácil | estilo normal con mucho ruido (1,5) | ~28 % |
| Normal | estilo normal, ruido 0,3 (la de las simulaciones) | 50 % |
| Difícil | estilo agresivo | ~62 % |

Quitar ruido no la hace más fuerte (sin ruido gana el 50 %); el estilo agresivo sí.

**Preparación (sec. 3 del reglamento).** Se sortea quién juega primero. Cada jugador elige 4 equipos y
2 tropas a pie (con los botones − y +, o partiendo de un ejército recomendado), el equipo en el que empieza
su personaje y 3 cartas. Jade elige también el rival (la IA o un segundo jugador en el mismo móvil) y
si se juega con reloj (C13: 25 s por turno y 60 s de reserva por partida; con los dos agotados, el turno
termina solo).

**Despliegue.** Cada jugador coloca sus unidades a 3 casillas o menos de su CG o de su cuartel: elige una
unidad en el panel y toca una casilla resaltada. Puede moverlas tocándolas otra vez, colocar el resto de
forma automática o quitarlas todas. Con dos jugadores, el móvil se pasa entre uno y otro con una pantalla
intermedia para que ninguno vea lo que eligió el otro. La IA elige al azar uno de los ejércitos
recomendados y 3 cartas, y despliega de forma automática.

**Partida.**

- El mapa no cabe entero a propósito: la cámara se centra en tu personaje al empezar tu turno y sigue
  a la IA durante el suyo. Arrastra con un dedo para mirar por el mapa y pellizca con dos para ampliar o
  reducir. Botones: −, +, «Mapa» (mapa entero / vista ampliada) y ★ (volver a tu personaje).
- Cada acción se anima: la unidad recorre su camino, disparo, número de daño, explosión, capturas,
  cartas y disparos de las torretas. Una acción dura como mucho 3 s (si tiene muchos sucesos, se
  acelera). Mientras se anima no se aceptan toques y el reloj se para.
- Sonido para mover, disparar, explotar, capturar, cartas, cambio de turno y los últimos 5 s del reloj;
  se apaga con el botón «Sonido» de arriba.

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
godot --path . -- --setup-test=clock                 # reloj activado: comprueba que el turno pasa solo
godot --path . -- --setup-test=resume                # sale al menú a mitad de partida y la continúa
godot --headless --path . --script res://tests/run_save.gd
godot --path . -- --tutorial-test=0                  # recorre el tutorial entero tocando lo resaltado
godot --headless --path . --script res://tests/run_camera.gd
godot --headless --path . --script res://tests/run_sfx.gd
godot --path . -- --demo=0 --anim-shot=a.png --anim-at=1.0   # captura a mitad de un ataque animado
godot --path . -- --setup-test=setup --shot=p.png    # captura de la pantalla de preparación (o =deploy)
```

Las opciones `--demo`, `--autoplay` y `--select` empiezan una partida rápida con ejércitos fijos, sin preparación.

## Arte

El tablero se dibuja con el arte de `assets/arte/`:

- **Terreno por piezas.** Cada casilla elige su imagen según sus vecinas: 16 piezas de camino y 16 de río
  (N=1, E=2, S=4, O=8), cuartos de lago para las zonas de agua de 2×2 y la pasarela del puente encima.
  Si el terreno cambia en la partida (muro destruido, puente volado, barricada), la casilla se redibuja.
- **Edificios** con el color de su dueño (la plaza, con su torreta en la esquina), **torretas** de las
  cartas sobre la casilla y la torreta destruida.
- **Unidades** de Jade mirando a la derecha y de Ámbar volteadas hacia la izquierda; encima, la vida, los
  puntos de tripulación (blanco) y personaje (amarillo), veterano, PEM y evolución.
- **Efectos** de las animaciones: proyectil, impacto, explosión, bomba, onda del PEM y bandera de captura.
- **Interfaz:** ilustración en cada carta, iconos de unidad en la preparación y el despliegue, logo, fondo
  de la preparación, carteles de victoria y derrota, e icono de la app.

Para cambiar o añadir arte: deja los archivos con sus nombres en una carpeta como la de la entrega
(`01_ASSETS_PARA_CLAUDE`) y ejecuta `python3 ../arte/preparar_arte.py <carpeta> assets/arte`.

## Pendiente

1. Sonido y música de la otra IA (prompts en `../arte/PROMPTS_AUDIO.md`).
2. Arte: las 10 cartas como ilustraciones individuales a 512×768 (ahora son recortes de una lámina) y la
   artillería de Ámbar con la misma forma que la de Jade. Música.
3. Más mapas (candidatos simulados en `../simulador/experimentos/RESULTADOS_MAPAS.md`).

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

`tools/android/debug.keystore` es la llave de depuración (alias `androiddebugkey`, contraseña `android`)
con la que se firman las APK de prueba. Usar siempre la misma permite instalar cada versión nueva encima
de la anterior; con otra llave, Android obliga a desinstalar primero.
