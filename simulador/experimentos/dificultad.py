"""Fuerza de la IA según el ruido: cada nivel juega contra el normal (0.3), cambiando de bando y de primero."""
import json, sys, random
from multiprocessing import Pool
sys.path.insert(0, ".")
from tw_sim.play import play_game
from tw_sim.rules import Config
CFG = json.load(open("experiments.json"))["REGLAS_ACTUALES"]["config"]
ARMIES = ["equilibrado4", "blindado4", "artilleria4", "rapido4", "infanteria4", "ingenieros4", "hacker4"]

def one(args):
    noise, i = args
    rnd = random.Random(i)
    a0, a1 = rnd.choice(ARMIES), rnd.choice(ARMIES)
    side = i % 2                     # bando del nivel probado
    noises = (noise, 0.3) if side == 0 else (0.3, noise)
    g = play_game("Cuatro plazas", a0, a1, first=(i // 2) % 2, seed=50000 + i, config=Config(**CFG), noises=noises)
    return noise, (1.0 if g.winner == side else 0.5 if g.winner not in (0, 1) else 0.0)

if __name__ == "__main__":
    levels = [0.0, 0.1, 0.3, 0.6, 1.0, 1.5, 2.5]
    n = int(sys.argv[1])
    jobs = [(nz, i) for nz in levels for i in range(n)]
    with Pool(4) as p:
        res = p.map(one, jobs)
    for nz in levels:
        r = [x for k, x in res if k == nz]
        m = sum(r) / len(r)
        se = (m * (1 - m) / len(r)) ** 0.5
        print(f"ruido {nz:4.1f}: gana {m*100:5.1f} % contra el normal (±{1.96*se*100:.1f})")
