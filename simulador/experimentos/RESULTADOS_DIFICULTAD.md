# Dificultad de la IA (23-10-2026)

200 partidas por nivel contra la IA normal (ruido 0,3, umbral 0,4), mapa Cuatro plazas, reglas actuales,
ejércitos al azar, cambiando de bando y de quién empieza. Se ejecuta desde `simulador/`:
`python3 experimentos/dificultad.py 200` y `python3 experimentos/estilos.py 200`.

| Variante | Gana a la normal (IC 95 %) |
|---|---|
| ruido 0,0 | 49,8 % (±6,9) |
| ruido 0,1 | 43,5 % (±6,9) |
| ruido 0,3 (normal contra sí misma) | 49,5 % (±6,9) |
| ruido 0,6 | 41,5 % (±6,8) |
| ruido 1,0 | 35,5 % (±6,6) |
| ruido 1,5 | 28,5 % (±6,3) |
| ruido 2,5 | 10,0 % (±4,2) |
| estilo agresivo | 62,5 % (±6,7) |
| estilo prudente | 42,0 % (±6,8) |
| estilo económico | 48,5 % (±6,9) |
| umbral 0,0 | 47,5 % (±6,9) |
| umbral 0,8 | 24,0 % (±5,9) |
| umbral −0,5 | 47,5 % (±6,9) |

Niveles elegidos para el prototipo: Fácil = ruido 1,5; Normal = ruido 0,3; Difícil = estilo agresivo.
