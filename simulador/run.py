"""Ejecuta experimentos definidos en experiments.json y guarda una fila de CSV por partida.

Uso:
    python3 run.py --list
    python3 run.py base --games 100 --workers 4
    python3 run.py base --games 2 --log      # guarda tambien el registro de acciones de cada partida
Cada partida usa una semilla fija (semilla_inicial + indice), asi que repetir el comando da los mismos resultados.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tw_sim.play import play_game, summary_row  # noqa: E402
from tw_sim.rules import MAP_SETS, Config  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def jobs_for(name, spec, games):
    """Reparte las partidas por mapa, alternando quien empieza y en que bando va cada ejercito."""
    maps = spec.get("maps", MAP_SETS["actuales"])
    if isinstance(maps, str):
        maps = MAP_SETS[maps]
    matchups = spec.get("matchups", [["equilibrado", "equilibrado"]])
    jobs = []
    i = 0
    seed0 = spec.get("seed", 1000)
    while len(jobs) < games:
        for m in maps:
            for a0, a1 in matchups:
                if len(jobs) >= games:
                    break
                swap = (i // 2) % 2 == 1          # cambia de bando cada 2 partidas
                first = i % 2                      # alterna quien empieza
                armies = (a1, a0) if swap else (a0, a1)
                jobs.append(dict(experiment=name, map=m, army_0=armies[0], army_1=armies[1], first=first,
                                 seed=seed0 + i, bots=spec.get("bots", ["heuristico", "heuristico"]),
                                 styles=spec.get("styles", ["normal", "normal"]), config=spec.get("config", {}),
                                 noises=spec.get("noises", [0.3, 0.3]), handicap=spec.get("handicap", [[], []]),
                                 paired=spec.get("paired", False)))
                i += 1
    if spec.get("paired"):
        # prueba emparejada: cada semilla se juega dos veces cambiando solo quien empieza
        paired = []
        for j in jobs[: games // 2]:
            for f in (0, 1):
                paired.append(dict(j, first=f))
        jobs = paired
    return jobs


def run_one(job):
    cfg = Config(**job["config"])
    g = play_game(job["map"], job["army_0"], job["army_1"], first=job["first"], seed=job["seed"], config=cfg,
                  bots=tuple(job["bots"]), styles=tuple(job["styles"]), noises=tuple(job["noises"]),
                  handicap=tuple(tuple(h) for h in job["handicap"]))
    meta = {k: job[k] for k in ("experiment", "map", "army_0", "army_1", "first", "seed")}
    meta["bots"] = "/".join(job["bots"])
    meta["styles"] = "/".join(job["styles"])
    meta["config"] = json.dumps(job["config"], sort_keys=True)
    meta["noises"] = "/".join(map(str, job["noises"]))
    meta["handicap"] = "/".join("".join(h) for h in job["handicap"])
    return summary_row(g, meta), g.log


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("experiment", nargs="?")
    ap.add_argument("--games", type=int, default=None)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default=None)
    ap.add_argument("--log", action="store_true")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()
    exps = json.load(open(os.path.join(HERE, "experiments.json"), encoding="utf-8"))
    if args.list or not args.experiment:
        for k, v in exps.items():
            print(f"{k:28s} {v.get('description', '')}")
        return
    spec = exps[args.experiment]
    games = args.games or spec.get("games", 100)
    jobs = jobs_for(args.experiment, spec, games)
    with Pool(args.workers) as p:
        results = p.map(run_one, jobs, chunksize=2)
    out = args.out or os.path.join(HERE, "results", f"{args.experiment}.csv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    rows = [r for r, _ in results]
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    if args.log:
        with open(out.replace(".csv", "_log.json"), "w", encoding="utf-8") as f:
            json.dump([{"seed": r["seed"], "first": r["first"], "map": r["map"], "log": lg} for r, lg in results], f)
    print(f"{len(rows)} partidas -> {out}")


if __name__ == "__main__":
    main()
