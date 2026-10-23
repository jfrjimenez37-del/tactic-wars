# Mapas con las reglas actuales (23-10-2026)

300 partidas por mapa, IA normal contra IA normal, ejércitos al azar, alternando quién empieza.
Desde `simulador/`: `python3 experimentos/mapas.py 300` y `python3 experimentos/mapas_nuevos.py 300`.

## Mapas que ya tenía el simulador

| Mapa | Gana J1 | Llegan a la ronda 20 | Rondas | Dominio / captura del CG | Diferencia entre ejércitos |
|---|---|---|---|---|---|
| Encrucijada | 46,0 % | 78,7 % | 18,1 | 4 / 60 | 23 pts |
| Ciudad en ruinas | 56,0 % | 83,3 % | 19,0 | 7 / 43 | 11 pts |
| Plaza central | 56,3 % | 86,0 % | 19,3 | 10 / 30 | 17 pts |
| Isla central | 43,0 % | 81,3 % | 18,5 | 1 / 55 | 33 pts |
| **Cuatro plazas** (el actual) | 52,0 % | 71,3 % | 18,4 | 56 / 30 | 41 pts |
| Cuatro plazas escalonada | 56,3 % | 80,0 % | 19,0 | 28 / 32 | 48 pts |

Diseñados para reglas anteriores: con las actuales alargan las partidas.

## Candidatos nuevos con la receta de Cuatro plazas

4 plazas con torreta a la misma distancia de los dos CG, 3 edificios propios por bando (10 en total),
simetría de punto. Mismas semillas que Cuatro plazas.

| Mapa | Gana J1 | Llegan a la ronda 20 | Rondas | Dominio / captura del CG | Diferencia entre ejércitos |
|---|---|---|---|---|---|
| Cuatro plazas | 52,0 % | 71,3 % | 18,4 | 56 / 30 | 41 pts (peor ingenieros4 22 %, mejor infanteria4 63 %) |
| Río central | 42,3 % | 51,7 % | 16,5 | 50 / 92 | 33 pts (peor ingenieros4 30 %, mejor infanteria4 63 %) |
| Desfiladero | 48,2 % | 54,0 % | 16,0 | 34 / 99 | 47 pts (peor ingenieros4 17 %, mejor blindado4 65 %) |
| Murallas | 56,3 % | 86,7 % | 19,6 | 26 / 14 | 30 pts (peor ingenieros4 35 %, mejor infanteria4 65 %) |
