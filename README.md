# TACTIC WARS

Juego de táctica por turnos para Android (estilo Advance Wars). Este repositorio contiene la capa 0:

| Carpeta | Qué es |
|---|---|
| `simulador/` | Motor de reglas en Python, bots y experimentos que se usaron para equilibrar el reglamento. Ver su README. |
| `prototipo/` | Prototipo jugable en Godot 4.3 (preparación, despliegue, partida contra la IA o entre dos personas, exportación a Android). Ver su README. |

Documentos de diseño (en Claude Docs): Reglamento capa 0 v2 y Concepto v2.

El motor y la IA de Godot están verificados contra el simulador: las partidas de referencia exportadas
desde Python (`simulador/export_golden.py`) se reproducen en Godot con el mismo estado turno a turno y
las mismas decisiones de la IA.
