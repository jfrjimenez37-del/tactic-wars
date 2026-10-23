"""Mapas más grandes con las reglas actuales: duración, cómo terminan y equilibrio.
Variantes: dominio proporcional al número de edificios y 20 o 25 rondas."""
import json, sys, random
from collections import Counter
from multiprocessing import Pool
sys.path.insert(0, ".")
import tw_sim.rules as rules
from tw_sim.play import play_game, setup, duration_fields
from tw_sim.rules import Config

GRANDES = {
    "Gran frente 16x10": ["..U..BB.U...C...",
                          ".Q=..C......B.U.",
                          "..=..~~P~~...=..",
                          "..=.#..BU..r.=..",
                          "H====.....C====."],
    "Campaña 20x12":     ["..U...B...U..C....U.",
                          ".Q=..CC.....B..=....",
                          "..=...~~~P~~.....=..",
                          "..U.#.B...B..r...=..",
                          "..=..r..C.U..B..C=..",
                          "H=====.....#...====="],
}
rules.MAPS.update(GRANDES)
BASE = json.load(open("experiments.json"))["REGLAS_ACTUALES"]["config"]
ARMIES = ["equilibrado4", "blindado4", "artilleria4", "rapido4", "infanteria4", "ingenieros4", "hacker4"]
VARIANTES = [("Cuatro plazas", 7, 20), ("Gran frente 16x10", 8, 20), ("Gran frente 16x10", 8, 25),
             ("Gran frente 16x10", 9, 20), ("Campaña 20x12", 10, 20), ("Campaña 20x12", 10, 25)]

def one(args):
    k, i = args
    m, dom, rounds = VARIANTES[k]
    rnd = random.Random(i)
    a0, a1 = rnd.choice(ARMIES), rnd.choice(ARMIES)
    cfg = Config(**dict(BASE, domination=dom, rounds=rounds))
    g = play_game(m, a0, a1, first=i % 2, seed=95000 + i, config=cfg)
    return k, g.winner, i % 2, min(g.round, rounds), g.how, duration_fields(g)["est_minutes"], (a0, a1)

if __name__ == "__main__":
    for m in GRANDES:
        g = setup(m, "equilibrado4", "equilibrado4", 0, 1, Config(**BASE))
        print(f"{m}: {rules.W}x{rules.H}, {len(g.owner)} edificios, {len(g.turrets)} plazas con torreta")
    n = int(sys.argv[1])
    with Pool(4) as p:
        res = p.map(one, [(k, i) for k in range(len(VARIANTES)) for i in range(n)])
    print(f"{'variante':34s} {'gana J1':>8s} {'llega al final':>15s} {'rondas':>7s} {'minutos':>8s}  dominio / CG   dif. ejércitos")
    for k, (m, dom, rounds) in enumerate(VARIANTES):
        r = [x for x in res if x[0] == k]
        dec = [x for x in r if x[1] in (0, 1)]
        j1 = sum(1 for x in dec if x[1] == x[2]) / max(1, len(dec))
        lim = sum(1 for x in r if x[4].startswith("ronda_limite") or x[4] == "empate") / len(r)
        how = Counter(x[4] for x in r)
        wins, plays = Counter(), Counter()
        for x in dec:
            for s in (0, 1):
                plays[x[6][s]] += 1
                wins[x[6][s]] += x[1] == s
        rates = [wins[a] / plays[a] for a in ARMIES if plays[a] >= 20]
        name = f"{m}, dominio {dom}, {rounds} rondas"
        print(f"{name:34s} {j1*100:7.1f}% {lim*100:14.1f}% {sum(x[3] for x in r)/len(r):7.1f} {sum(x[5] for x in r)/len(r):8.1f}"
              f"  {how['dominio']:4d} / {how['captura_CG']:3d}   {(max(rates)-min(rates))*100:5.1f} pts")
