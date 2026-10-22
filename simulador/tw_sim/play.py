"""Partida completa reproducible: misma semilla y misma configuracion -> misma partida."""
from __future__ import annotations

import random
from collections import defaultdict

from .bots import HeuristicBot, RandomBot
from .rules import CARDS, UNIT, Config, Game, deployment_zone, dist

ARMIES = {
    "equilibrado": ["T", "T", "R", "R", "J", "F", "F", "A"],
    "blindado": ["T", "T", "T", "T", "R", "F", "A", "A"],
    "artilleria": ["R", "R", "R", "T", "J", "F", "F", "A"],
    "rapido": ["J", "J", "J", "J", "T", "F", "F", "F"],
    "infanteria": ["T", "T", "R", "J", "J", "F", "F", "I"],
    "ingenieros": ["T", "T", "R", "J", "J", "F", "I", "I"],
    # Propuesta: 4 vehiculos + 2 tropas a pie + 1 personaje (* = vehiculo en el que empieza el personaje).
    # Cada ejercito es el de arriba con un vehiculo y una tropa a pie menos.
    "equilibrado4": ["T*", "T", "R", "J", "F", "A"],
    "blindado4": ["T*", "T", "T", "R", "F", "A"],
    "artilleria4": ["T*", "R", "R", "J", "F", "A"],
    "rapido4": ["T*", "J", "J", "J", "F", "F"],
    "infanteria4": ["T*", "T", "R", "J", "F", "I"],
    "ingenieros4": ["T*", "T", "R", "J", "I", "I"],
    "hacker4": ["T*", "T", "R", "J", "F", "K"],
    "equilibrado4_J": ["T", "T", "R", "J*", "F", "A"],
    "equilibrado4_R": ["T", "T", "R*", "J", "F", "A"],
}
BOTS = {"heuristico": HeuristicBot, "aleatorio": RandomBot}
ORDER = {"T": 0, "J": 1, "F": 2, "A": 3, "I": 4, "K": 4, "R": 5}


def deploy(g, side, army, rng):
    """C3.3: cada unidad en la zona de despliegue; las de primera linea mas cerca del rival."""
    zone = deployment_zone(g, side)
    enemy_hq = g.hq[1 - side]
    for t in sorted(army, key=lambda t: (ORDER[t[0]], t)):
        hero = t.endswith("*")
        t = t[0]
        k = UNIT[t][1]
        ok = [p for p in zone if p not in g.occ and g.passable(p, k) and g.terrain[p] != "H"]
        extra = 2 if t == "R" else 0
        ok.sort(key=lambda p: (dist(p, enemy_hq) + extra + 2 * rng.random(), p))
        v = g.add_unit(side, t, ok[0])
        if hero:
            g.add_char(v)


def with_handicap(army, remove):
    """Quita del ejercito las unidades indicadas (prefiere las que no llevan al personaje)."""
    army = list(army)
    for t in remove:
        army.remove(t if t in army else t + "*")
    return army


def make_decks(cfg, seed, decks=None):
    """Barajas de 3 cartas sin repetir: las indicadas o, si no, elegidas al azar con la semilla de la partida."""
    if not cfg.cards:
        return {0: [], 1: []}
    if decks:
        return {0: list(decks[0]), 1: list(decks[1])}
    return {s: sorted(random.Random(seed * 31 + s).sample(sorted(CARDS), 3)) for s in (0, 1)}


def setup(map_name, army0, army1, first, seed, config, handicap=((), ()), decks=None):
    cfg = config or Config()
    armies = {s: with_handicap(ARMIES[a], handicap[s]) for s, a in ((0, army0), (1, army1))}
    g = Game(map_name, first, armies, cfg, make_decks(cfg, seed, decks))
    for s in (0, 1):
        deploy(g, s, armies[s], random.Random(seed * 1009 + s))
    return g


def play_game(map_name, army0, army1, first=0, seed=0, config=None, bots=("heuristico", "heuristico"),
              styles=("normal", "normal"), max_turns=200, noises=(0.3, 0.3), handicap=((), ()), decks=None,
              bot_rng="python"):
    """noises: ruido de cada bot (mas ruido = juega peor). handicap: unidades que se quitan a cada bando."""
    g = setup(map_name, army0, army1, first, seed, config, handicap, decks)
    players = {}
    for s in (0, 1):
        kw = {"noise": noises[s], "rng": bot_rng} if bots[s] == "heuristico" else {}
        players[s] = BOTS[bots[s]](g, s, styles[s], seed=seed * 7919 + s, **kw)
    while g.winner is None and g.turn < max_turns:
        g.start_turn()
        if g.winner is None:
            players[g.current].play_turn()
    return g


def replay(map_name, army0, army1, first, seed, log, config=None, handicap=((), ()), decks=None):
    """Reproduce una partida desde su registro, comprobando que cada accion era legal."""
    from .rules import Action, cell
    g = setup(map_name, army0, army1, first, seed, config, handicap, decks)
    g.start_turn()
    for turn, kind, unit, dest, sub, target in log:
        if sub in ("struct", "barricade", "attack_turret", "sabotage", "repair_turret") or (
                kind not in ("produce", "card") and isinstance(target, str) and target[:1].isalpha() and target[1:].isdigit()):
            target = cell(target)
        a = Action(kind, unit, cell(dest) if dest else None, sub, target)
        g.apply(a, check=True)
        if kind == "end" and g.winner is None:
            g.start_turn()
    return g


def comeback_fields(g):
    """Ventaja relativa (v0 - v1) / (v0 + v1) por ronda, para medir remontadas."""
    adv = [(r, (a - b) / max(1, a + b)) for r, a, b in g.trace]
    out = {"adv_r5": None, "adv_r10": None, "adv_r15": None, "winner_worst": None, "loser_best": None}
    for r, x in adv:
        if r in (5, 10, 15):
            out[f"adv_r{r}"] = round(x, 3)
    if g.winner in (0, 1):
        sign = 1 if g.winner == 0 else -1
        late = [sign * x for r, x in adv if r >= 3]
        if late:
            out["winner_worst"] = round(min(late), 3)
            out["loser_best"] = round(-max(late), 3)
    return out


# Modelo de tiempo (supuestos para estimar la duracion en el movil, sec. C13):
THINK_BASE, THINK_PER_ACTION, CLOCK = 4.0, 3.0, 25.0     # segundos de decision por turno, con tope de 25 s
ANIM_MOVE, ANIM_ATTACK, TURN_CHANGE = 1.0, 3.0, 1.5      # animaciones (el combate dura 3 s como maximo)


def duration_fields(g):
    """Estimacion de minutos de partida en el movil a partir del registro de acciones."""
    acts, attacks, moves = defaultdict(int), defaultdict(int), defaultdict(int)
    for turn, kind, unit, dest, sub, target in g.log:
        if kind != "end":
            acts[turn] += 1
        if kind == "activate":
            moves[turn] += 1
            attacks[turn] += sub == "attack"
    total = 0.0
    for t in range(g.turn):
        total += min(CLOCK, THINK_BASE + THINK_PER_ACTION * acts[t]) + ANIM_MOVE * moves[t] + ANIM_ATTACK * attacks[t] + TURN_CHANGE
    worst = g.turn * (CLOCK + TURN_CHANGE) + 120 + sum(ANIM_MOVE * moves[t] + ANIM_ATTACK * attacks[t] for t in range(g.turn))
    return {"est_minutes": round(total / 60, 2), "max_minutes": round(worst / 60, 2),
            "actions_per_turn": round(sum(acts.values()) / max(1, g.turn), 2)}


def summary_row(g, meta):
    """Una fila de CSV por partida."""
    st = g.stats
    row = dict(meta)
    row.update(
        winner=g.winner, how=g.how, rounds=min(g.round, g.cfg.rounds), turns=g.turn, final_hash=g.state_hash(),
        buildings_0=sum(1 for o in g.owner.values() if o == 0), buildings_1=sum(1 for o in g.owner.values() if o == 1),
        points_0=g.points[0], points_1=g.points[1],
        bridges=st["bridges"], walls=st["walls"], barricades_destroyed=st["barricades_destroyed"],
        max_quiet=st["max_quiet"], last_turn_flip=st["last_turn_flip"],
        char_deaths=st["char_deaths"], char_eject=st["char_eject"],
    )
    row.update(comeback_fields(g))
    row.update(duration_fields(g))
    row["trainings"] = sum(st["trainings"])
    row["hacks"] = sum(st["hacks"])
    for k in ("turret_shots", "turret_kills", "turrets_destroyed", "sabotages", "turret_repairs"):
        row[k] = st[k]
    for x in (0, 1):
        row[f"deck_{x}"] = "+".join(g.decks[x])
        row[f"cards_used_{x}"] = sum(st["cards"][x].values())
    for c in CARDS:
        row[f"card_{c}"] = st["cards"][0][c] + st["cards"][1][c]
    for k in ("dismount", "eject", "board", "captures", "repairs", "barricades_built", "pm_used", "pm_lost", "damage_events"):
        row[f"{k}_0"], row[f"{k}_1"] = st[k]
    for t in UNIT:
        row[f"kills_{t}"] = g.kills[0][t] + g.kills[1][t]
        row[f"built_{t}"] = g.built[0][t] + g.built[1][t]
        row[f"acts_{t}"] = g.activations[0][t] + g.activations[1][t]
    return row
