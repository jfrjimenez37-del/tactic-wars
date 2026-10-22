#!/bin/sh
# Experimentos de la propuesta 4+2+personaje y de remontadas
cd "$(dirname "$0")"
for e in $(python3 -c "import json;print(' '.join(k for k in json.load(open('experiments.json')) if k[:2] in ('R_','H_')))"); do
  python3 run.py "$e" --workers 4
done
echo FIN
