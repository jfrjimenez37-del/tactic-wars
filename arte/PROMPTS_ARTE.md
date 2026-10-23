# TACTIC WARS — Prompts para generar el arte con otra IA

Todo lo que necesita el juego, en orden. Los prompts están en inglés porque los generadores de imágenes
(Midjourney, ChatGPT/DALL·E, Leonardo, Ideogram, Firefly…) responden mejor así; las explicaciones van en
español.

## 0. Cómo usarlo

1. **Primero la imagen ancla.** Genera el *Tanque medio de la Brigada Jade* (3.1) hasta que te guste.
   Esa imagen fija el estilo: úsala como referencia en todas las demás (en Midjourney `--sref <url>`;
   en ChatGPT, súbela y di «same style as this image»; en Leonardo, *Style Reference*).
2. **Pega siempre el estilo maestro (sección 1) delante** de cada prompt concreto.
3. **Fondo:** pide fondo transparente; si la herramienta no puede, usa fondo liso verde croma
   `#00FF00` (ya va en los prompts) y lo recorto yo.
4. **Sin texto dentro de las imágenes** (salvo el logo): el juego pone los textos.
5. **Tamaños:** genera en cuadrado 1024×1024 aunque luego se reduzca; abajo se indica el tamaño final.
6. **Nombres:** guarda cada imagen con el nombre de archivo indicado (`unidades/jade_tanque.png`…) y
   pásamelas todas; las integro en el prototipo.
7. **Vista:** todas en **vista cenital 3/4** (desde arriba y algo inclinada, como Advance Wars o
   Wargroove), unidades **mirando a la derecha**. Las de Ámbar pueden mirar a la izquierda; si salen a
   la derecha, el juego las voltea.

## 1. Estilo maestro (pegar delante de cada prompt)

```
Stylized mobile tactics game art, 3/4 top-down view like Advance Wars and Wargroove, clean vector-like
illustration, bold readable silhouette, thick dark outline, flat colors with soft cel shading, bright and
colorful, near-future military theme but friendly and non-realistic, no gore, no real-world flags,
insignia or brands, no text, centered single subject, readable at very small size, consistent lighting
from top-left.
```

**Paleta de los bandos** (añadir al prompt de cada unidad o edificio de ese bando):

- Brigada Jade: `faction colors jade green #2FA36B with dark green #1E6B47 and white accents`
- Legión Ámbar: `faction colors amber orange #E39B2D with dark brown #7A4A12 and cream accents`
- Neutral: `neutral light gray #E8E8E8 and stone colors`

Fondo del tablero de la interfaz: gris azulado oscuro `#1E2328`.

## 2. Unidades (9 × 2 bandos)

Tamaño final 256×256, fondo transparente (o `#00FF00`). Una unidad por imagen, ocupando unos dos
tercios del cuadro. **Las tropas a pie son dos soldados que funcionan como una unidad**: dibujar siempre
a dos.

Plantilla: `[estilo maestro] + [prompt de la unidad] + [paleta del bando] + "plain #00FF00 background, game unit sprite, 1024x1024"`

| Archivo | Unidad | Prompt |
|---|---|---|
| `unidades/{bando}_fusilero.png` | Fusilero | `a squad of two riflemen side by side, helmets and light armor, rifles ready, dynamic but compact pose` |
| `unidades/{bando}_antitanque.png` | Antitanque | `a squad of two anti-tank soldiers, one kneeling with a shoulder rocket launcher, the other carrying spare rockets` |
| `unidades/{bando}_ingeniero.png` | Ingeniero | `a squad of two combat engineers with hard helmets, one holding a big wrench, the other a toolbox and a coil of cable` |
| `unidades/{bando}_hacker.png` | Hacker | `a squad of two tech operators, one typing on a rugged laptop, the other holding a small antenna device with glowing screen` |
| `unidades/{bando}_tripulacion.png` | Tripulación | `two vehicle crew members in coveralls and padded tank helmets, one with a pistol, the other with a small toolbag` |
| `unidades/{bando}_personaje.png` | Personaje (comandante) | `a single heroic field commander, confident stance, long coat with shoulder pads, binoculars in hand, distinctive beret, clearly more important than regular soldiers` |
| `unidades/{bando}_jeep.png` | Jeep | `a light 4x4 military jeep with an open top and a mounted machine gun, fast and agile look` |
| `unidades/{bando}_tanque.png` | Tanque medio | `a medium battle tank with a rotating turret and a long cannon, sturdy tracks, chunky proportions` |
| `unidades/{bando}_artilleria.png` | Artillería | `a self-propelled artillery howitzer on a tracked chassis, very long barrel angled upward, support stabilizers` |

Variantes opcionales (para el detalle de la unidad seleccionada): mismo prompt + `damaged, smoke and
scratches` → `unidades/{bando}_{unidad}_danado.png`.

### 2.1 Retratos (preparación, menú y mensajes)

512×512, fondo del color del bando degradado. Plantilla: `[estilo maestro] + "bust portrait, " + [prompt] + [paleta]`.

- `retratos/{bando}_personaje.png`: el comandante del bando de frente, mirada decidida.
- `retratos/{bando}_{unidad}.png` (opcional): un soldado de cada tipo de tropa a pie.

## 3. Terreno del mapa

Casillas cuadradas de 256×256 **sin bordes ni sombras exteriores, que encajen unas con otras** (pedir
`seamless tileable square tile, top-down, no border`). Sin unidades ni texto.

| Archivo | Casilla | Prompt |
|---|---|---|
| `terreno/llanura.png` | Llanura | `grass plain tile with small tufts and tiny flowers, light green #8DB360` |
| `terreno/llanura_2.png` | Llanura (variante) | `same grass plain tile, different small details` |
| `terreno/bosque.png` | Bosque | `dense forest tile, two or three round dark green tree crowns seen from above` |
| `terreno/colina.png` | Colina | `small rocky hill tile, brown and ochre slopes, a few stones` |
| `terreno/rio_recto.png` | Río | `river tile flowing horizontally across, blue water #4F86C6 with light ripples, grassy banks top and bottom` |
| `terreno/rio_curva.png` | Río (curva) | `river tile turning 90 degrees from left edge to bottom edge, same style` |
| `terreno/puente.png` | Puente | `wooden and steel bridge over a river, crossing horizontally, top-down` |
| `terreno/camino_recto.png` | Camino | `dirt road tile running horizontally, sandy beige #C9B48A, wheel tracks` |
| `terreno/camino_curva.png` | Camino (curva) | `dirt road tile turning from left edge to bottom edge` |
| `terreno/camino_cruce.png` | Camino (cruce) | `dirt road crossroads tile, roads to all four edges` |
| `terreno/camino_t.png` | Camino (T) | `dirt road T junction tile, roads to left, right and bottom edges` |
| `terreno/muro.png` | Muro | `thick concrete wall block tile, impassable, gray, top-down` |
| `terreno/ruinas.png` | Ruinas | `ruined building tile, broken walls and rubble, gray-brown` |
| `terreno/barricada.png` | Barricada | `military barricade of sandbags and steel hedgehogs on grass` |

(Los caminos y ríos se giran en el juego para las demás direcciones; con recto, curva, cruce y T basta.)

## 4. Edificios y torretas

256×256, fondo transparente, edificio centrado ocupando casi toda la casilla. Para cada edificio, tres
versiones: **neutral**, **Jade** y **Ámbar** (tejados, banderas y luces del color del bando; la forma igual).
El CG y el cuartel nunca son neutrales: de esos basta con Jade y Ámbar.

| Archivo | Edificio | Prompt |
|---|---|---|
| `edificios/{bando}_cg.png` | Cuartel general | `fortified military headquarters building, command tower with radar dish, the most important building, flag on top` |
| `edificios/{bando}_cuartel.png` | Cuartel | `military barracks and vehicle factory with a big garage door and a small chimney` |
| `edificios/{bando}_ciudad.png` | Ciudad | `small town block with two or three houses and a supply depot with crates` |
| `edificios/{bando}_plaza.png` | Plaza (ciudad central con torreta) | `central town square with a fountain, surrounded by low buildings, strategic place` |

Torretas (fondo transparente, se dibujan encima de la casilla):

| Archivo | Torreta | Prompt |
|---|---|---|
| `torretas/{bando}_plaza.png` | Torreta de plaza (también neutral) | `armored defensive gun turret on a round concrete base, twin barrels` |
| `torretas/{bando}_terrestre.png` | Torreta terrestre (carta) | `compact deployable ground turret, single machine gun barrel, tripod base` |
| `torretas/{bando}_misiles.png` | Torreta lanzamisiles (carta) | `missile launcher turret with a rack of four missiles, angled upward` |
| `torretas/destruida.png` | Torreta destruida | `destroyed turret base, broken barrel, smoke, rubble` |

## 5. Efectos

Fondo negro liso (para usar en modo «suma») o transparente. **Hojas de animación**: varios fotogramas
en fila horizontal, mismo tamaño cada uno.

| Archivo | Efecto | Prompt |
|---|---|---|
| `efectos/explosion.png` | Explosión | `sprite sheet of a cartoon explosion animation, 8 frames in a horizontal row, from small flash to big fireball to smoke, each frame 256x256` |
| `efectos/disparo.png` | Fogonazo | `sprite sheet of a muzzle flash, 4 frames in a row` |
| `efectos/proyectil.png` | Proyectil | `glowing yellow tracer bullet streak, horizontal, small` |
| `efectos/humo.png` | Humo | `sprite sheet of a soft gray smoke puff dissipating, 6 frames in a row` |
| `efectos/impacto.png` | Impacto | `sprite sheet of a small impact spark burst, 4 frames in a row` |
| `efectos/bomba.png` | Bomba (carta aérea) | `cartoon aerial bomb falling, top-down view, with a small fire trail` |
| `efectos/pem.png` | PEM | `blue electric EMP shockwave ring with lightning arcs, top-down` |
| `efectos/bandera_{bando}.png` | Captura | `small flag on a pole being planted, waving` + paleta del bando |

## 6. Cartas (10)

Ilustración 512×768 vertical, sin texto (el nombre y el coste los pone el juego). Plantilla:
`[estilo maestro] + "card illustration, vertical composition, dramatic, " + [prompt] + ", no text, no frame"`

| Archivo | Carta | Prompt |
|---|---|---|
| `cartas/marcha.png` | Orden de marcha | `a commander pointing forward with a radio, a jeep speeding past with motion lines` |
| `cartas/reparacion.png` | Reparación de campo | `engineers welding and repairing a damaged tank with sparks flying` |
| `cartas/pem.png` | PEM | `a blue electromagnetic pulse dome expanding over vehicles, screens and lights shutting off` |
| `cartas/torreta.png` | Torreta terrestre | `soldiers deploying a compact ground turret next to a building` |
| `cartas/refuerzo.png` | Refuerzo de emergencia | `fresh soldiers running out of a headquarters gate, alarm lights` |
| `cartas/hackeo.png` | Hackeo de red | `a hacker's glowing laptop taking control of an enemy turret, digital code lines` |
| `cartas/aereo.png` | Ataque aéreo | `a fighter jet diving and dropping a bomb on a target below, top-down perspective` |
| `cartas/misiles.png` | Torreta lanzamisiles | `a missile launcher turret firing a salvo of missiles into the sky` |
| `cartas/saturacion.png` | Bombardeo de saturación | `many artillery shells raining down on an area, explosions in a grid pattern` |
| `cartas/paracaidistas.png` | Paracaidistas | `a paratrooper descending with a parachute over a battlefield at dawn` |

Marco de carta (uno por bando y uno neutro): `cartas/marco_{bando}.png`, 512×768, `ornate but clean
card frame for a tactics game, empty center, space for title at top and cost circle at top-left, metallic
edges` + paleta.

## 7. Interfaz

| Archivo | Elemento | Tamaño | Prompt |
|---|---|---|---|
| `ui/logo.png` | Logo | 2048×1024 | `game logo text "TACTIC WARS", bold military stencil letters with metallic bevel, jade green and amber orange split, crossed tank shells behind, transparent background` (usar Ideogram o una IA que escriba bien el texto) |
| `ui/icono_app.png` | Icono de la app | 1024×1024 | `mobile app icon, a tank turret and a soldier helmet in a shield, half jade green half amber orange, rounded square, no text` |
| `ui/fondo_menu.png` | Fondo del menú | 2400×1080 | `wide panoramic battlefield at sunset seen from a hill, jade army on the left and amber army on the right facing each other, town in the middle, space in the center for the logo` |
| `ui/fondo_preparacion.png` | Fondo de la preparación | 2400×1080 | `military war room with a big map table and screens, dim lighting, blurred, low contrast so text can go on top` |
| `ui/iconos.png` | Iconos | 8×128×128 en fila | `set of 8 flat game UI icons in a horizontal row, white with dark outline: lightning bolt (action points), crates (supplies), building (buildings), stopwatch (clock), speaker (sound), playing card (cards), star (commander), shield (defense)` |
| `ui/boton.png` | Botón | 512×128 | `game UI button, dark slate #2A3036 with subtle metallic border, empty, no text` |
| `ui/panel.png` | Panel | 512×512 | `game UI panel background, dark slate with thin metallic frame and rivets, empty center, 9-slice friendly` |
| `ui/victoria.png` | Victoria | 1024×512 | `victory banner with laurels and stars, empty center for text` |
| `ui/derrota.png` | Derrota | 1024×512 | `defeat banner, torn flag and smoke, empty center for text` |

## 8. Lista de comprobación

- [ ] Imagen ancla aprobada (Tanque Jade)
- [ ] 18 unidades (9 × 2 bandos) + 2 retratos de comandante
- [ ] 14 casillas de terreno
- [ ] 10 edificios (CG y cuartel × 2 bandos; ciudad y plaza × neutral/Jade/Ámbar) + 8 torretas (plaza × 3, terrestre y lanzamisiles × 2, destruida)
- [ ] 9 efectos (incluye 2 banderas)
- [ ] 10 ilustraciones de carta + 3 marcos
- [ ] 9 elementos de interfaz

Con las unidades, el terreno y los edificios ya se puede sustituir todo el dibujo actual del tablero;
cartas, efectos e interfaz pueden llegar después.

## 9. Revisión de la primera entrega (23-10-2026)

Integrado en el prototipo (versión 0.4). Arreglado con `preparar_arte.py`, sin volver a generar:

- Caminos y ríos no empalmaban (cada pieza tenía la franja a otra altura y con otro ancho): se generan
  las 16 piezas de cada uno a partir de la textura de la recta, más cuartos de lago y la pasarela.
- `camino_cruce` y `camino_t` venían con los nombres intercambiados (ya no se usan: se generan).
- Torreta destruida cortada por los bordes: reducida y centrada.
- `llanura_2` más clara que `llanura`: igualado el tono.
- Cartas: recortada la ilustración (sin margen ni rótulo).

Pendiente de generar de nuevo con la otra IA:

1. **Las 10 cartas** como ilustraciones individuales a 512×768 (prompts de la sección 6).
2. **La artillería de Ámbar** con la misma forma que la de Jade (obús blindado con patas de apoyo),
   cambiando solo los colores: prompt de la sección 2 con la imagen `unidades/jade_artilleria.png` como
   referencia y «same vehicle, recolor to the amber faction palette».
