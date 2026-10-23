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

## Mapas más grandes (bocetos para medir el efecto del tamaño)

200 partidas por variante. «Minutos» es la estimación del simulador para el móvil (`duration_fields`).
Desde `simulador/`: `python3 experimentos/mapas_grandes.py 200`.

| Variante | Gana J1 | Llegan al final | Rondas | Minutos | Dominio / CG | Diferencia entre ejércitos |
|---|---|---|---|---|---|---|
| Cuatro plazas 12×8, dominio 7 de 10, 20 rondas | 51,5 % | 66,0 % | 18,2 | 13,2 | 39 / 29 | 35,6 pts |
| Gran frente 16×10, dominio 8 de 12, 20 rondas | 45,0 % | 77,0 % | 18,9 | 14,3 | 15 / 31 | 43,3 pts |
| Gran frente 16×10, dominio 8 de 12, 25 rondas | 45,5 % | 63,0 % | 22,4 | 17,0 | 33 / 41 | 27,4 pts |
| Gran frente 16×10, dominio 9 de 12, 20 rondas | 45,0 % | 84,5 % | 19,0 | 14,5 | 0 / 31 | 43,3 pts |
| Campaña 20×12, dominio 10 de 14, 20 rondas | 48,5 % | 81,0 % | 19,0 | 14,6 | 0 / 38 | 25,3 pts |
| Campaña 20×12, dominio 10 de 14, 25 rondas | 51,5 % | 69,0 % | 22,8 | 17,7 | 1 / 61 | 16,5 pts |

Conclusiones: con el ejército y las 20 rondas actuales, los mapas grandes vuelven a llevar la mayoría de
las partidas al final; con 25 rondas se recupera la proporción de Cuatro plazas a cambio de ~4–5 minutos
más. El dominio al 70 % casi nunca se alcanza en mapas grandes (hace falta un umbral más bajo). Los
ejércitos quedan más igualados cuanto mayor es el mapa.
