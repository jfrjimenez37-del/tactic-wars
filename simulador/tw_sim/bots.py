"""Bots para la capa 0. Eligen siempre entre las acciones legales que da el motor (rules.Game.legal_actions).

HeuristicBot puntua cada accion (dano, captura, riesgo de la casilla, avance, produccion, terreno) y
juega la mejor mientras le queden PM. RandomBot elige al azar: sirve para comprobar que el
heuristico juega mejor que el azar.
"""
from __future__ import annotations

import random
from collections import defaultdict

from .lcg import LCG
from .rules import CARDS, FOOT, UNIT, VEHICLES, dist, neighbors

VALUE = {"F": 2.5, "A": 2.5, "I": 2.5, "P": 1.5, "J": 3.0, "T": 6.0, "R": 5.0, "C": 4.0, "K": 3.0}
BUILDING_VALUE = {"H": 40.0, "Q": 8.0, "U": 5.0}
STYLES = {
    "normal": dict(risk=1.0, pos=0.6, cap=1.0, atk=1.0, prod=1.0),
    "agresivo": dict(risk=0.5, pos=0.9, cap=1.0, atk=1.4, prod=1.0),
    "prudente": dict(risk=1.6, pos=0.4, cap=1.0, atk=0.9, prod=1.0),
    "economico": dict(risk=1.0, pos=0.6, cap=1.6, atk=0.8, prod=1.3),
    "encerrado": dict(risk=1.3, pos=0.6, cap=1.0, atk=1.0, prod=1.2, home=4),   # no se aleja de su base
}


class HeuristicBot:
    def __init__(self, game, side, style="normal", seed=0, noise=0.3, threshold=0.4, rng="python"):
        self.g, self.side = game, side
        self.base = dict(STYLES[style])
        self.w = dict(self.base)
        self.rng = LCG(seed) if rng == "lcg" else random.Random(seed)
        self.noise, self.threshold = noise, threshold

    # --- contexto del turno
    def _adapt(self):
        """A partir de la ronda 8, si va perdiendo en el desempate, arriesga mas."""
        self.w = dict(self.base)
        if self.g.round >= 8:
            st = self.g._standing()
            if st != self.side:
                self.w.update(risk=self.w["risk"] * 0.5, pos=self.w["pos"] * 1.6, atk=self.w["atk"] * 1.2, cap=self.w["cap"] * 1.3)
            else:
                self.w["risk"] *= 1.3

    def _threat(self):
        g = self.g
        per = defaultdict(lambda: defaultdict(list))
        for e in g.activatable(1 - self.side):
            if e.t == "R":
                hi = 4 if g.terrain[e.pos] == "C" else 3
                cells = [q for q in g.terrain if 2 <= dist(q, e.pos) <= hi]
            else:
                cells = set()
                for p in g.reach(e):
                    cells.update(neighbors(p))
            for q in cells:
                for cl in ("pie", "lig", "bli"):
                    if g.dmg[e.t][cl] > 0:
                        per[q][cl].append(g.dmg[e.t][cl] + (1 if e.veteran else 0))
        for tq, t in g.turrets.items():                  # v5: fuego de las torretas al terminar mi turno
            if t["hp"] > 0 and t["owner"] != self.side and t["off"] < g.turn:
                for q in g.terrain:
                    if t["lo"] <= dist(q, tq) <= t["hi"]:
                        for cl in ("pie", "lig", "bli"):
                            per[q][cl].append(t["dmg"] * 0.8)
        th = defaultdict(lambda: {"pie": 0.0, "lig": 0.0, "bli": 0.0})
        for q, m in per.items():
            for cl, lst in m.items():
                lst.sort(reverse=True)
                th[q][cl] = lst[0] + 0.5 * sum(lst[1:3])
        return th

    def _context(self):
        g, s = self.g, self.side
        enemies = g.on_board(1 - s)
        targets = [p for p, o in g.owner.items() if o != s]
        en_pos = [e.pos for e in enemies] + [g.hq[1 - s]]
        return dict(
            th=self._threat(), enemies=enemies,
            dm_foot=g.distances(targets, 0) if targets else {},
            dm={k: g.distances(en_pos, k) for k in (0, 1, 2)},
            hq_tracks=g.distances([g.hq[s]], 2),
            dm_home=g.distances([p for p, o in g.owner.items() if o == s and g.terrain[p] in "HQ"], 0) if g.cfg.train else {},
            capturing=[c[1] for p, c in g.capture.items() if c[0] != s and g.owner[p] == s],
        )

    # --- puntuacion
    def score(self, a, ctx):
        g, s, w = self.g, self.side, self.w
        if a.kind == "end":
            return 0.0
        if a.kind == "produce":
            t = a.target
            mine = g.on_board(s)
            sc = VALUE[t] * 0.9 * w["prod"] - 1.0
            if t in "FAIK" and sum(1 for u in mine if u.t in "FAIK") < 3:
                sc += 2.0
            if t == "A" and sum(1 for e in ctx["enemies"] if e.t == "T") >= 2:
                sc += 1.5
            if t == "F":
                sc += 0.5
            return sc
        if a.kind == "card":
            return self._card_score(a, ctx)
        if a.kind == "dismount":
            # solo merece la pena si la tripulacion puede capturar desde esa casilla (A5)
            v = g.units[a.unit]
            if a.sub != "char" and not v.char and any(e.t == "K" and dist(e.pos, v.pos) <= 2 + UNIT["K"][3] for e in ctx["enemies"]):
                return -3.0                     # no dejar el vehiculo vacio al alcance de un hacker (C8.10)
            if a.dest in g.owner and g.owner[a.dest] != s:
                bv = BUILDING_VALUE[g.terrain[a.dest]]
                return 0.25 * bv * w["cap"] + (2 if g.owner[a.dest] == 1 - s else 0) - ctx["th"][a.dest]["pie"] * 0.4 - 0.2
            return -1.0
        u = g.units[a.unit]
        cl = UNIT[u.t][0]
        e = a.dest
        if "home" in w and dist(e, g.hq[s]) > w["home"]:
            return -10.0
        risk = ctx["th"][e][cl] * VALUE[u.t] / UNIT[u.t][2] * w["risk"]
        if u.t == "P" and g.cfg.train and (g.cfg.train == "gratis" or g.supplies[s] >= 2):
            before, after = ctx["dm_home"].get(u.pos, 30), ctx["dm_home"].get(e, 30)   # vuelve a evolucionar
        elif u.t == "K":
            before, after = ctx["dm"][0].get(u.pos, 30), ctx["dm"][0].get(e, 30)
        elif u.t in FOOT:
            before, after = ctx["dm_foot"].get(u.pos, 30), ctx["dm_foot"].get(e, 30)
        else:
            dm = ctx["dm"][UNIT[u.t][1]]
            before, after = dm.get(u.pos, 30), dm.get(e, 30)
            if u.t == "R":
                before, after = abs(before - 3), abs(after - 3)
        base = (before - after) * 0.25 * w["pos"] * (0.6 if u.t == "R" else 1) - 0.6 * risk
        if a.sub == "none":
            return base
        if a.sub == "attack":
            en = g.units[a.target]
            old = u.pos
            u.pos = e
            d = g.damage(u, en)
            sc = d * VALUE[en.t] / UNIT[en.t][2] * w["atk"]
            if d >= en.hp:
                sc += VALUE[en.t] * 0.8 + (0.5 if en.t in VEHICLES and en.crew else 0)
            elif g.cfg.counter and u.t != "R" and en.t != "R" and dist(e, en.pos) == 1:
                c = g.damage(en, u, counter=True)
                sc -= c * VALUE[u.t] / UNIT[u.t][2] + (VALUE[u.t] * 0.8 if c >= u.hp else 0)
            u.pos = old
            if en.id in ctx["capturing"]:
                sc += 4
            return base + sc
        if a.sub == "capture":
            c = g.capture.get(e)
            have = c[2] if c and c[1] == u.id else 0
            add = 2 if u.t in ("F", "C") else 1
            bv = BUILDING_VALUE[g.terrain[e]]
            need = g.cfg.hq_points if g.terrain[e] == "H" else 4
            sc = add / need * bv * w["cap"] + (bv if have + add >= need else 0) + (2 if g.owner[e] == 1 - s else 0)
            if g.cfg.domination and have + add >= need:     # acercarse al dominio o romper el del rival
                mine = sum(1 for o in g.owner.values() if o == s)
                theirs = sum(1 for o in g.owner.values() if o == 1 - s)
                if mine + 1 >= g.cfg.domination:
                    sc += 15
                if g.owner[e] == 1 - s and theirs >= g.cfg.domination - 1:
                    sc += 15
            if g.terrain[e] == "U" and have + add >= need:
                sc += (g.cfg.city_first if g.owner[e] is None else g.cfg.city_retake) * 0.5
            return base + sc
        if a.sub == "repair":
            v = g.units[a.target]
            amt = min(UNIT[v.t][2] - v.hp, 2 if u.t == "I" else 1)
            return base + amt * VALUE[v.t] / UNIT[v.t][2] * 1.2
        if a.sub == "board":
            return base + VALUE[g.units[a.target].t] * 0.6
        if a.sub == "struct":
            q = a.target
            ch = g.terrain[q]
            if ch == "#":
                return base + max(0, self._path_gain(q, "r", own=True)) * 0.6 - 0.5
            if ch == "P":
                return base + self._bridge_value(q, ctx) - 0.5
            return base + 0.5                                   # barricada rival
        if a.sub == "attack_turret":
            t = g.turrets[a.target]
            d = g.turret_damage(u, a.target)
            return base + d * 5.0 / t["max"] * w["atk"] + (4.0 if d >= t["hp"] else 0) + (1.0 if t["owner"] == 1 - s else 0)
        if a.sub == "sabotage":
            t = g.turrets[a.target]
            near = sum(VALUE[m.t] for m in g.on_board(s) if dist(m.pos, a.target) <= t["hi"] + 2)
            return base + min(4.0, near * 0.3) - 0.5
        if a.sub == "repair_turret":
            t = g.turrets[a.target]
            return base + (3.0 if t["hp"] == 0 else min(2, t["max"] - t["hp"]) * 0.8)
        if a.sub == "hack":
            v = g.units[a.target]
            return base + VALUE[v.t] * v.hp / UNIT[v.t][2] * 2.0
        if a.sub == "train":
            t = a.target
            sc = (VALUE[t] - VALUE["P"]) * 2.0 + (1.5 if t == "A" and sum(1 for x in ctx["enemies"] if x.t == "T") >= 2 else 0)
            if g.cfg.train == "pagando":
                sc -= g.cost(t) * 0.5
            return base + sc
        if a.sub == "barricade":
            return base + self._barricade_value(a.target, ctx) - 0.8
        return base

    def _card_score(self, a, ctx):
        """Puntuacion de una carta: beneficio estimado menos su coste en PM."""
        g, s, w = self.g, self.side, self.w
        c = a.sub
        cost = g.card_def[c][0] * 0.6
        enemies = ctx["enemies"]
        if c == "marcha":
            u = g.units[a.unit]
            fake = type(a)("activate", u.id, a.dest, "none")
            return self.score(fake, ctx) - 0.4
        if c == "reparacion":
            v = g.units[a.unit]
            return min(3, UNIT[v.t][2] - v.hp) * VALUE[v.t] / UNIT[v.t][2] * 1.2 - cost
        if c in ("torreta", "misiles"):
            near = sum(1 for e in enemies if dist(e.pos, a.dest) <= 4)
            return 1.2 + 0.7 * near + (0.5 if c == "misiles" else 0) - cost
        if c == "refuerzo":
            mine = sum(1 for m in g.on_board(s) if m.t in "FAIK")
            return VALUE[a.target] * 0.9 + (2.0 if mine < 2 else 0) - cost
        if c == "hackeo":
            t = g.turrets[a.dest]
            near = sum(VALUE[m.t] for m in g.on_board(s) if dist(m.pos, a.dest) <= t["hi"] + 2)
            return min(4.0, near * 0.3) - cost
        if c == "pem":
            val = sum(VALUE[e.t] * 0.4 for e in enemies if e.t in VEHICLES and max(abs(e.pos[0] - a.dest[0]), abs(e.pos[1] - a.dest[1])) <= 1)
            val += sum(1.5 for q, t in g.turrets.items() if t["hp"] > 0 and t["owner"] != s
                       and max(abs(q[0] - a.dest[0]), abs(q[1] - a.dest[1])) <= 1)
            return val - cost
        if c in ("aereo", "saturacion"):
            val = 0.0
            for e in enemies:
                dd = max(abs(e.pos[0] - a.dest[0]), abs(e.pos[1] - a.dest[1]))
                if c == "aereo":
                    d = 4 if e.pos == a.dest else (2 if dist(e.pos, a.dest) == 1 else 0)
                else:
                    d = 2 if dd <= 1 else 0
                if d:
                    val += min(d, e.hp) * VALUE[e.t] / UNIT[e.t][2] * w["atk"] + (VALUE[e.t] * 0.8 if d >= e.hp else 0)
            return val - cost
        if c == "paracaidistas":
            best = 0.0
            for p, o in g.owner.items():
                if o != s and dist(p, a.dest) <= 1:
                    best = max(best, BUILDING_VALUE[g.terrain[p]] * 0.3 * w["cap"])
            return best + 1.0 - cost
        return -1.0

    def _path_gain(self, q, new, own):
        g = self.g
        target = g.hq[1 - self.side] if own else g.hq[self.side]
        start = g.hq[self.side] if own else g.hq[1 - self.side]
        before = g.distances([target], 2).get(start, 99)
        saved = g.terrain[q]
        g.terrain[q] = new
        after = g.distances([target], 2).get(start, 99)
        g.terrain[q] = saved
        return before - after

    def _bridge_value(self, q, ctx):
        g = self.g
        before = ctx["hq_tracks"]
        saved = g.terrain[q]
        g.terrain[q] = "~"
        after = g.distances([g.hq[self.side]], 2)
        g.terrain[q] = saved
        gain = sum(min(after.get(e.pos, 40), 40) - before.get(e.pos, 40) for e in ctx["enemies"] if e.t in "JTR")
        mine = sum(min(after.get(m.pos, 40), 40) - before.get(m.pos, 40) for m in g.on_board(self.side) if m.t in "JTR")
        return (gain - mine) * 0.25

    def _barricade_value(self, q, ctx):
        """Cuanto alarga la barricada el camino de los vehiculos enemigos hasta mi cuartel general."""
        g = self.g
        enemies = [e for e in ctx["enemies"] if e.t in "JTR" and dist(e.pos, g.hq[self.side]) <= 10]
        if not enemies:
            return -1.0
        saved = g.terrain[q]
        g.terrain[q] = "X"
        after = g.distances([g.hq[self.side]], 2)
        g.terrain[q] = saved
        before = ctx["hq_tracks"]
        gain = sum(min(after.get(e.pos, 40), 40) - before.get(e.pos, 40) for e in enemies)
        mine = sum(min(after.get(m.pos, 40), 40) - before.get(m.pos, 40) for m in g.on_board(self.side) if m.t in "JTR")
        return (gain - 0.5 * mine) * 0.3

    # --- turno
    def play_turn(self):
        g = self.g
        self._adapt()
        while g.winner is None and g.current == self.side:
            acts = g.legal_actions()
            ctx = self._context()
            best, best_sc = None, None
            for a in acts:
                sc = self.score(a, ctx) + (self.rng.uniform(-self.noise, self.noise) if a.kind != "end" else 0)
                if best_sc is None or sc > best_sc:
                    best, best_sc = a, sc
            if best.kind != "end" and best_sc < self.threshold:
                best = next(a for a in acts if a.kind == "end")
            g.apply(best, check=False)


class RandomBot:
    def __init__(self, game, side, style=None, seed=0):
        self.g, self.side = game, side
        self.rng = random.Random(seed)

    def play_turn(self):
        g = self.g
        while g.winner is None and g.current == self.side:
            acts = g.legal_actions()
            a = self.rng.choice(acts)
            if self.rng.random() < 0.15:
                a = next(x for x in acts if x.kind == "end")
            g.apply(a, check=False)
