"""Exporta partidas de referencia para comprobar que el motor de Godot aplica las mismas reglas.

Uso:  python3 export_golden.py [carpeta_salida] [partidas]
Cada archivo JSON lleva la colocacion inicial, las barajas, el registro de acciones y el estado canonico
al final de cada turno. El prototipo de Godot vuelve a jugar el registro y compara esos estados.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tw_sim.play import play_game  # noqa: E402
from tw_sim.rules import COLS, Config  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ARMY_POOL = ["equilibrado4", "hacker4", "ingenieros4", "rapido4", "blindado4", "infanteria4", "artilleria4"]


def cn(p):
    return "-" if p is None else f"{COLS[p[0]]}{p[1]}"


def b(x):
    return "1" if x else "0"


def opt(x):
    return "N" if x is None else str(x)


def canonical(g):
    """Estado completo en texto. Debe coincidir caracter a caracter con TWGame.canonical() en Godot."""
    lines = [f"T{g.turn} R{g.round} C{g.current} PM{g.pm} S{g.supplies[0]},{g.supplies[1]} "
             f"SP{g.saved_pm[0]},{g.saved_pm[1]} W{opt(g.winner)} H{opt(g.how)} "
             f"DS{g.dom_streak[0]},{g.dom_streak[1]} D{g.destroyed[0]},{g.destroyed[1]}"]
    lines.append("".join(g.terrain[(c, r)] for r in range(1, 9) for c in range(12)))
    lines.append(" ".join(f"{cn(p)}:{opt(o)}" for p, o in sorted(g.owner.items())))
    lines.append(" ".join(f"{cn(p)}:{c[0]}:{c[1]}:{c[2]}" for p, c in sorted(g.capture.items())))
    lines.append(" ".join(f"{cn(p)}:{o[0]}:{o[1]}:{o[2]}" for p, o in sorted(g.orders.items())))
    for u in sorted(g.units.values(), key=lambda x: x.id):
        tr = "-" if not u.training else f"{u.training[0]}@{u.training[1]}"
        lines.append(f"{u.id}:{u.side}:{u.t}:{u.hp}:{cn(u.pos)}:{b(u.veteran)}:{opt(u.crew)}:{opt(u.char)}:"
                     f"{opt(u.carrier)}:{opt(u.home)}:{tr}:{opt(u.stun)}:{b(u.acted)}:{b(u.moved)}:{u.barricades}")
    lines.append(" ".join(f"{cn(q)}:{t['hp']}:{t['max']}:{opt(t['owner'])}:{t['off']}:{t['kind']}"
                          for q, t in sorted(g.turrets.items())))
    for x in (0, 1):
        lines.append(" ".join(f"{c}:{r}" for c, r in sorted(g.card_ready[x].items())))
    return "\n".join(lines)


def action_key(a):
    """Misma forma que TWGame.action_key() en Godot."""
    t = a.target
    if isinstance(t, tuple):
        t = cn(t)
    ts = "-" if t is None else str(t)
    return f"{a.kind}|{-1 if a.unit is None else a.unit}|{cn(a.dest)}|{a.sub}|{ts}"


def legal_digest(g):
    keys = sorted(action_key(a) for a in g.legal_actions())
    return [len(keys), hashlib.sha1("\n".join(keys).encode()).hexdigest()]


def setup_steps(g0):
    """Pasos para reconstruir la colocacion inicial con los mismos identificadores."""
    steps = []
    for u in sorted(g0.units.values(), key=lambda x: x.id):
        if u.t == "C" and u.carrier is not None:
            steps.append(["char", u.carrier])
        elif u.pos is not None:
            steps.append(["unit", u.side, u.t, cn(u.pos), bool(u.crew)])
    return steps


def export_bot_games(out, n, cfg, cfg_dict):
    """Partidas bot contra bot con el generador LCG: Godot debe elegir exactamente las mismas acciones."""
    os.makedirs(out, exist_ok=True)
    from tw_sim.play import setup
    for i in range(n):
        a0, a1 = ARMY_POOL[(i * 2) % len(ARMY_POOL)], ARMY_POOL[(i * 5 + 3) % len(ARMY_POOL)]
        first, seed = i % 2, 9100 + i
        g = play_game("Cuatro plazas", a0, a1, first=first, seed=seed, config=cfg, bot_rng="lcg")
        g0 = setup("Cuatro plazas", a0, a1, first, seed, cfg, decks=None)
        data = {"map": "Cuatro plazas", "first": first, "seed": seed, "armies": [a0, a1],
                "allowed": [sorted(g0.allowed[0]), sorted(g0.allowed[1])], "decks": [g0.decks[0], g0.decks[1]],
                "bot_seeds": [seed * 7919, seed * 7919 + 1], "noise": 0.3, "threshold": 0.4,
                "setup": setup_steps(g0), "log": g.log, "final": canonical(g), "how": g.how}
        with open(os.path.join(out, f"bot_{i:02d}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        print(f"bot_{i:02d}: {a0} vs {a1}, {len(g.log)} acciones, {g.how}")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "tactic_wars_godot", "tests", "golden")
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 24
    os.makedirs(out, exist_ok=True)
    exps = json.load(open(os.path.join(HERE, "experiments.json"), encoding="utf-8"))
    cfg_dict = exps["REGLAS_ACTUALES"]["config"]
    cfg = Config(**cfg_dict)
    if len(sys.argv) > 3 and sys.argv[3] == "bots":
        export_bot_games(out, n, cfg, cfg_dict)
        return
    for i in range(n):
        a0, a1 = ARMY_POOL[i % len(ARMY_POOL)], ARMY_POOL[(i * 3 + 1) % len(ARMY_POOL)]
        first, seed = i % 2, 7000 + i
        # Se juega una vez registrando el estado al final de cada turno
        checkpoints, legal = [], []
        from tw_sim import rules as R
        orig_end, orig_start = R.Game.end_turn, R.Game.start_turn

        def end_turn_hook(self, _orig=orig_end):
            _orig(self)
            checkpoints.append(canonical(self))

        def start_turn_hook(self, _orig=orig_start):
            _orig(self)
            if self.winner is None:
                legal.append(legal_digest(self))
        R.Game.end_turn, R.Game.start_turn = end_turn_hook, start_turn_hook
        try:
            g = play_game("Cuatro plazas", a0, a1, first=first, seed=seed, config=cfg)
        finally:
            R.Game.end_turn, R.Game.start_turn = orig_end, orig_start
        # Colocacion inicial: se reconstruye jugando de nuevo hasta antes del primer turno
        from tw_sim.play import setup
        g0 = setup("Cuatro plazas", a0, a1, first, seed, cfg, decks=None)
        data = {
            "map": "Cuatro plazas", "first": first, "seed": seed, "armies": [a0, a1],
            "allowed": [sorted(g0.allowed[0]), sorted(g0.allowed[1])],
            "decks": [g0.decks[0], g0.decks[1]], "config": cfg_dict,
            "setup": setup_steps(g0), "initial": canonical(g0),
            "log": g.log, "checkpoints": checkpoints, "legal": legal, "final": canonical(g),
            "winner": g.winner, "how": g.how,
        }
        with open(os.path.join(out, f"game_{i:02d}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        print(f"game_{i:02d}: {a0} vs {a1}, {len(g.log)} acciones, {g.how}")


if __name__ == "__main__":
    main()
