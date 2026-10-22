# Simulador de TACTIC WARS — capa 0

Herramienta reproducible para probar el reglamento de la capa 0 (C1–C13 con las aclaraciones A1–A8)
con bots. Solo usa la biblioteca estándar de Python 3.10 o superior.

## Estructura

| Archivo | Qué hace |
|---|---|
| `tw_sim/rules.py` | Motor de reglas determinista: mapas, unidades, tabla de daño, `legal_actions()`, `apply()`, `state_hash()`. No sabe nada de bots. |
| `tw_sim/bots.py` | `HeuristicBot` (estilos normal, agresivo, prudente, económico; construye barricadas, puentes y derriba muros) y `RandomBot`. Solo eligen entre acciones legales. |
| `tw_sim/play.py` | Despliegue, ejércitos, `play_game()` y `replay()` (reproduce una partida desde su registro y comprueba que cada acción era legal). |
| `tests/test_rules.py` | 81 pruebas: una o más por regla (C1–C13, A1–A8), tripulaciones, terreno destructible, conectividad y reproducibilidad. |
| `experiments.json` | Definición de cada experimento: partidas, semilla inicial, ejércitos, estilos y variantes de reglas. |
| `run.py` | Ejecuta un experimento y guarda una fila de CSV por partida en `results/`. |
| `analyze.py` | Resume los CSV (victorias con intervalo de confianza, tipo de final, bajas por unidad, uso de mecánicas). |
| `run_all.sh` | Repite todos los experimentos y escribe `results/resumen.txt`. |

## Uso

```sh
python3 -m unittest discover -s tests -v     # pruebas de reglas
python3 run.py --list                         # experimentos disponibles
python3 run.py base                           # 300 partidas -> results/base.csv
python3 run.py base --games 4 --log           # guarda también el registro de acciones
python3 analyze.py base iniciativa            # resumen
./run_all.sh                                  # todo (unos 20 minutos con 4 núcleos)
```

## Reproducibilidad

- Cada partida tiene una semilla (`seed` en el CSV). El despliegue usa `seed*1009+bando` y cada bot `seed*7919+bando`.
- Misma semilla, ejércitos, mapa, quién empieza y configuración → misma partida. La columna `final_hash`
  permite comprobarlo: si se repite un experimento, los hashes deben coincidir fila a fila.
- Con `--log` se guarda la lista de acciones; `play.replay()` la vuelve a jugar validando cada acción.
- Las variantes de reglas se activan con `config` en `experiments.json`
  (`damage`, `tiebreak`, `lead`, `rounds`, `hq_points`, `hq_produces`, `pm`, `limit`, `counter`, `heal`,
  `build_extra`, `build_mult`, `crew`).
- Propuesta en estudio: ejércitos `*4` (4 vehículos + 2 a pie; `T*` = vehículo con el personaje).
  `./run_propuesta.sh` repite sus experimentos (prefijos `R_` y `H_`).
- Remontadas: cada fila guarda la ventaja material por ronda (`adv_r5`, `adv_r10`, `adv_r15`, `winner_worst`).
  Los experimentos `H_` enfrentan un bot fuerte (ruido 0.3) contra uno flojo (ruido 2.0), con o sin un tanque menos.
  Ninguna variante cambia el reglamento: solo sirven para comparar.

## Límites

Los bots son heurísticos: juegan razonablemente (ganan al azar 80 de 80), pero no como personas.
Los resultados indican tendencias y problemas probables; no sustituyen a las partidas en papel.
