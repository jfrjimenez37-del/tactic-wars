"""Mapas candidatos con la receta de Cuatro plazas (4 plazas equidistantes, 10 edificios, simetría de punto).
Se simulan con las reglas actuales frente a Cuatro plazas, con las mismas semillas."""
import json, sys, random
from collections import Counter
from multiprocessing import Pool
sys.path.insert(0, ".")
import tw_sim.rules as rules
from tw_sim.play import play_game, setup
from tw_sim.rules import Config
CFG = json.load(open("experiments.json"))["REGLAS_ACTUALES"]["config"]
ARMIES = ["equilibrado4", "blindado4", "artilleria4", "rapido4", "infanteria4", "ingenieros4", "hacker4"]
# Mitad de abajo (filas 1 a 4); la de arriba es la misma girada 180°.
CANDIDATOS = {
    "Río central": ["..U..~...C..",
                    ".Q=..PU..B..",
                    "..=.B~..=...",
                    "H===.~U...B."],
    "Desfiladero": ["..U.C.UB.C..",
                    ".Q=.B..B..C.",
                    "..=..CU.B...",
                    "H===.B..C.B."],
    "Murallas":    ["..U.#.U.r...",
                    ".Q=.#..#..r.",
                    "..==r..#.=..",
                    "H=..#.U.r==."],
}
rules.MAPS.update(CANDIDATOS)
MAPAS = ["Cuatro plazas"] + list(CANDIDATOS)

def one(args):
    m, i = args
    rnd = random.Random(i)
    a0, a1 = rnd.choice(ARMIES), rnd.choice(ARMIES)
    first = i % 2
    g = play_game(m, a0, a1, first=first, seed=90000 + i, config=Config(**CFG))
    return m, g.winner, first, min(g.round, 20), g.how, (a0, a1)

def check(m):
    g = setup(m, "equilibrado4", "equilibrado4", 0, 1, Config(**CFG))
    b = Counter(o for o in g.owner.values())
    return f"{m}: {len(g.owner)} edificios ({b[0]} Jade, {b[1]} Ámbar, {b[None]} neutrales), {len(g.turrets)} plazas con torreta"

if __name__ == "__main__":
    for m in MAPAS:
        print(check(m))
    n = int(sys.argv[1])
    with Pool(4) as p:
        res = p.map(one, [(m, i) for m in MAPAS for i in range(n)])
    print(f"{'mapa':16s} {'gana J1':>8s} {'ronda 20':>9s} {'rondas':>7s}  final (dominio / CG)  dif. ejércitos")
    for m in MAPAS:
        r = [x for x in res if x[0] == m]
        dec = [x for x in r if x[1] in (0, 1)]
        j1 = sum(1 for x in dec if x[1] == x[2]) / max(1, len(dec))
        r20 = sum(1 for x in r if x[4].startswith("ronda_limite") or x[4] == "empate") / len(r)
        how = Counter(x[4] for x in r)
        wins, plays = Counter(), Counter()
        for x in dec:
            for s in (0, 1):
                plays[x[5][s]] += 1
                wins[x[5][s]] += x[1] == s
        rates = {a: wins[a] / plays[a] for a in ARMIES if plays[a] >= 20}
        lo, hi = min(rates, key=rates.get), max(rates, key=rates.get)
        print(f"{m:16s} {j1*100:7.1f}% {r20*100:8.1f}% {sum(x[3] for x in r)/len(r):7.1f}  {how['dominio']:3d} / {how['captura_CG']:3d}"
              f"   {(rates[hi]-rates[lo])*100:5.1f} pts (peor {lo} {rates[lo]*100:.0f} %, mejor {hi} {rates[hi]*100:.0f} %)")
