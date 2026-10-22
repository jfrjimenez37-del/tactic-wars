"""Motor de reglas de la capa 0 de Tactic Wars (reglas C1-C13 con las aclaraciones A1-A8).

Herramienta de pruebas: no es el juego. Todo es determinista; el azar solo entra en
los bots y en el despliegue, siempre a traves de generadores con semilla.
El reloj (C13) no se modela.
"""
from __future__ import annotations

import hashlib
import heapq
from collections import defaultdict
from dataclasses import dataclass, field

COLS = "ABCDEFGHIJKL"
W, H = 12, 8

# Mitad inferior (filas 1-4) de cada mapa; la mitad superior se obtiene por rotacion de 180 grados (C1.4).
# . llano  = carretera  B bosque  C colina  ~ rio  P puente  # muro  r ruinas  X barricada
# H cuartel general  Q cuartel  U ciudad
MAPS = {
    "Encrucijada": ["..U.B~~..C..", ".Q=..~~U..B.", "..=C.PP==...", "H==.#~~..B.U"],
    "Ciudad en ruinas": ["H=..U.#.....", "Q=.B..r..C..", "..=..#U#..B.", ".U==.r..=..."],
    # Propuestas v4: 2 ciudades en el centro, a la misma distancia (6) de los dos cuarteles generales
    "Plaza central": ["..U..B..C...", ".Q=.....B.U.", "..==.#..~~..", "H=..r.U.~P.."],
    "Isla central": ["..U..~~..C..", ".Q=..PP..B.U", "..=.B~~..=..", "H===P.U~...."],
    # 3 edificios propios por jugador y 4 ciudades en el centro: dominio 7 = lo propio + todo el centro
    "Cuatro plazas": ["..U..B..C...", ".Q=...U.B...", "..=.#..=~~..", "H===r.U.~P.."],
    "Cuatro plazas escalonada": ["..U..B..C...", ".Q=..U..B...", "..=.#..=~~..", "H===rU..~P.."],
}
MAP_SETS = {"actuales": ["Encrucijada", "Ciudad en ruinas"], "plaza": ["Plaza central"], "isla": ["Isla central"],
            "cuatro": ["Cuatro plazas"], "escalonada": ["Cuatro plazas escalonada"]}

# C2: coste de movimiento por clase (0 a pie, 1 ruedas, 2 orugas); None = intransitable
MOVE_COST = {".": (1, 2, 1), "=": (1, 1, 1), "B": (1, 3, 2), "C": (2, 3, 2), "~": (2, None, None),
             "P": (1, 1, 1), "#": (None, None, None), "X": (None, None, None), "r": (1, 1, 1),
             "H": (1, 1, 1), "Q": (1, 1, 1), "U": (1, 1, 1), "O": (None, None, None)}   # O = torreta de carta
COVER = set("BrHQU")          # C2: cobertura para tropas a pie
BUILDINGS = set("HQU")

# Sec. 2.1: tipo -> (clase objetivo, clase de movimiento, PV, Mov, PM, alcance min, alcance max, coste, turnos)
UNIT = {
    "F": ("pie", 0, 3, 3, 1, 1, 1, 2, 1),
    "A": ("pie", 0, 3, 2, 1, 1, 1, 2, 1),
    "I": ("pie", 0, 3, 2, 1, 1, 1, 2, 1),
    "P": ("pie", 0, 2, 2, 1, 1, 1, 0, 0),
    "J": ("lig", 1, 4, 6, 1, 1, 1, 3, 1),
    "T": ("bli", 2, 8, 4, 2, 1, 1, 6, 2),
    "R": ("lig", 1, 5, 4, 2, 2, 3, 5, 2),
    "K": ("pie", 0, 2, 2, 1, 1, 1, 3, 1),      # hacker (Concepto v2, sec. 10.1); hackear cuesta 2 PM
    "C": ("pie", 0, 4, 3, 1, 1, 1, 0, 0),      # personaje a pie (Concepto v2, sec. 8.1); no se fabrica
}
NAMES = {"F": "Fusilero", "A": "Antitanque", "I": "Ingeniero", "P": "Tripulacion", "J": "Jeep", "T": "Tanque medio", "R": "Artilleria", "C": "Personaje", "K": "Hacker"}
VEHICLES = set("JTR")
FOOT = set("FAIPCK")
HACK_RANGE, HACK_PM = 2, 2
# v5: torretas (Concepto v2, 6.5 y 9.2). Disparan al terminar el turno de cada jugador que no sea su dueno.
# La de la plaza (alcance 0-2) tambien dispara a quien la esta capturando.
TURRETS = {"plaza": dict(hp=6, lo=0, hi=2, dmg=2), "torreta": dict(hp=6, lo=1, hi=2, dmg=2),
           "misiles": dict(hp=5, lo=2, hi=4, dmg=3)}
# v5: cartas de habilidad adaptadas a la capa 0 (Concepto v2, sec. 9): nombre -> (PM, recarga en rondas, desde ronda)
CARDS = {"marcha": (1, 4, 1), "reparacion": (1, 4, 1), "torreta": (2, 5, 3), "refuerzo": (2, 6, 3),
         "hackeo": (2, 6, 3), "pem": (2, 6, 4), "aereo": (3, 7, 4), "misiles": (3, 6, 5),
         "saturacion": (3, 8, 5), "paracaidistas": (3, 8, 5)}
# Sec. 2.2: dano base por clase de objetivo
DAMAGE = {"F": {"pie": 2, "lig": 1, "bli": 0}, "A": {"pie": 1, "lig": 3, "bli": 3}, "I": {"pie": 1, "lig": 0, "bli": 0},
          "P": {"pie": 1, "lig": 0, "bli": 0}, "J": {"pie": 2, "lig": 1, "bli": 0}, "T": {"pie": 3, "lig": 4, "bli": 3},
          "R": {"pie": 4, "lig": 3, "bli": 2}, "C": {"pie": 2, "lig": 1, "bli": 0}, "K": {"pie": 1, "lig": 0, "bli": 0}}
CHAR_EJECT_HP = 2           # supuesto: el personaje eyectado sale con la mitad de sus PV
CHAR_BOUNTY = 3             # Concepto v2, 8.1.6: si muere, el rival gana 3 suministros


@dataclass
class Config:
    pm: int = 5                      # C4.2: PM por turno
    rounds: int = 20                 # C4.1
    counter: bool = True             # C7.4
    heal: bool = True                # C4.2.2
    limit: int = 12                  # C11.5
    hq_points: int = 4               # C10.1 (puntos para capturar el cuartel general)
    hq_produces: bool = True         # C10.3
    tiebreak: str = "base"           # "base" (C12.4) o "puntos" (variante S2)
    lead: int | None = None          # variante S3: victoria anticipada por ventaja de puntos
    damage: dict = field(default_factory=dict)  # sobrescrituras {"A:bli": 4, ...}
    build_extra: int = 0             # rondas extra de fabricacion para todas las unidades
    build_mult: int = 1              # multiplica las rondas de fabricacion
    crew: str = "P"                  # tipo de la tropa que tripula cada vehiculo ("P" tripulacion o "F" fusilero)
    costs: dict = field(default_factory=dict)   # sobrescribe costes en suministros {"K": 2}
    # Economia (C4.2/C10.3). Valores por defecto = reglas v1/v2; las v3 se fijan en experiments.json
    supplies_start: int = 5
    income_base: int = 0             # suministros fijos por turno
    income_hq: int = 2
    income_city: int = 1             # por cada ciudad, cada turno propio
    city_first: int = 0              # al conquistar una ciudad neutral
    city_retake: int = 0             # al conquistarla al rival
    supply_cap: int = 20
    hq_heals: bool = True
    pm_schedule: list | None = None  # [[ronda, PM, maximo guardado], ...]; None = pm fijo y guardar 1
    caps: dict | None = None         # {"veh": 6, "foot": 4, "crew": 6}; None = limite total de C11.5
    domination: int | None = None    # victoria por dominio: tantos edificios al empezar 2 turnos propios seguidos
    plaza_turrets: bool = False      # v5: torretas en las ciudades centrales e ingeniero mejorado
    cards: bool = False              # v5: cartas de habilidad
    plaza_hp: int = 6                # v6: PV de las torretas de plaza
    plaza_armor: int = 0             # v6: dano que se resta a cada golpe contra una torreta de plaza
    plaza_regen: int = 0             # v6: PV que recupera una torreta de plaza con dueno al inicio de su turno
    card_overrides: dict = field(default_factory=dict)   # v6: {"pem": [PM, recarga, ronda], ...}
    pem_all: bool = False            # v6b: el PEM tambien inmoviliza tropas a pie
    train: str | None = None         # evolucion de la tripulacion (C8.9): None, "pagando" o "gratis"


def build_terrain(name):
    bottom = MAPS[name]
    rows = {r + 1: bottom[r] for r in range(4)}
    for r in range(4):
        rows[8 - r] = bottom[r][::-1]
    return {(c, r): rows[r][c] for r in range(1, 9) for c in range(12)}


def neighbors(p):
    c, r = p
    for q in ((c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)):
        if 0 <= q[0] < W and 1 <= q[1] <= H:
            yield q


def dist(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def cell(name):
    return (COLS.index(name[0]), int(name[1:]))


def cell_name(p):
    return f"{COLS[p[0]]}{p[1]}"


class Unit:
    __slots__ = ("id", "side", "t", "hp", "pos", "veteran", "crew", "acted", "moved", "barricades", "carrier", "home", "char", "training", "stun")

    def __init__(self, uid, side, t, pos, hp=None):
        self.id, self.side, self.t, self.pos = uid, side, t, pos
        self.hp = UNIT[t][2] if hp is None else hp
        self.veteran = False
        self.crew = None          # id de la tropa que lo tripula (vehiculos)
        self.acted = False
        self.moved = False
        self.barricades = 2 if t == "I" else 0
        self.carrier = None       # id del vehiculo en el que va (tropas a pie)
        self.home = None          # vehiculo de origen de una tripulacion (C8.6)
        self.char = None          # id del personaje que va dentro (vehiculos)
        self.training = None      # (tipo, turno en que termina) mientras la tripulacion evoluciona
        self.stun = None          # turno en que no puede actuar (PEM)

    def __repr__(self):
        where = cell_name(self.pos) if self.pos else f"dentro de {self.carrier}"
        return f"{self.t}{self.id}(lado {self.side}, {self.hp} PV, {where})"


@dataclass(frozen=True)
class Action:
    """Accion legal. kind: activate | dismount | produce | end."""
    kind: str
    unit: int | None = None
    dest: tuple | None = None
    sub: str = "none"            # en activate: none | attack | capture | repair | barricade | board | struct
    target: object = None        # id de unidad, casilla o tipo de unidad

    def as_list(self):
        t = self.target
        if isinstance(t, tuple):
            t = cell_name(t)
        return [self.kind, self.unit, cell_name(self.dest) if self.dest else None, self.sub, t]


class Game:
    def __init__(self, map_name, first, armies, config=None, decks=None):
        self.cfg = config or Config()
        self.map_name = map_name
        self.terrain = build_terrain(map_name)
        self.dmg = {k: dict(v) for k, v in DAMAGE.items()}
        for key, val in self.cfg.damage.items():
            a, cls = key.split(":")
            self.dmg[a][cls] = val
        self.units = {}
        self.occ = {}
        self.next_id = 0
        self.owner = {p: None for p, ch in self.terrain.items() if ch in BUILDINGS}
        hqs = sorted(p for p, ch in self.terrain.items() if ch == "H")
        self.hq = {0: hqs[0], 1: hqs[1]}
        for p, ch in self.terrain.items():
            if ch in "HQ":
                self.owner[p] = 0 if p[0] < 6 else 1
        self.capture = {}              # casilla -> [lado, id unidad, puntos]
        self.supplies = [self.cfg.supplies_start] * 2   # C3.4
        self.dom_streak = [0, 0]
        self.saved_pm = [0, 0]
        self.orders = {}               # edificio -> (lado, tipo, turno global en que sale)
        self.armies = armies
        self.allowed = {s: {t[0] for t in armies[s]} - {"C"} for s in (0, 1)}
        self.first = first
        self.current = first
        self.round = 1
        self.turn = 0
        self.pm = 0
        self.points = [0, 0]
        self.winner = None
        self.how = None
        self.log = []
        self.stats = {k: [0, 0] for k in ("dismount", "eject", "board", "captures", "repairs", "barricades_built",
                                          "pm_used", "pm_lost", "damage_events")}
        self.stats.update(bridges=0, walls=0, barricades_destroyed=0, last_event_turn=0, max_quiet=0, last_turn_flip=None)
        self.kills = [defaultdict(int), defaultdict(int)]
        self.built = [defaultdict(int), defaultdict(int)]
        self.activations = [defaultdict(int), defaultdict(int)]
        self.trace = []                # (ronda, valor bando 0, valor bando 1) al final de cada ronda
        self.turrets = {}              # casilla -> estado de la torreta (v5)
        if self.cfg.plaza_turrets:
            for p, ch in self.terrain.items():
                if ch == "U" and dist(p, self.hq[0]) == dist(p, self.hq[1]):
                    self.turrets[p] = dict(TURRETS["plaza"], hp=self.cfg.plaza_hp, max=self.cfg.plaza_hp, owner=None,
                                           off=-1, kind="plaza", armor=self.cfg.plaza_armor)
        self.card_def = dict(CARDS)
        self.card_def.update({k: tuple(v) for k, v in self.cfg.card_overrides.items()})
        self.decks = decks or {0: [], 1: []}
        self.card_ready = {x: {c: 0 for c in self.decks[x]} for x in (0, 1)}
        self.stats.update(turret_shots=0, turret_kills=0, turrets_destroyed=0, sabotages=0, turret_repairs=0)
        self.stats["cards"] = [defaultdict(int), defaultdict(int)]
        self.stats.update(char_deaths=0, char_eject=0)
        self.destroyed = [0, 0]        # valor de las unidades enemigas destruidas (desempate v4)
        self.stats["trainings"] = [0, 0]
        self.stats["hacks"] = [0, 0]

    # ------------------------------------------------------------------ unidades
    def add_unit(self, side, t, pos, hp=None, with_crew=True):
        self.next_id += 1
        u = Unit(self.next_id, side, t, pos, hp)
        self.units[u.id] = u
        if pos is not None:
            assert pos not in self.occ, f"casilla ocupada {cell_name(pos)}"
            assert MOVE_COST[self.terrain[pos]][UNIT[t][1]] is not None, f"{t} no puede estar en {cell_name(pos)}"
            self.occ[pos] = u.id
        if t in VEHICLES and with_crew:
            self.next_id += 1
            c = Unit(self.next_id, side, self.cfg.crew, None)
            c.carrier = u.id
            c.home = u.id
            self.units[c.id] = c
            u.crew = c.id
        return u

    def add_char(self, v):
        """El personaje empieza dentro del vehiculo elegido, junto a su tripulacion (Concepto v2, 8.1)."""
        self.next_id += 1
        c = Unit(self.next_id, v.side, "C", None)
        c.carrier = v.id
        self.units[c.id] = c
        v.char = c.id
        return c

    def category(self, u_or_t):
        t = u_or_t if isinstance(u_or_t, str) else (u_or_t.training[0] if u_or_t.training else u_or_t.t)
        return "veh" if t in VEHICLES else ("crew" if t == "P" else ("char" if t == "C" else "foot"))

    def count(self, side, cat):
        """Unidades propias de una categoria, dentro o fuera de vehiculos, mas encargos pendientes."""
        n = sum(1 for u in self.units.values() if u.side == side and self.category(u) == cat)
        return n + sum(1 for (os_, t, _) in self.orders.values() if os_ == side and self.category(t) == cat)

    def room(self, side, t):
        """Limites por tipo (v3): 6 equipos, 4 tropas a pie, 6 tripulaciones."""
        if not self.cfg.caps:
            return True
        cat = self.category(t)
        return cat not in self.cfg.caps or self.count(side, cat) < self.cfg.caps[cat]

    def cost(self, t):
        return self.cfg.costs.get(t, UNIT[t][7])

    def on_board(self, side=None):
        return [u for u in self.units.values() if u.pos is not None and (side is None or u.side == side)]

    def activatable(self, side):
        return [u for u in self.on_board(side) if (u.t not in VEHICLES or u.crew or u.char) and not u.training]

    def at(self, p):
        uid = self.occ.get(p)
        return self.units[uid] if uid is not None else None

    def _drop_capture_of(self, uid):
        for p, c in list(self.capture.items()):
            if c[1] == uid:
                del self.capture[p]

    def _remove(self, u):
        if u.pos is not None:
            del self.occ[u.pos]
        del self.units[u.id]
        self._drop_capture_of(u.id)

    # ------------------------------------------------------------------ movimiento (C6)
    def passable(self, p, move_class):
        return MOVE_COST[self.terrain[p]][move_class] is not None

    def reach(self, u):
        """Casillas finales alcanzables -> coste. Incluye la casilla actual (mover 0)."""
        k = UNIT[u.t][1]
        mov = UNIT[u.t][3]
        best = {u.pos: 0}
        ends = {u.pos: 0}
        pq = [(0, u.pos)]
        while pq:
            d, p = heapq.heappop(pq)
            if d > best[p]:
                continue
            if p != u.pos and self.terrain[p] == "r":       # C6.3: las ruinas terminan el movimiento
                continue
            for q in neighbors(p):
                c = MOVE_COST[self.terrain[q]][k]
                if c is None or d + c > mov:
                    continue
                other = self.at(q)
                if other is not None and other.side != u.side:  # C6.2
                    continue
                if self.terrain[q] == "r" and other is not None:  # C6.3
                    continue
                if d + c < best.get(q, 99):
                    best[q] = d + c
                    heapq.heappush(pq, (d + c, q))
                    if other is None:
                        ends[q] = d + c
        return ends

    def distances(self, sources, move_class):
        """Coste minimo por terreno (ignorando unidades) desde un conjunto de casillas."""
        d = {s: 0 for s in sources}
        pq = [(0, s) for s in sources]
        heapq.heapify(pq)
        while pq:
            x, p = heapq.heappop(pq)
            if x > d[p]:
                continue
            for q in neighbors(p):
                c = MOVE_COST[self.terrain[q]][move_class]
                if c is not None and x + c < d.get(q, 999):
                    d[q] = x + c
                    heapq.heappush(pq, (x + c, q))
        return d

    def tracks_connected(self, overrides):
        """C9.5: queda camino para orugas entre los dos cuarteles generales?"""
        saved = {p: self.terrain[p] for p in overrides}
        self.terrain.update(overrides)
        ok = self.hq[1] in self.distances([self.hq[0]], 2)
        self.terrain.update(saved)
        return ok

    # ------------------------------------------------------------------ combate (C7)
    def damage(self, att, dfn, counter=False, att_pos=None):
        base = self.dmg[att.t][UNIT[dfn.t][0]]
        if counter:
            base -= 1
        if base <= 0:                                     # A1 y A2: 0 = no ataca / no contraataca
            return 0
        cover = UNIT[dfn.t][0] == "pie" and self.terrain[dfn.pos] in COVER
        return max(1, base + (1 if att.veteran or att.char else 0) - (1 if cover else 0))

    def can_attack(self, att, dfn, from_pos):
        if dfn.side == att.side or self.dmg[att.t][UNIT[dfn.t][0]] <= 0:
            return False
        lo, hi = UNIT[att.t][5], UNIT[att.t][6]
        if att.t == "R":                                   # C7.2
            if from_pos != att.pos or att.moved:
                return False
            if self.terrain[att.pos] == "C":
                hi += 1
        return lo <= dist(from_pos, dfn.pos) <= hi

    def _hit(self, att, dfn):
        d = self.damage(att, dfn)
        self.stats["damage_events"][att.side] += 1
        self.stats["last_event_turn"] = self.turn
        dfn.hp -= d
        if dfn.hp <= 0:
            self._kill(dfn, att)
            return
        if self.cfg.counter and att.t != "R" and dfn.t != "R" and dist(att.pos, dfn.pos) == 1:  # C7.4
            c = self.damage(dfn, att, counter=True)
            if c > 0:
                att.hp -= c
                if att.hp <= 0:
                    self._kill(att, dfn)

    def worth(self, t):
        """Valor de una unidad para el desempate: su coste; la tripulacion vale 1 y el personaje 4."""
        return 1 if t == "P" else (4 if t == "C" else self.cost(t))

    def _kill(self, u, killer, credit=None):
        """credit: bando al que se apunta la baja cuando no hay unidad atacante (torretas, cartas)."""
        if killer is not None:                             # C7.6
            killer.veteran = True
            self.kills[killer.side][killer.t] += 1
            credit = killer.side
        elif credit is None and not self.cfg.plaza_turrets and not self.cfg.cards:
            credit = 1 - u.side                            # comportamiento anterior a v5
        if credit is not None and credit != u.side:
            self.destroyed[credit] += self.worth(u.t)
        pos, side = u.pos, u.side
        riders = [self.units[i] for i in (u.crew, u.char) if i] if u.t in VEHICLES else []
        self._remove(u)
        if u.t == "C":
            self._char_died(side)
        for crew in riders:                                # C8.5 y A8
            free = [q for q in neighbors(pos) if q not in self.occ and self.passable(q, 0)]
            if free:
                enemies = self.on_board(1 - side)
                q = max(free, key=lambda q: (min([dist(q, e.pos) for e in enemies] or [99]), q))
                crew.carrier = None
                crew.pos = q
                crew.hp = CHAR_EJECT_HP if crew.t == "C" else 1
                crew.acted = True
                self.occ[q] = crew.id
                self.stats["eject"][side] += 1
                if crew.t == "C":
                    self.stats["char_eject"] += 1
            else:
                del self.units[crew.id]
                if credit is not None and credit != side:
                    self.destroyed[credit] += self.worth(crew.t)
                if crew.t == "C":
                    self._char_died(side)
        self._check_elimination()

    def _char_died(self, side):
        self.stats["char_deaths"] += 1
        self.supplies[1 - side] = min(self.cfg.supply_cap, self.supplies[1 - side] + CHAR_BOUNTY)

    def _check_elimination(self):                           # C12.2 y A3
        for s in (0, 1):
            if self.winner is None and not self.activatable(s):
                self._finish(1 - s, "eliminacion")

    def _finish(self, winner, how):
        if self.winner is None:
            self.winner, self.how = winner, how

    # ------------------------------------------------------------------ objetivos posibles
    def attack_targets(self, u, from_pos):
        return [e for e in self.on_board(1 - u.side) if self.can_attack(u, e, from_pos)]

    def struct_targets(self, u, from_pos):
        out = []
        if u.t in ("T", "A", "I"):                         # C9.1 y C9.2
            for q in neighbors(from_pos):
                ch = self.terrain[q]
                if (ch == "#" and u.t == "T") or ch == "X":
                    out.append(q)
        if u.t == "R" and from_pos == u.pos and not u.moved:  # C9.1-C9.3
            hi = 3 + (1 if self.terrain[u.pos] == "C" else 0)
            for q, ch in self.terrain.items():
                if 2 <= dist(q, u.pos) <= hi and (ch in "#X" or (ch == "P" and q not in self.occ)):
                    if ch == "P" and not self.tracks_connected({q: "~"}):   # C9.5
                        continue
                    out.append(q)
        return out

    def barricade_cells(self, u, from_pos):                 # C9.4
        if u.t != "I" or u.barricades <= 0:
            return []
        out = []
        for q in neighbors(from_pos):
            if q in self.occ or self.terrain[q] not in ".=":
                continue
            if self.tracks_connected({q: "X"}):            # C9.5
                out.append(q)
        return out

    def can_capture(self, u, at):                           # C10.1 y A5
        return u.t in FOOT and at in self.owner and self.owner[at] != u.side

    def repair_targets(self, u, at):                        # C8.6
        out = []
        for q in neighbors(at):
            v = self.at(q)
            if v is None or v.side != u.side or v.t not in VEHICLES or v.hp >= UNIT[v.t][2]:
                continue
            if u.t == "I" or (u.t == self.cfg.crew and u.home == v.id):
                out.append(v.id)
        return out

    def hack_targets(self, u, at):                          # C8.10: el hacker roba vehiculos vacios
        if u.t != "K" or not self.room(u.side, "T"):
            return []
        return [v.id for v in self.on_board(1 - u.side)
                if v.t in VEHICLES and not v.crew and not v.char and dist(at, v.pos) <= HACK_RANGE]

    def train_types(self, u, at):                           # C8.9
        if not self.cfg.train or u.t != "P" or self.owner.get(at) != u.side or self.terrain[at] not in "HQ":
            return []
        if self.terrain[at] == "H" and not self.cfg.hq_produces:
            return []
        pay = self.cfg.train == "pagando"
        return [t for t in sorted(self.allowed[u.side] & set("FAIK"))
                if (not pay or self.supplies[u.side] >= self.cost(t)) and self.room(u.side, t)]

    def board_targets(self, u, at):                         # C8.4; el personaje, a cualquier vehiculo sin personaje
        if u.t not in FOOT:
            return []
        slot = "char" if u.t == "C" else "crew"
        return [self.occ[q] for q in neighbors(at)
                if q in self.occ and self.units[self.occ[q]].side == u.side
                and self.units[self.occ[q]].t in VEHICLES and not getattr(self.units[self.occ[q]], slot)]

    # ------------------------------------------------------------------ acciones legales
    def legal_actions(self):
        s = self.current
        acts = [Action("end")]
        for u in self.on_board(s):
            if u.acted or u.training or u.stun == self.turn or (u.t in VEHICLES and not u.crew and not u.char):
                continue
            if UNIT[u.t][4] > self.pm:
                continue
            for e in self.reach(u):
                if e != u.pos:
                    acts.append(Action("activate", u.id, e, "none"))
                for en in self.attack_targets(u, e):
                    acts.append(Action("activate", u.id, e, "attack", en.id))
                if self.can_capture(u, e):
                    acts.append(Action("activate", u.id, e, "capture"))
                for v in self.repair_targets(u, e):
                    acts.append(Action("activate", u.id, e, "repair", v))
                for v in self.board_targets(u, e):
                    acts.append(Action("activate", u.id, e, "board", v))
                for q in self.struct_targets(u, e):
                    acts.append(Action("activate", u.id, e, "struct", q))
                for q in self.barricade_cells(u, e):
                    acts.append(Action("activate", u.id, e, "barricade", q))
                for t in self.train_types(u, e):
                    acts.append(Action("activate", u.id, e, "train", t))
                if self.pm >= HACK_PM:
                    for v in self.hack_targets(u, e):
                        acts.append(Action("activate", u.id, e, "hack", v))
                if self.turrets:
                    for q in self.turret_targets(u, e):
                        acts.append(Action("activate", u.id, e, "attack_turret", q))
                    for sub, q in self.engineer_turret_actions(u, e):
                        acts.append(Action("activate", u.id, e, sub, q))
        for v in self.on_board(s):                         # C8.2: desembarcar, 0 PM
            if v.t in VEHICLES and (v.crew or v.char):
                for q in neighbors(v.pos):
                    if q not in self.occ and self.passable(q, 0):
                        if v.crew:
                            acts.append(Action("dismount", v.id, q))
                        if v.char:
                            acts.append(Action("dismount", v.id, q, "char"))
        if self.pm >= 1 and (self.cfg.caps or len(self.on_board(s)) < self.cfg.limit):   # C11 y A7
            for p, o in self.owner.items():
                if o != s or p in self.orders or self.terrain[p] not in "HQ":
                    continue
                for t in sorted(self.allowed[s]):
                    if t in VEHICLES and self.terrain[p] == "H":
                        continue
                    if self.terrain[p] == "H" and not self.cfg.hq_produces:
                        continue
                    if self.cost(t) <= self.supplies[s] and self.room(s, t):
                        acts.append(Action("produce", None, p, "none", t))
        if self.cfg.cards:
            acts += self.card_actions()
        return acts

    # ------------------------------------------------------------------ torretas (v5)
    def active_turret(self, q):
        t = self.turrets.get(q)
        return t if t and t["hp"] > 0 else None

    def turret_targets(self, u, from_pos):
        """Torretas enemigas o neutrales que la unidad puede atacar (se tratan como blindadas)."""
        if self.dmg[u.t]["bli"] <= 0:
            return []
        lo, hi = UNIT[u.t][5], UNIT[u.t][6]
        if u.t == "R":
            if from_pos != u.pos or u.moved:
                return []
            if self.terrain[u.pos] == "C":
                hi += 1
        return [q for q, t in self.turrets.items() if t["hp"] > 0 and t["owner"] != u.side and lo <= dist(from_pos, q) <= hi]

    def engineer_turret_actions(self, u, at):
        """Ingeniero v5: sabotaje de torretas ajenas adyacentes; reparar o reconstruir torretas propias."""
        if u.t != "I" or not self.cfg.plaza_turrets:
            return []
        out = []
        for q in [at] + list(neighbors(at)):
            t = self.turrets.get(q)
            if not t:
                continue
            if t["hp"] > 0 and t["owner"] != u.side and t["off"] < self.turn + 1:
                out.append(("sabotage", q))
            elif t["owner"] == u.side and t["hp"] < t["max"] and (t["hp"] > 0 or t["kind"] == "plaza"):
                out.append(("repair_turret", q))
        return out

    def turret_damage(self, u, q):
        t = self.turrets[q]
        return max(1, self.dmg[u.t]["bli"] + (1 if u.veteran or u.char else 0) - t.get("armor", 0))

    def _damage_turret(self, q, d):
        t = self.turrets[q]
        t["hp"] = max(0, t["hp"] - d)
        self.stats["last_event_turn"] = self.turn
        if t["hp"] == 0:
            self.stats["turrets_destroyed"] += 1
            if t["kind"] != "plaza":                       # las de carta desaparecen
                self.terrain[q] = t["base"]
                del self.turrets[q]

    def _turrets_fire(self, s):
        """Al terminar el turno de s, cada torreta activa que no sea suya dispara al enemigo mas cercano."""
        for q, t in sorted(self.turrets.items()):
            if t["hp"] <= 0 or t["owner"] == s or self.turn <= t["off"] or self.winner is not None:
                continue
            cands = [u for u in self.on_board(s) if t["lo"] <= dist(u.pos, q) <= t["hi"]]
            if not cands:
                continue
            u = min(cands, key=lambda u: (dist(u.pos, q), u.hp, u.id))
            cover = UNIT[u.t][0] == "pie" and self.terrain[u.pos] in COVER
            d = max(1, t["dmg"] - (1 if cover else 0))
            self.stats["turret_shots"] += 1
            self.stats["last_event_turn"] = self.turn
            u.hp -= d
            if u.hp <= 0:
                self.stats["turret_kills"] += 1
                self._kill(u, None, credit=t["owner"])

    def _place_turret(self, q, kind, owner):
        cfg = TURRETS[kind]
        self.turrets[q] = dict(cfg, max=cfg["hp"], owner=owner, off=-1, kind=kind, base=self.terrain[q])
        self.terrain[q] = "O"

    # ------------------------------------------------------------------ cartas (v5)
    def card_available(self, c):
        s = self.current
        pm, _, rnd = self.card_def[c]
        return self.pm >= pm and self.round >= rnd and self.card_ready[s].get(c, 99) <= self.turn

    def _area(self, center):
        return [(center[0] + dx, center[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                if 0 <= center[0] + dx < W and 1 <= center[1] + dy <= H]

    def card_actions(self):
        s, acts = self.current, []
        enemies = self.on_board(1 - s)
        mine_b = [p for p, o in self.owner.items() if o == s]
        for c in self.decks[s]:
            if not self.card_available(c):
                continue
            if c == "marcha":
                for u in self.on_board(s):
                    if u.acted and u.stun != self.turn and (u.t not in VEHICLES or u.crew or u.char):
                        for e in self.reach(u):
                            if e != u.pos:
                                acts.append(Action("card", u.id, e, c))
            elif c == "reparacion":
                for v in self.on_board(s):
                    if v.t in VEHICLES and v.hp < UNIT[v.t][2]:
                        acts.append(Action("card", v.id, v.pos, c))
            elif c in ("torreta", "misiles"):
                if sum(1 for t in self.turrets.values() if t["owner"] == s and t["kind"] != "plaza") >= 3:
                    continue
                cells = {q for p in mine_b for q in neighbors(p)}
                for q in sorted(cells):
                    if q not in self.occ and q not in self.turrets and self.terrain[q] in ".=Br" \
                            and self.tracks_connected({q: "O"}):
                        acts.append(Action("card", None, q, c))
            elif c == "refuerzo":
                hq = self.hq[s]
                spots = [hq] + sorted(neighbors(hq))
                if self.owner[hq] == s and any(q not in self.occ and self.passable(q, 0) for q in spots):
                    for t in sorted(self.allowed[s] & set("FAIK")):
                        if self.room(s, t):
                            acts.append(Action("card", None, hq, c, t))
            elif c == "hackeo":
                for q, t in self.turrets.items():
                    if t["hp"] > 0 and t["owner"] != s:
                        acts.append(Action("card", None, q, c))
            elif c == "pem":
                centers = {e.pos for e in enemies if e.t in VEHICLES} | {q for q, t in self.turrets.items()
                                                                       if t["hp"] > 0 and t["owner"] != s}
                for q in sorted(centers):
                    acts.append(Action("card", None, q, c))
            elif c in ("aereo", "saturacion"):
                for q in sorted({e.pos for e in enemies}):
                    acts.append(Action("card", None, q, c))
            elif c == "paracaidistas":
                if not self.room(s, "F"):
                    continue
                epos = {e.pos for e in enemies}
                cells = {q for p, o in self.owner.items() if o != s for q in [p] + list(neighbors(p))}
                for q in sorted(cells):
                    if q not in self.occ and q not in self.turrets and self.passable(q, 0) \
                            and not any(n in epos for n in neighbors(q)):
                        acts.append(Action("card", None, q, c))
        return acts

    def _card_damage(self, u, d, s):
        u.hp -= d
        self.stats["last_event_turn"] = self.turn
        if u.hp <= 0:
            self._kill(u, None, credit=s)

    def _apply_card(self, a, s):
        c = a.sub
        pm, rech, _ = self.card_def[c]
        self.pm -= pm
        self.stats["pm_used"][s] += pm
        self.card_ready[s][c] = self.turn + 2 * rech
        self.stats["cards"][s][c] += 1
        if c == "marcha":
            u = self.units[a.unit]
            self._drop_capture_of(u.id)
            del self.occ[u.pos]
            u.pos = a.dest
            self.occ[a.dest] = u.id
        elif c == "reparacion":
            v = self.units[a.unit]
            v.hp = min(UNIT[v.t][2], v.hp + 3)
        elif c in ("torreta", "misiles"):
            self._place_turret(a.dest, c, s)
        elif c == "refuerzo":
            hq = self.hq[s]
            spot = next(q for q in [hq] + sorted(neighbors(hq)) if q not in self.occ and self.passable(q, 0))
            u = self.add_unit(s, a.target, spot)
            u.acted = True
        elif c == "hackeo":
            self.turrets[a.dest]["off"] = self.turn + 2
        elif c == "pem":
            for q in self._area(a.dest):
                e = self.at(q)
                if e is not None and e.side != s and (e.t in VEHICLES or self.cfg.pem_all):
                    e.stun = self.turn + 1
                t = self.turrets.get(q)
                if t and t["owner"] != s:
                    t["off"] = self.turn + 2
        elif c == "aereo":
            for q in [a.dest] + list(neighbors(a.dest)):
                e = self.at(q)
                if e is not None and e.side != s:
                    self._card_damage(e, 4 if q == a.dest else 2, s)
        elif c == "saturacion":
            for q in self._area(a.dest):
                e = self.at(q)
                if e is not None and e.side != s:
                    self._card_damage(e, 2, s)
        elif c == "paracaidistas":
            u = self.add_unit(s, "F", a.dest)
            u.acted = True
        self._check_elimination()

    def is_legal(self, a):
        return a in set(self.legal_actions())

    # ------------------------------------------------------------------ aplicar
    def apply(self, a, check=True):
        if check and not self.is_legal(a):
            raise ValueError(f"accion ilegal: {a}")
        s = self.current
        self.log.append([self.turn] + a.as_list())
        if a.kind == "end":
            self.end_turn()
            return
        if a.kind == "dismount":
            v = self.units[a.unit]
            if a.sub == "char":
                c = self.units[v.char]
                v.char = None
            else:
                c = self.units[v.crew]
                v.crew = None
            c.carrier = None
            c.pos = a.dest
            self.occ[a.dest] = c.id
            self.stats["dismount"][s] += 1
            return
        if a.kind == "card":
            self._apply_card(a, s)
            return
        if a.kind == "produce":
            t = a.target
            self.pm -= 1
            self.stats["pm_used"][s] += 1
            self.supplies[s] -= self.cost(t)
            self.orders[a.dest] = (s, t, self.turn + 2 * (UNIT[t][8] * self.cfg.build_mult + self.cfg.build_extra))
            return
        u = self.units[a.unit]
        cost = HACK_PM if a.sub == "hack" else UNIT[u.t][4]
        self.pm -= cost
        self.stats["pm_used"][s] += cost
        u.acted = True
        self.activations[s][u.t] += 1
        if a.dest != u.pos:
            self._drop_capture_of(u.id)
            del self.occ[u.pos]
            u.pos = a.dest
            self.occ[a.dest] = u.id
            u.moved = True
        if a.sub == "attack":
            self._hit(u, self.units[a.target])
        elif a.sub == "capture":
            self._capture(u)
        elif a.sub == "repair":
            v = self.units[a.target]
            v.hp = min(UNIT[v.t][2], v.hp + (2 if u.t == "I" else 1))
            self.stats["repairs"][s] += 1
        elif a.sub == "board":
            v = self.units[a.target]
            self._drop_capture_of(u.id)
            del self.occ[u.pos]
            u.pos = None
            u.carrier = v.id
            if u.t == "C":
                v.char = u.id
            else:
                u.home = v.id
                v.crew = u.id
            self.stats["board"][s] += 1
        elif a.sub == "struct":
            self._destroy(a.target)
        elif a.sub == "attack_turret":
            self.stats["damage_events"][s] += 1
            d = self.turret_damage(u, a.target)
            self._damage_turret(a.target, d)
        elif a.sub == "sabotage":
            self.turrets[a.target]["off"] = self.turn + 2
            self.stats["sabotages"] += 1
        elif a.sub == "repair_turret":
            t = self.turrets[a.target]
            t["hp"] = 3 if t["hp"] == 0 else min(t["max"], t["hp"] + 2)
            self.stats["turret_repairs"] += 1
        elif a.sub == "hack":
            v = self.units[a.target]
            v.side = s
            v.acted = True
            self.stats["hacks"][s] += 1
            self.stats["last_event_turn"] = self.turn
        elif a.sub == "train":
            if self.cfg.train == "pagando":
                self.supplies[s] -= self.cost(a.target)
            u.training = (a.target, self.turn + 2)
            self.stats["trainings"][s] += 1
        elif a.sub == "barricade":
            self.terrain[a.target] = "X"
            u.barricades -= 1
            self.stats["barricades_built"][s] += 1

    def _capture(self, u):
        p = u.pos
        c = self.capture.get(p)
        if c is None or c[1] != u.id:
            c = [u.side, u.id, 0]
        c[2] += 2 if u.t in ("F", "C") else 1          # el fusilero y el personaje capturan 2 (C10.1, C8.8)
        self.stats["last_event_turn"] = self.turn
        need = self.cfg.hq_points if self.terrain[p] == "H" else 4
        if c[2] >= need:
            prev = self.owner[p]
            self.owner[p] = u.side
            if p in self.turrets:                                 # v5: la torreta de la plaza cambia de dueno
                self.turrets[p]["owner"] = u.side
            if self.terrain[p] == "U":                            # v3: conquista y reconquista de ciudades
                bonus = self.cfg.city_first if prev is None else self.cfg.city_retake
                self.supplies[u.side] = min(self.cfg.supply_cap, self.supplies[u.side] + bonus)
            self.capture.pop(p, None)
            self.stats["captures"][u.side] += 1
            if p in self.orders and self.orders[p][0] == prev:   # C11.4
                del self.orders[p]
            if self.terrain[p] == "H":                            # C12.1
                self._finish(u.side, "captura_CG")
        else:
            self.capture[p] = c

    def _destroy(self, q):
        ch = self.terrain[q]
        if ch == "#":
            self.terrain[q] = "r"
            self.stats["walls"] += 1
        elif ch == "X":
            self.terrain[q] = "."
            self.stats["barricades_destroyed"] += 1
        elif ch == "P":
            self.terrain[q] = "~"
            self.stats["bridges"] += 1
        self.stats["last_event_turn"] = self.turn

    # ------------------------------------------------------------------ turnos (C4)
    def start_turn(self):
        s = self.current
        income = self.cfg.income_base + sum(
            self.cfg.income_hq if self.terrain[p] == "H" else (self.cfg.income_city if self.terrain[p] == "U" else 0)
            for p, o in self.owner.items() if o == s)
        self.supplies[s] = min(self.cfg.supply_cap, self.supplies[s] + income)
        if self.cfg.domination:                           # victoria por dominio (v3)
            mine = sum(1 for o in self.owner.values() if o == s)
            self.dom_streak[s] = self.dom_streak[s] + 1 if mine >= self.cfg.domination else 0
            if self.dom_streak[s] >= 2:
                self._finish(s, "dominio")
        self.points[s] += sum(1 for o in self.owner.values() if o == s)
        if self.cfg.lead and self.points[s] - self.points[1 - s] >= self.cfg.lead:
            self._finish(s, "ventaja_puntos")
        if self.cfg.heal:
            for p, o in self.owner.items():
                if o == s and self.terrain[p] in ("HU" if self.cfg.hq_heals else "U"):
                    u = self.at(p)
                    if u is not None and u.side == s:
                        u.hp = min(UNIT[u.t][2], u.hp + 1)
        for q, t in self.turrets.items():                # v6: la torreta de una plaza propia se repara sola
            if t["kind"] == "plaza" and t["owner"] == s and 0 < t["hp"] < t["max"]:
                t["hp"] = min(t["max"], t["hp"] + self.cfg.plaza_regen)
        for u in self.units.values():                    # C8.9: termina la evolucion
            if u.side == s and u.training and u.training[1] <= self.turn:
                u.t = u.training[0]
                u.hp = UNIT[u.t][2]
                u.barricades = 2 if u.t == "I" else 0
                u.home = None
                u.training = None
        for p, (os_, t, ready) in sorted(self.orders.items()):
            if os_ == s and ready <= self.turn:
                spot = p if p not in self.occ else next(
                    (q for q in sorted(neighbors(p)) if q not in self.occ and self.passable(q, UNIT[t][1])), None)
                if spot is not None:
                    crewed = not self.cfg.caps or self.count(s, "crew") < self.cfg.caps.get("crew", 99)
                    self.add_unit(s, t, spot, with_crew=crewed)   # con 6 tripulaciones, el equipo sale vacio
                    self.built[s][t] += 1
                    del self.orders[p]
        for u in self.units.values():
            if u.side == s:
                u.acted = False
                u.moved = False
        self.pm = self.pm_rule()[0] + self.saved_pm[s]
        self.saved_pm[s] = 0
        if self.round == self.cfg.rounds and s != self.first:
            self._snapshot_last = self._standing()

    def end_turn(self):
        s = self.current
        if self.turrets:
            self._turrets_fire(s)
        keep = min(self.pm_rule()[1], self.pm)
        self.saved_pm[s] = keep
        self.stats["pm_lost"][s] += self.pm - keep
        self.stats["max_quiet"] = max(self.stats["max_quiet"], self.turn - self.stats["last_event_turn"])
        self.turn += 1
        if s != self.first:
            self.trace.append((self.round, self.value(0), self.value(1)))
            self.round += 1
        self.current = 1 - s
        if self.round > self.cfg.rounds and self.winner is None:
            self._tiebreak()

    def pm_rule(self):
        """(PM por turno, maximo que se puede guardar) en la ronda actual."""
        if not self.cfg.pm_schedule:
            return self.cfg.pm, 1
        pm, keep = self.cfg.pm, 1
        for r, p, k in self.cfg.pm_schedule:
            if self.round >= r:
                pm, keep = p, k
        return pm, keep

    def alive_value(self, side):
        return sum(self.worth(u.t) for u in self.units.values() if u.side == side)

    def value(self, side):
        """Ventaja material para medir remontadas: unidades (coste por PV restantes), suministros,
        encargos en curso y 3 por edificio. El personaje vale 4."""
        v = self.supplies[side] + 3 * sum(1 for o in self.owner.values() if o == side)
        for u in self.units.values():
            if u.side == side:
                cost = 4 if u.t == "C" else self.cost(u.t)
                v += cost * u.hp / UNIT[u.t][2]
        v += sum(self.cost(t) for (s, t, _) in self.orders.values() if s == side)
        return v

    def _standing(self):
        b = [sum(1 for o in self.owner.values() if o == x) for x in (0, 1)]
        inv = [sum(self.cost(u.t) for u in self.on_board(x)) for x in (0, 1)]
        if self.cfg.tiebreak == "puntos":
            key = [(self.points[x],) for x in (0, 1)]
        elif self.cfg.tiebreak == "edificios_bajas":
            key = [(b[x], sum(self.kills[x].values())) for x in (0, 1)]
        elif self.cfg.tiebreak == "edificios_valor":
            key = [(b[x], self.destroyed[x], self.alive_value(x)) for x in (0, 1)]
        else:
            key = [(b[x], inv[x]) for x in (0, 1)]
        return 0 if key[0] > key[1] else (1 if key[1] > key[0] else -1)

    def _tiebreak(self):                                     # C12.4 o variante S2
        if self.cfg.tiebreak == "puntos":
            w = self._standing()
            self._finish(w, "ronda_limite_puntos" if w >= 0 else "empate")
        elif self.cfg.tiebreak == "edificios_valor":           # v4: edificios, valor destruido y valor vivo
            w = self._standing()
            b = [sum(1 for o in self.owner.values() if o == x) for x in (0, 1)]
            how = "edificios" if b[0] != b[1] else ("valor_destruido" if self.destroyed[0] != self.destroyed[1] else "valor_vivo")
            self._finish(w, f"ronda_limite_{how}" if w >= 0 else "empate")
        elif self.cfg.tiebreak == "edificios_bajas":           # v3: edificios y despues unidades destruidas
            b = [sum(1 for o in self.owner.values() if o == x) for x in (0, 1)]
            k = [sum(self.kills[x].values()) for x in (0, 1)]
            if b[0] != b[1]:
                self._finish(0 if b[0] > b[1] else 1, "ronda_limite_edificios")
            elif k[0] != k[1]:
                self._finish(0 if k[0] > k[1] else 1, "ronda_limite_bajas")
            else:
                self._finish(-1, "empate")
        else:
            b = [sum(1 for o in self.owner.values() if o == x) for x in (0, 1)]
            inv = [sum(self.cost(u.t) for u in self.on_board(x)) for x in (0, 1)]
            if b[0] != b[1]:
                self._finish(0 if b[0] > b[1] else 1, "ronda_limite_edificios")
            elif inv[0] != inv[1]:
                self._finish(0 if inv[0] > inv[1] else 1, "ronda_limite_inversion")
            else:
                self._finish(-1, "empate")
        snap = getattr(self, "_snapshot_last", None)
        if snap is not None:
            self.stats["last_turn_flip"] = int(snap != self.winner)

    # ------------------------------------------------------------------ utilidades
    def state_hash(self):
        parts = [self.map_name, str(self.turn), str(self.supplies), str(self.points), str(self.winner)]
        parts += [f"{cell_name(p)}{ch}" for p, ch in sorted(self.terrain.items())]
        parts += [f"{cell_name(p)}{o}" for p, o in sorted(self.owner.items())]
        parts += [f"{u.id}{u.side}{u.t}{u.hp}{u.pos}{u.veteran}{u.crew}{u.char}{u.training}" for u in sorted(self.units.values(), key=lambda x: x.id)]
        if self.turrets:
            parts += [f"{cell_name(q)}{t['hp']}{t['owner']}{t['off']}" for q, t in sorted(self.turrets.items())]
        if self.cfg.cards:
            parts += [f"{x}{c}{r}" for x in (0, 1) for c, r in sorted(self.card_ready[x].items())]
        return hashlib.sha256("|".join(parts).encode()).hexdigest()[:16]


def deployment_zone(g, side):
    """C3.3: casillas transitables a 3 pasos o menos del cuartel general o del cuartel propios."""
    srcs = [p for p, o in g.owner.items() if o == side and g.terrain[p] in "HQ"]
    return [p for p in g.terrain if any(dist(p, s) <= 3 for s in srcs) and g.passable(p, 0)]
