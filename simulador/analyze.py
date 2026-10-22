"""Resume uno o varios CSV de results/.  Uso: python3 analyze.py base iniciativa ...  (sin argumentos: todos)"""
from __future__ import annotations

import csv
import math
import os
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
UNITS = "FAITJRP"


def ci(k, n):
    """Proporcion con intervalo de confianza del 95 % (aproximacion normal)."""
    if n == 0:
        return "-"
    p = k / n
    return f"{100 * p:.1f} % ±{196 * math.sqrt(p * (1 - p) / n):.1f}"


def load(name):
    with open(os.path.join(HERE, "results", f"{name}.csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def summarize(name, rows):
    n = len(rows)
    dec = [r for r in rows if r["winner"] not in ("", "None", "-1")]
    print(f"\n=== {name}: {n} partidas")
    how = Counter(r["how"] for r in rows)
    print("  final:", ", ".join(f"{k} {100 * v / n:.0f} %" for k, v in how.most_common()))
    early = [r for r in rows if not (r["how"].startswith("ronda_limite") or r["how"] == "empate")]
    print(f"  terminan antes del final de la ronda 20: {100 * len(early) / n:.1f} %"
          + (f" (ronda media {sum(int(r['rounds']) for r in early) / len(early):.1f})" if early else ""))
    rounds = sorted(int(r["rounds"]) for r in rows)
    print(f"  rondas: media {sum(rounds) / n:.1f}, mediana {rounds[n // 2]}")
    print("  gana quien empieza:", ci(sum(1 for r in dec if r["winner"] == r["first"]), len(dec)))
    print("  gana el bando 0:", ci(sum(1 for r in dec if r["winner"] == "0"), len(dec)))
    if n - len(dec):
        print(f"  empates: {100 * (n - len(dec)) / n:.1f} %")
    kills = {t: sum(int(r[f"kills_{t}"]) for r in rows) for t in UNITS}
    tot = sum(kills.values()) or 1
    print("  bajas causadas por:", ", ".join(f"{t} {100 * v / tot:.0f} %" for t, v in kills.items() if v))
    per = lambda k: sum(int(r[k]) for r in rows) / n  # noqa: E731
    print(f"  por partida: barricadas {per('barricades_built_0') + per('barricades_built_1'):.2f}, "
          f"puentes {per('bridges'):.2f}, muros {per('walls'):.2f}, desembarcos {per('dismount_0') + per('dismount_1'):.2f}, "
          f"eyecciones {per('eject_0') + per('eject_1'):.2f}, subidas {per('board_0') + per('board_1'):.2f}, "
          f"reparaciones {per('repairs_0') + per('repairs_1'):.2f}")
    flips = [r for r in rows if r["last_turn_flip"] == "1"]
    if flips:
        print(f"  la ultima accion cambia el ganador del desempate: {100 * len(flips) / n:.1f} %")
    comebacks(rows, dec)
    if "est_minutes" in rows[0]:
        est = sorted(float(r["est_minutes"]) for r in rows)
        print(f"  duracion estimada en el movil: media {sum(est) / n:.1f} min (10 % de las partidas: menos de {est[n // 10]:.1f}; "
              f"90 %: menos de {est[9 * n // 10]:.1f}); maximo con el reloj agotado {max(float(r['max_minutes']) for r in rows):.1f} min; "
              f"{sum(float(r['actions_per_turn']) for r in rows) / n:.1f} acciones por turno")
    if "hacks" in rows[0] and any(r["hacks"] not in ("0", "") for r in rows):
        print(f"  vehiculos robados por hackers por partida: {sum(int(r['hacks']) for r in rows) / n:.2f}")
    if "turret_shots" in rows[0] and any(r["turret_shots"] not in ("0", "") for r in rows):
        print(f"  torretas por partida: {per('turret_shots'):.1f} disparos, {per('turret_kills'):.2f} bajas, "
              f"{per('turrets_destroyed'):.2f} destruidas, {per('sabotages'):.2f} sabotajes, {per('turret_repairs'):.2f} reparaciones")
    if "deck_0" in rows[0] and rows[0]["deck_0"]:
        cards = sorted({c for r in rows for x in (0, 1) for c in r[f"deck_{x}"].split("+") if c})
        stats = []
        for c in cards:
            w = g = 0
            for r in dec:
                has = [c in r["deck_0"].split("+"), c in r["deck_1"].split("+")]
                if has[0] != has[1]:
                    g += 1
                    w += r["winner"] == ("0" if has[0] else "1")
            uses = sum(int(r.get(f"card_{c}", 0)) for r in rows) / max(1, sum(r["deck_0"].count(c) + r["deck_1"].count(c) for r in rows))
            stats.append((w / g if g else 0, c, g, uses))
        print("  cartas (gana quien la lleva y el rival no; usos por partida en que se lleva): " + ", ".join(
            f"{c} {100 * p:.0f} % ({g}) x{u:.1f}" for p, c, g, u in sorted(stats, reverse=True)))
    if "trainings" in rows[0] and any(r["trainings"] not in ("0", "") for r in rows):
        print(f"  evoluciones de tripulacion por partida: {sum(int(r['trainings']) for r in rows) / n:.2f}")
    if "char_deaths" in rows[0] and any(r["army_0"].endswith(("4", "_J", "_R")) for r in rows):
        print(f"  personaje: muere en {per('char_deaths'):.2f} y sale eyectado {per('char_eject'):.2f} veces por partida")
    if "noises" in rows[0] and rows[0]["noises"].split("/")[0] != rows[0]["noises"].split("/")[1]:
        hc = rows[0].get("handicap", "/")
        print(f"  gana el jugador fuerte (bando 0{', sin ' + hc.split('/')[0] if hc.split('/')[0] else ''}):",
              ci(sum(1 for r in dec if r["winner"] == "0"), len(dec)))
    if len({(r["army_0"], r["army_1"]) for r in rows}) > 1:
        wins, games = defaultdict(int), defaultdict(int)
        for r in dec:
            for s in (0, 1):
                games[r[f"army_{s}"]] += 1
                wins[r[f"army_{s}"]] += r["winner"] == str(s)
        print("  victorias por ejercito:", ", ".join(f"{a} {ci(wins[a], games[a])}" for a in sorted(games, key=lambda a: -wins[a] / games[a])))
    if len({r["styles"] for r in rows}) == 1 and rows[0]["styles"].split("/")[0] != rows[0]["styles"].split("/")[1]:
        st = rows[0]["styles"].split("/")[0]
        # jobs_for intercambia bandos de ejercito, no de estilo: el estilo 0 es siempre el bando 0
        print(f"  gana el estilo {st}:", ci(sum(1 for r in dec if r["winner"] == "0"), len(dec)))
    if rows[0].get("experiment", "").endswith("iniciativa") or "iniciativa" in name:
        paired(rows)


def comebacks(rows, dec):
    """Remontadas: el ganador llego a ir por detras en ventaja material (ronda 3 o mas)."""
    if not rows or "winner_worst" not in rows[0]:
        return
    ww = [float(r["winner_worst"]) for r in dec if r["winner_worst"] not in ("", "None")]
    if not ww:
        return
    n = len(ww)
    print(f"  remontadas: el ganador fue por detras al menos un 10 % en {100 * sum(x <= -0.10 for x in ww) / n:.0f} % "
          f"y al menos un 20 % en {100 * sum(x <= -0.20 for x in ww) / n:.0f} % de las partidas con ganador")
    for rr in ("adv_r5", "adv_r10"):
        trail = [(float(r[rr]), r["winner"]) for r in dec if r[rr] not in ("", "None") and abs(float(r[rr])) >= 0.15]
        if trail:
            k = sum(1 for a, w in trail if (a < 0 and w == "0") or (a > 0 and w == "1"))
            print(f"  quien va por detras un 15 % o mas en la ronda {rr[5:]} acaba ganando: {ci(k, len(trail))} "
                  f"({len(trail)} partidas)")


def paired(rows):
    by = defaultdict(dict)
    for r in rows:
        by[r["seed"]][r["first"]] = r["winner"]
    both = [v for v in by.values() if len(v) == 2]
    same = sum(1 for v in both if v["0"] == v["1"])
    j1 = sum((v["0"] == "0") + (v["1"] == "1") for v in both)
    print(f"  emparejada: {len(both)} semillas; el ganador no cambia al cambiar quien empieza en {100 * same / len(both):.0f} %; "
          f"gana quien empieza {ci(j1, 2 * len(both))}")
    swing = Counter("J1" if (v["0"] == "0" and v["1"] == "1") else "J2" if (v["0"] == "1" and v["1"] == "0") else "=" for v in both)
    print(f"  semillas donde gana siempre quien empieza: {swing['J1']}, siempre el segundo: {swing['J2']}")


def main():
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(os.path.join(HERE, "results")) if f.endswith(".csv"))
    for name in names:
        summarize(name, load(name))


if __name__ == "__main__":
    main()
