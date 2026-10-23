# TACTIC WARS — Prompts para generar sonido y música con otra IA

Todo el audio que necesita el juego. Los prompts van en inglés (las IAs de audio responden mejor así);
las explicaciones, en español.

## 0. Cómo usarlo

- **Efectos de sonido:** ElevenLabs *Sound Effects*, Stable Audio, Adobe Firefly *Generate Sound
  Effects* u otra IA de efectos. Genera 3 o 4 variantes de cada uno y quédate con la mejor.
- **Música:** Suno, Udio, Stable Audio o similar. Pide **solo instrumental** (sin voz).
- **Licencia:** usa una cuenta cuyo plan permita el **uso comercial** (en Suno y Udio, los planes
  gratuitos no lo permiten). Guarda la prueba (factura o captura del plan).
- **No pidas que suene como un juego o un compositor concreto** (nada de «como Advance Wars»): basta con
  describir el estilo, como hacen los prompts de abajo.
- **Nombres:** guarda cada archivo con el nombre indicado y pásamelos; los integro y sustituyo los
  sonidos provisionales que genera ahora el juego.

**Formato técnico**

| | Efectos | Música |
|---|---|---|
| Formato | WAV 44,1 kHz 16 bits (o OGG) | OGG (o WAV/MP3 y lo convierto yo) |
| Canales | mono | estéreo |
| Duración | la indicada en cada uno (casi todos < 1,5 s) | bucles de 1,5–2,5 min; jingles de 3–8 s |
| Volumen | normalizado, sin saturar (pico −1 dB) | normalizado a −16 LUFS |
| Silencio | sin silencio al principio (el sonido debe arrancar al instante) | el bucle debe empalmar sin corte |

## 1. Estilo maestro

**Efectos** (pegar delante de cada uno):

```
Video game sound effect for a colorful, cartoon-style mobile military tactics game. Punchy, clean,
slightly stylized and exaggerated (not realistic or gory), short attack, no music, no voice, no
background noise, no reverb tail longer than half a second.
```

**Música** (pegar delante de cada pista):

```
Instrumental video game music for a colorful cartoon-style military turn-based strategy game on mobile.
Hybrid orchestral and modern electronic: marching snare drums, brass, strings, light synth arpeggios and
punchy percussion. Heroic, upbeat and catchy, never grim. No vocals, no lyrics.
```

## 2. Efectos de unidades

| Archivo | Cuándo suena | Duración | Prompt |
|---|---|---|---|
| `sonido/seleccionar.wav` | Tocar una unidad propia | 0,2 s | `soft military radio click with a tiny confirmation beep` |
| `sonido/mover_vehiculo.wav` | Se mueve un jeep, tanque o artillería | 1 s | `small military vehicle engine revving and rolling briefly, tracks and wheels on dirt` |
| `sonido/mover_tropa.wav` | Se mueve una tropa a pie | 0,8 s | `a few quick boot footsteps on dirt with gear rattling, two soldiers` |
| `sonido/disparo_fusil.wav` | Ataca el fusilero, el personaje o la tripulación | 0,5 s | `short burst of cartoon rifle fire, three quick shots` |
| `sonido/disparo_ametralladora.wav` | Ataca el jeep | 0,7 s | `fast mounted machine gun burst, punchy and short` |
| `sonido/disparo_cohete.wav` | Ataca el antitanque | 0,8 s | `shoulder rocket launcher firing, whoosh of the rocket leaving` |
| `sonido/disparo_canon.wav` | Ataca el tanque | 0,8 s | `heavy tank cannon shot, deep boom with a metallic clank` |
| `sonido/disparo_artilleria.wav` | Ataca la artillería | 1,2 s | `long-range artillery howitzer firing, big deep boom then a distant whistle` |
| `sonido/disparo_hacker.wav` | Ataca el hacker o el ingeniero | 0,5 s | `small electric zap with a digital crackle` |
| `sonido/impacto.wav` | El ataque alcanza a la unidad | 0,4 s | `bullet and shrapnel impact on metal armor, quick ping and thud` |
| `sonido/explosion.wav` | Se destruye una unidad | 1,2 s | `cartoon vehicle explosion, punchy boom with debris falling` |
| `sonido/expulsion.wav` | La tripulación o el personaje salen del vehículo destruido | 0,5 s | `hatch popping open and someone jumping out, quick scramble` |
| `sonido/subir_vehiculo.wav` | Una tropa sube a un vehículo | 0,5 s | `metal hatch opening and closing with a clunk` |
| `sonido/reparar.wav` | El ingeniero repara | 0,8 s | `wrench ratcheting and a short welding hiss` |
| `sonido/hackear.wav` | El hacker roba un vehículo vacío | 1 s | `fast computer keyboard typing then a digital access granted chime with glitch` |
| `sonido/sabotear.wav` | El ingeniero sabotea una torreta | 0,8 s | `electric sparks and a short circuit fizz` |
| `sonido/barricada.wav` | Se construye una barricada | 0,8 s | `sandbags dropped and metal hedgehog placed with a thud` |
| `sonido/evolucionar.wav` | La tripulación empieza a evolucionar | 0,8 s | `uplifting short training whistle and a gear-up sound` |
| `sonido/capturar_paso.wav` | Avanza una captura (sin completarla) | 0,4 s | `flag rope pulled and fabric fluttering briefly` |
| `sonido/capturar.wav` | Se completa una captura | 1,2 s | `short triumphant brass fanfare of three notes with a flag flapping` |
| `sonido/fabricar.wav` | Se encarga una unidad en un cuartel | 0,8 s | `factory machinery clank and a short hydraulic press` |
| `sonido/aparece_unidad.wav` | Sale una unidad fabricada | 0,8 s | `garage door opening with a rising mechanical whoosh` |

## 3. Torretas

| Archivo | Cuándo suena | Duración | Prompt |
|---|---|---|---|
| `sonido/torreta_disparo.wav` | Dispara una torreta | 0,6 s | `automated defense turret firing twin shots, mechanical and sharp` |
| `sonido/torreta_impacto.wav` | Una unidad ataca una torreta | 0,4 s | `shot hitting a thick concrete and steel bunker, heavy clang` |
| `sonido/torreta_destruida.wav` | Una torreta queda destruida | 1 s | `turret breaking apart with sparks, metal collapsing and a small explosion` |
| `sonido/torreta_reparar.wav` | Se repara o reconstruye una torreta | 0,8 s | `power tools whirring and a machine booting up with a beep` |

## 4. Cartas

| Archivo | Carta | Duración | Prompt |
|---|---|---|---|
| `sonido/carta_activar.wav` | Al usar cualquier carta (antes de su efecto) | 0,5 s | `playing card swiped and slammed on a table with a magical tactical whoosh` |
| `sonido/carta_marcha.wav` | Orden de marcha | 1 s | `military radio command chirp followed by a quick vehicle acceleration` |
| `sonido/carta_reparacion.wav` | Reparación de campo | 1,2 s | `rapid repair: welding sparks, wrench clicks and a positive healing chime` |
| `sonido/carta_pem.wav` | PEM | 1,5 s | `electromagnetic pulse: rising electric hum then a deep wobbling blast and electronics powering down` |
| `sonido/carta_torreta.wav` | Torreta terrestre | 1,2 s | `deployable turret unfolding with servos and locking into place with a clunk` |
| `sonido/carta_refuerzo.wav` | Refuerzo de emergencia | 1,2 s | `short alarm siren followed by boots running` |
| `sonido/carta_hackeo.wav` | Hackeo de red | 1,2 s | `digital glitch hacking sound, data bursts and a system override tone` |
| `sonido/carta_aereo.wav` | Ataque aéreo | 2,5 s | `fighter jet flyby from left to right, a bomb whistle falling, then a big explosion` |
| `sonido/carta_misiles.wav` | Torreta lanzamisiles | 1,5 s | `missile launcher rack raising and locking, then a missile launch whoosh` |
| `sonido/carta_saturacion.wav` | Bombardeo de saturación | 2,5 s | `artillery barrage: several shells whistling then many explosions in quick succession` |
| `sonido/carta_paracaidistas.wav` | Paracaidistas | 2 s | `transport plane passing overhead, parachute popping open and a soldier landing` |

## 5. Interfaz y partida

| Archivo | Cuándo suena | Duración | Prompt |
|---|---|---|---|
| `sonido/boton.wav` | Pulsar un botón | 0,1 s | `soft clean UI button tap, subtle` |
| `sonido/boton_carta.wav` | Elegir una carta en la preparación | 0,3 s | `card being picked up, paper flick` |
| `sonido/error.wav` | Acción no permitida | 0,3 s | `short low soft error buzz, not annoying` |
| `sonido/turno_jade.wav` | Empieza el turno de la Brigada Jade | 1 s | `short bright military bugle call, two rising notes, heroic` |
| `sonido/turno_ambar.wav` | Empieza el turno de la Legión Ámbar | 1 s | `short military horn call, two notes, slightly lower and more menacing` |
| `sonido/reloj_tic.wav` | Cada segundo de los últimos 5 del reloj | 0,1 s | `single sharp clock tick` |
| `sonido/reloj_fin.wav` | Se acaba el tiempo del turno | 0,8 s | `alarm buzzer short, time is up` |
| `sonido/alerta_dominio.wav` | Un bando tiene 6 de 10 edificios (a uno del dominio) | 1,2 s | `tense warning alarm, two pulsing tones` |
| `sonido/personaje_caido.wav` | Destruyen a un personaje | 1,5 s | `dramatic low brass hit with a falling tone` |

## 6. Música

Bucles: piden que el final empalme con el principio (`seamless loop`); si la IA no lo hace bien, dame
la pista algo más larga y la corto yo en un compás.

| Archivo | Dónde suena | Duración | Prompt (después del estilo maestro) |
|---|---|---|---|
| `musica/menu.ogg` | Menú principal | 2 min, bucle | `Main menu theme. Memorable heroic melody on brass over marching snare, confident and inviting, medium tempo 110 BPM, seamless loop.` |
| `musica/preparacion.ogg` | Preparación y despliegue | 2 min, bucle | `War room planning music. Calm but focused, light pulsing synth and soft strings, ticking percussion, tempo 95 BPM, thoughtful anticipation, seamless loop.` |
| `musica/batalla_1.ogg` | Partida, rondas 1–7 | 2,5 min, bucle | `Battle theme, early phase. Energetic and playful, marching snare groove, brass riffs answering each other, tempo 120 BPM, keeps momentum without being stressful, seamless loop.` |
| `musica/batalla_2.ogg` | Partida, rondas 8–13 | 2,5 min, bucle | `Battle theme, mid phase. Same mood as an energetic military march but more driving, bigger drums, faster strings ostinato, tempo 128 BPM, seamless loop.` |
| `musica/batalla_3.ogg` | Partida, rondas 14–20 o cerca del dominio | 2,5 min, bucle | `Battle theme, final phase. Intense and climactic, full orchestra with heavy taiko and snare, urgent brass, tempo 138 BPM, decisive showdown feeling, seamless loop.` |
| `musica/tutorial.ogg` | Tutorial | 2 min, bucle | `Light and friendly training music, relaxed marching rhythm, soft brass and pizzicato strings, tempo 100 BPM, encouraging, seamless loop.` |
| `musica/victoria.ogg` | Ganas | 6 s | `Short victory fanfare jingle, triumphant brass and cymbal, ends on a strong major chord.` |
| `musica/derrota.ogg` | Pierdes | 6 s | `Short defeat jingle, slow descending brass and soft drum roll, melancholic but not depressing, ends softly.` |
| `musica/empate.ogg` | Empate | 5 s | `Short neutral ending jingle, unresolved brass chord with a snare roll, ambiguous outcome.` |

Las tres de batalla conviene generarlas **con la misma melodía base** (en Suno o Udio: genera la
primera y usa «extend» o «cover» con más intensidad para las otras dos), así el cambio de fase se nota
pero suena a la misma partida.

## 7. Lista de comprobación

- [ ] 22 efectos de unidades
- [ ] 4 efectos de torretas
- [ ] 11 efectos de cartas
- [ ] 9 efectos de interfaz y partida
- [ ] 6 músicas en bucle + 3 jingles

Si quieres empezar por lo mínimo: `seleccionar`, `mover_vehiculo`, `mover_tropa`, los 6 `disparo_*`,
`impacto`, `explosion`, `capturar`, `turno_jade`, `turno_ambar`, `musica/menu` y `musica/batalla_1`.
