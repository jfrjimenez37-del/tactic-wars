#!/bin/sh
# Repite todos los experimentos de experiments.json (unos 20 minutos con 4 nucleos)
cd "$(dirname "$0")"
for e in $(python3 -c "import json;print(' '.join(json.load(open('experiments.json'))))"); do
  python3 run.py "$e" --workers 4
done
python3 analyze.py > results/resumen.txt
