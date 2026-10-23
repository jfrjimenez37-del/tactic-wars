"""¿Algún estilo o umbral de la IA gana al normal? Mismo esquema: cambia de bando y de primero."""
import json, sys, random
from multiprocessing import Pool
sys.path.insert(0, ".")
from tw_sim.play import setup
from tw_sim.bots import HeuristicBot
from tw_sim.rules import Config
CFG = json.load(open("experiments.json"))["REGLAS_ACTUALES"]["config"]
ARMIES = ["equilibrado4", "blindado4", "artilleria4", "rapido4", "infanteria4", "ingenieros4", "hacker4"]
VARIANTS = {"agresivo": ("agresivo", 0.3, 0.4), "prudente": ("prudente", 0.3, 0.4), "economico": ("economico", 0.3, 0.4),
            "umbral 0.0": ("normal", 0.3, 0.0), "umbral 0.8": ("normal", 0.3, 0.8), "umbral -0.5": ("normal", 0.3, -0.5)}

def one(args):
    name, i = args
    rnd = random.Random(i)
    a0, a1 = rnd.choice(ARMIES), rnd.choice(ARMIES)
    side, first, seed = i % 2, (i // 2) % 2, 70000 + i
    g = setup("Cuatro plazas", a0, a1, first, seed, Config(**CFG))
    st, nz, th = VARIANTS[name]
    bots = {}
    for s in (0, 1):
        if s == side:
            bots[s] = HeuristicBot(g, s, st, seed=seed * 7919 + s, noise=nz, threshold=th)
        else:
            bots[s] = HeuristicBot(g, s, "normal", seed=seed * 7919 + s)
    while g.winner is None and g.turn < 200:
        g.start_turn()
        if g.winner is None:
            bots[g.current].play_turn()
    return name, (1.0 if g.winner == side else 0.5 if g.winner not in (0, 1) else 0.0)

if __name__ == "__main__":
    n = int(sys.argv[1])
    with Pool(4) as p:
        res = p.map(one, [(k, i) for k in VARIANTS for i in range(n)])
    for k in VARIANTS:
        r = [x for kk, x in res if kk == k]
        m = sum(r) / len(r); se = (m * (1 - m) / len(r)) ** 0.5
        print(f"{k:12s}: gana {m*100:5.1f} % contra el normal (±{1.96*se*100:.1f})")
