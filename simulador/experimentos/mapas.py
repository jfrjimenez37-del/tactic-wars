"""Los mapas del simulador con las reglas actuales: ventaja del que empieza, duración y cómo terminan."""
import json, sys, random
from collections import Counter
from multiprocessing import Pool
sys.path.insert(0, ".")
from tw_sim.play import play_game
from tw_sim.rules import Config, MAPS
CFG = json.load(open("experiments.json"))["REGLAS_ACTUALES"]["config"]
ARMIES = ["equilibrado4", "blindado4", "artilleria4", "rapido4", "infanteria4", "ingenieros4", "hacker4"]

def one(args):
    m, i = args
    rnd = random.Random(i)
    a0, a1 = rnd.choice(ARMIES), rnd.choice(ARMIES)
    first = i % 2
    g = play_game(m, a0, a1, first=first, seed=90000 + i, config=Config(**CFG))
    return m, g.winner, first, min(g.round, 20), g.how, (a0, a1)

if __name__ == "__main__":
    n = int(sys.argv[1])
    with Pool(4) as p:
        res = p.map(one, [(m, i) for m in MAPS for i in range(n)])
    print(f"{'mapa':26s} {'gana J1':>8s} {'ronda 20':>9s} {'rondas':>7s}  final (dominio / CG / eliminación)  dif. ejércitos")
    for m in MAPS:
        r = [x for x in res if x[0] == m]
        dec = [x for x in r if x[1] in (0, 1)]
        j1 = sum(1 for x in dec if x[1] == x[2]) / max(1, len(dec))
        r20 = sum(1 for x in r if x[4].startswith("ronda_limite") or x[4] == "empate") / len(r)
        rounds = sum(x[3] for x in r) / len(r)
        how = Counter(x[4] for x in r)
        wins = Counter(); plays = Counter()
        for x in dec:
            for s in (0, 1):
                plays[x[5][s]] += 1
                wins[x[5][s]] += x[1] == s
        rates = [wins[a] / plays[a] for a in ARMIES if plays[a] >= 20]
        spread = (max(rates) - min(rates)) * 100 if rates else 0
        print(f"{m:26s} {j1*100:7.1f}% {r20*100:8.1f}% {rounds:7.1f}  {how['dominio']:3d} / {how['captura_CG']:3d} / {how['eliminacion']:3d}"
              f"   {spread:5.1f} pts (peor {min(rates)*100:.0f} %, mejor {max(rates)*100:.0f} %)")
