"""Pruebas del motor de reglas. Ejecutar con:  python3 -m unittest discover -s tests -v
Cada prueba cita la regla (C1-C13) o la aclaracion (A1-A8) que comprueba."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from tw_sim.play import play_game, replay  # noqa: E402
from tw_sim.rules import MAPS, Action, Config, Game, build_terrain, cell, cell_name, deployment_zone, dist, neighbors  # noqa: E402

E = "Encrucijada"
R = "Ciudad en ruinas"


def empty(map_name=E, allowed=None, **cfg):
    armies = {0: allowed or [], 1: allowed or []}
    g = Game(map_name, 0, armies, Config(**cfg))
    return g


def put(g, side, t, name, hp=None, crew=True):
    return g.add_unit(side, t, cell(name), hp, with_crew=crew)


def act(g, u, dest, sub="none", target=None):
    a = Action("activate", u.id, cell(dest), sub, target)
    g.apply(a)
    return a


class C1Tablero(unittest.TestCase):
    def test_simetria_180(self):
        for m in MAPS:
            t = build_terrain(m)
            for (c, r), ch in t.items():
                self.assertEqual(ch, t[(11 - c, 9 - r)], f"{m} {c},{r}")

    def test_sin_diagonales(self):
        self.assertEqual(set(neighbors(cell("D4"))), {cell("C4"), cell("E4"), cell("D3"), cell("D5")})


class C2Terreno(unittest.TestCase):
    def test_ruedas_pagan_2_en_llano(self):
        g = empty()
        j = put(g, 0, "J", "A1")
        self.assertEqual(g.reach(j)[cell("B1")], 2)

    def test_rio_solo_a_pie(self):
        g = empty()
        f = put(g, 0, "F", "E2")
        t = put(g, 0, "T", "E3")
        self.assertEqual(g.reach(f)[cell("F2")], 2)
        self.assertNotIn(cell("F2"), g.reach(t))


class C3Preparacion(unittest.TestCase):
    def test_zona_de_despliegue(self):
        g = empty()
        zone = deployment_zone(g, 0)
        for p in zone:
            self.assertTrue(min(dist(p, cell("A4")), dist(p, cell("B2"))) <= 3)
            self.assertTrue(g.passable(p, 0))

    def test_inicio(self):
        g = empty()
        self.assertEqual(g.supplies, [5, 5])
        self.assertEqual(g.owner[cell("A4")], 0)
        self.assertEqual(g.owner[cell("K7")], 1)
        self.assertIsNone(g.owner[cell("C1")])


class C4Turnos(unittest.TestCase):
    def test_ingresos_y_tope(self):
        g = empty()
        g.owner[cell("C1")] = 0
        g.start_turn()
        self.assertEqual(g.supplies[0], 5 + 2 + 1)
        g.supplies[0] = 19
        g.apply(Action("end"))
        g.start_turn()
        g.apply(Action("end"))
        g.start_turn()
        self.assertEqual(g.supplies[0], 20)

    def test_curacion_en_ciudad_propia(self):
        g = empty()
        g.owner[cell("C1")] = 0
        f = put(g, 0, "F", "C1", hp=1)
        g.start_turn()
        self.assertEqual(f.hp, 2)

    def test_guardar_un_pm(self):
        g = empty()
        g.start_turn()
        self.assertEqual(g.pm, 5)
        g.apply(Action("end"))
        self.assertEqual(g.saved_pm[0], 1)
        g.start_turn(); g.apply(Action("end")); g.start_turn()
        self.assertEqual(g.pm, 6)

    def test_limite_de_rondas(self):
        g = empty(rounds=2)
        put(g, 0, "F", "A1"); put(g, 1, "F", "L8")
        for _ in range(4):
            g.start_turn(); g.apply(Action("end"))
        self.assertIsNotNone(g.winner)


class C5Acciones(unittest.TestCase):
    def test_una_activacion_por_turno(self):
        g = empty()
        f = put(g, 0, "F", "A1"); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, f, "A2")
        self.assertFalse(any(a.unit == f.id and a.kind == "activate" for a in g.legal_actions()))

    def test_desembarcar_es_gratis(self):
        g = empty()
        t = put(g, 0, "T", "D2"); put(g, 1, "F", "L8")
        g.start_turn()
        g.apply(Action("dismount", t.id, cell("D1")))
        self.assertEqual(g.pm, 5)
        self.assertIsNone(t.crew)


class C6Movimiento(unittest.TestCase):
    def test_atraviesa_aliado_sin_terminar(self):
        g = empty()
        f = put(g, 0, "F", "A1"); put(g, 0, "F", "B1")
        r = g.reach(f)
        self.assertIn(cell("C1"), r)
        self.assertNotIn(cell("B1"), r)

    def test_no_atraviesa_enemigo(self):
        g = empty()
        f = put(g, 0, "F", "A1"); put(g, 1, "F", "B1")
        self.assertNotIn(cell("C1"), g.reach(f))

    def test_ruinas_terminan_el_movimiento(self):
        g = empty(R)
        f = put(g, 0, "F", "E4")
        r = g.reach(f)
        self.assertIn(cell("F4"), r)
        self.assertNotIn(cell("G4"), r)

    def test_ruinas_ocupadas_por_aliado(self):
        g = empty(R)
        f = put(g, 0, "F", "E4"); put(g, 0, "F", "F4")
        self.assertNotIn(cell("F4"), g.reach(f))


class C7Combate(unittest.TestCase):
    def test_antitanque_contra_tanque_con_contraataque(self):
        g = empty()
        a = put(g, 0, "A", "D2"); t = put(g, 1, "T", "E2")
        g.start_turn()
        act(g, a, "D2", "attack", t.id)
        self.assertEqual((t.hp, a.hp), (5, 1))

    def test_cobertura(self):
        g = empty()
        j = put(g, 0, "J", "D1"); f = put(g, 1, "F", "E1")   # E1 es bosque
        self.assertEqual(g.damage(j, f), 1)

    def test_A1_cero_no_ataca(self):
        g = empty()
        f = put(g, 0, "F", "D2"); t = put(g, 1, "T", "E2")
        self.assertNotIn(t, g.attack_targets(f, f.pos))

    def test_A2_contraataque_cero(self):
        g = empty()
        j = put(g, 0, "J", "D2"); f = put(g, 1, "F", "E2")
        g.start_turn()
        act(g, j, "D2", "attack", f.id)
        self.assertEqual((f.hp, j.hp), (1, 4))

    def test_artilleria_alcance_y_colina(self):
        g = empty()
        r = put(g, 0, "R", "B3"); e = put(g, 1, "F", "D3")
        self.assertIn(e, g.attack_targets(r, r.pos))
        g2 = empty()
        r2 = put(g2, 0, "R", "D3"); e2 = put(g2, 1, "F", "H3")   # distancia 4 desde colina
        self.assertIn(e2, g2.attack_targets(r2, r2.pos))

    def test_artilleria_no_mueve_y_dispara(self):
        g = empty()
        r = put(g, 0, "R", "B3"); e = put(g, 1, "F", "E3")
        self.assertNotIn(e, g.attack_targets(r, cell("C3")))

    def test_artilleria_no_contraataca(self):
        g = empty()
        f = put(g, 0, "F", "D2"); r = put(g, 1, "R", "E2")
        g.start_turn()
        act(g, f, "D2", "attack", r.id)
        self.assertEqual((r.hp, f.hp), (4, 3))

    def test_veterano(self):
        g = empty()
        t = put(g, 0, "T", "D2"); f = put(g, 1, "F", "E2", hp=1); f2 = put(g, 1, "F", "C2")
        g.start_turn()
        act(g, t, "D2", "attack", f.id)
        self.assertTrue(t.veteran)
        self.assertEqual(g.damage(t, f2), 4)


class C8Tripulaciones(unittest.TestCase):
    def test_eyeccion(self):
        g = empty()
        a = put(g, 0, "A", "D2"); t = put(g, 1, "T", "E2", hp=1)
        crew_id = t.crew
        g.start_turn()
        act(g, a, "D2", "attack", t.id)
        crew = g.units[crew_id]
        self.assertEqual(crew.hp, 1)
        self.assertIn(crew.pos, set(neighbors(cell("E2"))))
        self.assertTrue(g.passable(crew.pos, 0))                       # A8

    def test_eyeccion_bloqueada(self):
        g = empty()
        t = put(g, 1, "T", "D4", hp=1)                                   # E4 es muro
        a = put(g, 0, "A", "C4"); put(g, 0, "F", "D5"); put(g, 0, "F", "D3")
        crew_id = t.crew
        g.start_turn()
        act(g, a, "C4", "attack", t.id)
        self.assertNotIn(crew_id, g.units)

    def test_subir_conserva_pv(self):
        g = empty()
        j = put(g, 0, "J", "D2"); f = put(g, 0, "F", "B1", hp=2); put(g, 1, "F", "L8")
        g.start_turn()
        g.apply(Action("dismount", j.id, cell("D3")))
        act(g, f, "C2", "board", j.id)
        self.assertEqual(j.crew, f.id)
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        g.apply(Action("dismount", j.id, cell("D1")))
        self.assertEqual((g.units[f.id].t, g.units[f.id].hp), ("F", 2))

    def test_tripulacion_repara_solo_su_vehiculo(self):
        g = empty()
        t1 = put(g, 0, "T", "D2"); t2 = put(g, 0, "T", "C3", hp=5); put(g, 1, "F", "L8")
        g.start_turn()
        g.apply(Action("dismount", t1.id, cell("D3")))
        crew = g.units[[u for u in g.units if g.units[u].home == t1.id][0]]
        self.assertNotIn(t2.id, g.repair_targets(crew, crew.pos))
        t1.hp = 6
        self.assertIn(t1.id, g.repair_targets(crew, crew.pos))

    def test_vehiculo_vacio_no_se_activa(self):
        g = empty()
        t = put(g, 0, "T", "D2"); put(g, 1, "F", "L8")
        g.start_turn()
        g.apply(Action("dismount", t.id, cell("D1")))
        self.assertFalse(any(a.kind == "activate" and a.unit == t.id for a in g.legal_actions()))


class C9Terreno(unittest.TestCase):
    def test_tanque_derriba_muro(self):
        g = empty()
        t = put(g, 0, "T", "D4"); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, t, "D4", "struct", cell("E4"))
        self.assertEqual(g.terrain[cell("E4")], "r")

    def test_A4_puente_por_casillas_y_conectividad(self):
        g = empty()
        r = put(g, 0, "R", "D3"); put(g, 1, "F", "L8")
        self.assertIn(cell("F3"), g.struct_targets(r, r.pos))
        g.start_turn()
        act(g, r, "D3", "struct", cell("F3"))
        self.assertEqual(g.terrain[cell("F3")], "~")
        self.assertEqual(g.terrain[cell("G3")], "P")
        r2 = put(g, 0, "R", "D6")
        self.assertNotIn(cell("F6"), g.struct_targets(r2, r2.pos))       # C9.5

    def test_puente_ocupado(self):
        g = empty()
        r = put(g, 0, "R", "D3"); put(g, 1, "F", "F3")
        self.assertNotIn(cell("F3"), g.struct_targets(r, r.pos))

    def test_barricada_y_conectividad(self):
        g = empty()
        i = put(g, 0, "I", "D6")
        self.assertIn(cell("E6"), g.barricade_cells(i, i.pos))
        g.terrain[cell("F3")] = "~"                                        # solo queda el puente de la fila 6
        self.assertNotIn(cell("E6"), g.barricade_cells(i, i.pos))

    def test_ingeniero_construye_y_desmonta(self):
        g = empty()
        i = put(g, 0, "I", "B3"); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, i, "B3", "barricade", cell("A3"))
        self.assertEqual((g.terrain[cell("A3")], i.barricades), ("X", 1))
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        act(g, i, "B3", "struct", cell("A3"))
        self.assertEqual(g.terrain[cell("A3")], ".")


class C10Captura(unittest.TestCase):
    def test_captura_en_dos_turnos_A5(self):
        g = empty()
        f = put(g, 0, "F", "C2"); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, f, "C1", "capture")
        self.assertEqual(g.capture[cell("C1")][2], 2)
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        act(g, f, "C1", "capture")                                         # sin moverse
        self.assertEqual(g.owner[cell("C1")], 0)

    def test_salir_reinicia(self):
        g = empty()
        f = put(g, 0, "F", "C1"); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, f, "C1", "capture")
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        act(g, f, "D1")
        self.assertNotIn(cell("C1"), g.capture)

    def test_captura_del_cuartel_general(self):
        g = empty()
        f = put(g, 0, "F", "L5"); put(g, 1, "F", "A8")
        g.capture[cell("L5")] = [0, f.id, 2]
        g.start_turn()
        act(g, f, "L5", "capture")
        self.assertEqual((g.winner, g.how), (0, "captura_CG"))


class C11Produccion(unittest.TestCase):
    def test_tipos_y_edificio(self):
        g = empty(allowed=["F", "T"])
        put(g, 1, "F", "L8")
        g.start_turn()
        prods = {(a.dest, a.target) for a in g.legal_actions() if a.kind == "produce"}
        self.assertIn((cell("B2"), "F"), prods)
        self.assertNotIn((cell("A4"), "T"), prods)                        # el cuartel general solo hace tropas a pie
        self.assertFalse(any(t == "J" for _, t in prods))                 # C11.1

    def test_tiempo_de_fabricacion(self):
        g = empty(allowed=["T"])
        put(g, 1, "F", "L8")
        g.supplies[0] = 10
        g.start_turn()
        g.apply(Action("produce", None, cell("B2"), "none", "T"))
        for _ in range(2):
            g.apply(Action("end")); g.start_turn()
            self.assertFalse(any(u.t == "T" for u in g.on_board(0)))
            g.apply(Action("end")); g.start_turn()
        self.assertTrue(any(u.t == "T" for u in g.on_board(0)))

    def test_encargo_perdido_al_capturar(self):
        g = empty(allowed=["F"])
        e = put(g, 1, "F", "B2")
        g.orders[cell("B2")] = (0, "F", 99)
        g.capture[cell("B2")] = [1, e.id, 2]
        g.current = 1
        g.start_turn()
        act(g, e, "B2", "capture")
        self.assertNotIn(cell("B2"), g.orders)

    def test_A6_encargar_con_enemigo_encima(self):
        g = empty(allowed=["F"])
        put(g, 1, "F", "B2")
        g.start_turn()
        self.assertTrue(any(a.kind == "produce" and a.dest == cell("B2") for a in g.legal_actions()))

    def test_A7_limite_al_encargar(self):
        g = empty(allowed=["F"], limit=3)
        for n in ("A1", "B1", "C1"):
            put(g, 0, "F", n)
        put(g, 1, "F", "L8")
        g.start_turn()
        self.assertFalse(any(a.kind == "produce" for a in g.legal_actions()))


class C12Victoria(unittest.TestCase):
    def test_A3_eliminacion_con_produccion_pendiente(self):
        g = empty(allowed=["F"])
        a = put(g, 0, "A", "D2"); f = put(g, 1, "F", "E2", hp=1)
        g.orders[cell("K7")] = (1, "F", 99)
        g.start_turn()
        act(g, a, "D2", "attack", f.id)
        self.assertEqual((g.winner, g.how), (0, "eliminacion"))

    def test_desempate_edificios_e_inversion(self):
        g = empty()
        put(g, 0, "T", "D2"); put(g, 1, "F", "L8")
        g._tiebreak()
        self.assertEqual((g.winner, g.how), (0, "ronda_limite_inversion"))
        g2 = empty()
        put(g2, 0, "F", "D2"); put(g2, 1, "F", "L8")
        g2.owner[cell("J8")] = 1
        g2._tiebreak()
        self.assertEqual((g2.winner, g2.how), (1, "ronda_limite_edificios"))


class Personaje(unittest.TestCase):
    """Propuesta en estudio (Concepto v2, sec. 8.1), no forma parte de la capa 0."""

    def test_va_dentro_y_da_veterania(self):
        g = empty()
        t = put(g, 0, "T", "D2"); f = put(g, 1, "F", "E2")
        base = g.damage(t, f)
        g.add_char(t)
        self.assertEqual(g.damage(t, f), base + 1)

    def test_eyeccion_de_tripulacion_y_personaje(self):
        g = empty()
        a = put(g, 0, "A", "D2"); t = put(g, 1, "T", "E2", hp=1)
        c = g.add_char(t)
        g.start_turn()
        act(g, a, "D2", "attack", t.id)
        self.assertEqual((c.hp, c.carrier is None), (2, True))
        self.assertEqual(sum(1 for u in g.on_board(1) if u.t in "PC"), 2)

    def test_muerte_da_3_suministros(self):
        g = empty()
        a = put(g, 0, "T", "D2"); put(g, 1, "F", "L8")
        c = g.add_unit(1, "C", cell("E2"), hp=1)
        g.start_turn()
        before = g.supplies[0]
        act(g, a, "D2", "attack", c.id)
        self.assertEqual(g.supplies[0], before + 3)

    def test_vehiculo_solo_con_personaje_se_activa(self):
        g = empty()
        t = put(g, 0, "T", "D2"); put(g, 1, "F", "L8")
        g.add_char(t)
        g.start_turn()
        g.apply(Action("dismount", t.id, cell("D1")))
        self.assertTrue(any(a.kind == "activate" and a.unit == t.id for a in g.legal_actions()))
        g.apply(Action("dismount", t.id, cell("D3"), "char"))
        self.assertFalse(any(a.kind == "activate" and a.unit == t.id for a in g.legal_actions()))

    def test_fabricacion_mas_lenta(self):
        g = empty(allowed=["F"], build_extra=1)
        put(g, 1, "F", "L8")
        g.start_turn()
        g.apply(Action("produce", None, cell("B2"), "none", "F"))
        self.assertEqual(g.orders[cell("B2")][2], g.turn + 4)

    def test_tripulacion_fusilero(self):
        g = empty(crew="F")
        t = put(g, 0, "T", "D2")
        self.assertEqual(g.units[t.crew].t, "F")


class EvolucionTripulacion(unittest.TestCase):
    """C8.9: la tripulacion evoluciona a otra tropa a pie en un edificio de fabricacion; tarda 1 turno."""

    def test_evoluciona_en_un_turno(self):
        g = empty(allowed=["T", "F", "A"], train="pagando")
        p = g.add_unit(0, "P", cell("C2")); put(g, 1, "F", "L8")
        g.start_turn()
        s0 = g.supplies[0]
        act(g, p, "B2", "train", "A")
        self.assertEqual(g.supplies[0], s0 - 2)
        self.assertFalse(any(a.unit == p.id for a in g.legal_actions() if a.kind == "activate"))
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        self.assertEqual((p.t, p.hp, p.training), ("A", 3, None))

    def test_solo_tipos_elegidos_y_edificio_propio(self):
        g = empty(allowed=["T", "F"], train="gratis")
        p = g.add_unit(0, "P", cell("C2")); put(g, 1, "F", "L8")
        self.assertEqual(g.train_types(p, cell("B2")), ["F"])
        self.assertEqual(g.train_types(p, cell("C1")), [])           # ciudad neutral

    def test_sin_regla_no_evoluciona(self):
        g = empty(allowed=["F"])
        p = g.add_unit(0, "P", cell("C2"))
        self.assertEqual(g.train_types(p, cell("B2")), [])


class Hacker(unittest.TestCase):
    """C8.10: el hacker roba un vehiculo vacio enemigo a 2 casillas o menos por 2 PM."""

    def test_roba_vehiculo_vacio(self):
        g = empty()
        k = put(g, 0, "K", "D2"); t = put(g, 1, "T", "D4", crew=False); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, k, "D2", "hack", t.id)
        self.assertEqual((t.side, t.crew, g.pm), (0, None, 3))
        f = put(g, 0, "F", "C4")
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        act(g, f, "C4", "board", t.id)
        self.assertEqual(t.crew, f.id)

    def test_no_roba_tripulado_ni_lejano(self):
        g = empty()
        k = put(g, 0, "K", "D2"); t = put(g, 1, "T", "D4"); far = put(g, 1, "J", "H3", crew=False)
        self.assertEqual(g.hack_targets(k, k.pos), [])
        self.assertNotIn(far.id, g.hack_targets(k, k.pos))
        self.assertTrue(t.crew)

    def test_ingeniero_no_hackea(self):
        g = empty()
        i = put(g, 0, "I", "D2"); put(g, 1, "T", "E2", crew=False)
        self.assertEqual(g.hack_targets(i, i.pos), [])


V3 = dict(supplies_start=2, income_base=1, income_hq=0, income_city=1, city_first=5, city_retake=2, supply_cap=30,
          hq_heals=False, pm_schedule=[[1, 5, 1], [8, 6, 2], [14, 7, 3]], caps={"veh": 6, "foot": 4, "crew": 6},
          domination=7, tiebreak="edificios_bajas")


class ReglasV3(unittest.TestCase):
    """Economia, PM, limites, dominio y desempate de las reglas v3."""

    def test_economia(self):
        g = empty(**V3)
        self.assertEqual(g.supplies, [2, 2])
        f = put(g, 0, "F", "C1"); put(g, 1, "F", "L8")
        g.start_turn()
        self.assertEqual(g.supplies[0], 3)                    # +1 fijo; el cuartel general no da nada
        g.capture[cell("C1")] = [0, f.id, 2]
        act(g, f, "C1", "capture")
        self.assertEqual(g.supplies[0], 8)                    # +5 por conquista inicial
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        self.assertEqual(g.supplies[0], 10)                   # +1 fijo +1 por la ciudad

    def test_reconquista_da_2(self):
        g = empty(**V3)
        f = put(g, 0, "F", "C1"); put(g, 1, "F", "L8")
        g.owner[cell("C1")] = 1
        g.capture[cell("C1")] = [0, f.id, 2]
        g.start_turn()
        before = g.supplies[0]
        act(g, f, "C1", "capture")
        self.assertEqual(g.supplies[0], before + 2)

    def test_cuartel_general_no_cura(self):
        g = empty(**V3)
        f = put(g, 0, "F", "A4", hp=1); put(g, 1, "F", "L8")
        g.start_turn()
        self.assertEqual(f.hp, 1)

    def test_escalada_de_pm(self):
        g = empty(**V3)
        put(g, 0, "F", "A1"); put(g, 1, "F", "L8")
        g.round = 8
        g.start_turn()
        self.assertEqual(g.pm, 6)
        g.apply(Action("end"))
        self.assertEqual(g.saved_pm[0], 2)
        g.round = 14
        g.start_turn(); g.apply(Action("end")); g.start_turn()
        self.assertEqual(g.pm, 9)                             # 7 + 2 guardados

    def test_limite_de_equipos_y_equipo_vacio(self):
        g = empty(allowed=["T", "F"], **V3)
        for n in ("C2", "C3", "D2", "D3", "E2", "E3"):
            put(g, 0, "T", n)
        put(g, 1, "F", "L8")
        g.supplies[0] = 20
        g.start_turn()
        self.assertFalse(any(a.kind == "produce" and a.target == "T" for a in g.legal_actions()))
        g._kill(g.at(cell("E3")), None)                         # su tripulacion sobrevive: 5 equipos, 6 tripulaciones
        g.apply(Action("produce", None, cell("B2"), "none", "T"))
        for _ in range(3):
            g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        self.assertEqual(g.at(cell("B2")).t, "T")
        self.assertIsNone(g.at(cell("B2")).crew)

    def test_limite_de_tropas_a_pie(self):
        g = empty(allowed=["F"], **V3)
        for n in ("A1", "B1", "D1", "E1"):
            put(g, 0, "F", n)
        put(g, 1, "F", "L8")
        g.supplies[0] = 20
        g.start_turn()
        self.assertFalse(any(a.kind == "produce" for a in g.legal_actions()))

    def test_victoria_por_dominio(self):
        g = empty(**V3)
        put(g, 0, "F", "A1"); put(g, 1, "F", "L8")
        cities = [p for p, ch in g.terrain.items() if ch == "U"]
        for p in cities[:5]:
            g.owner[p] = 0                                      # 2 + 5 = 7 edificios
        g.start_turn(); self.assertIsNone(g.winner)
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end")); g.start_turn()
        self.assertEqual((g.winner, g.how), (0, "dominio"))

    def test_desempate_por_bajas(self):
        g = empty(**V3)
        put(g, 0, "F", "A1"); put(g, 1, "F", "L8")
        g.kills[1]["T"] = 2
        g._tiebreak()
        self.assertEqual((g.winner, g.how), (1, "ronda_limite_bajas"))


class MapasV4(unittest.TestCase):
    def test_mapas_nuevos(self):
        for m in ("Plaza central", "Isla central"):
            g = empty(m)
            self.assertEqual(sum(1 for ch in g.terrain.values() if ch in "HQU"), 10)
            self.assertTrue(g.tracks_connected({}), m)
            hq0, hq1 = g.hq[0], g.hq[1]
            central = [p for p, ch in g.terrain.items() if ch == "U" and dist(p, hq0) == dist(p, hq1)]
            self.assertEqual(len(central), 2, m)

    def test_mapas_cuatro_plazas(self):
        for m, equal in (("Cuatro plazas", 4), ("Cuatro plazas escalonada", 0)):
            g = empty(m)
            self.assertEqual(sum(1 for ch in g.terrain.values() if ch in "HQU"), 10)
            self.assertTrue(g.tracks_connected({}), m)
            cities = [p for p, ch in g.terrain.items() if ch == "U"]
            self.assertEqual(sum(1 for p in cities if dist(p, g.hq[0]) == dist(p, g.hq[1])), equal, m)

    def test_desempate_por_valor(self):
        g = empty(tiebreak="edificios_valor")
        a = put(g, 0, "A", "D2"); t = put(g, 1, "T", "E2", hp=1)
        g.start_turn()
        act(g, a, "D2", "attack", t.id)
        self.assertEqual(g.destroyed[0], 6)
        g._tiebreak()
        self.assertEqual((g.winner, g.how), (0, "ronda_limite_valor_destruido"))


CP = "Cuatro plazas"


class TorretasYCartasV5(unittest.TestCase):
    def test_torreta_neutral_dispara_al_mas_cercano_incluido_quien_captura(self):
        g = empty(CP, plaza_turrets=True)
        self.assertEqual(sorted(cell_name(q) for q in g.turrets), ["F5", "F7", "G2", "G4"])
        f = put(g, 0, "F", "G4"); j = put(g, 0, "J", "G5"); put(g, 1, "F", "L8")
        g.start_turn(); g.apply(Action("end"))
        self.assertEqual((f.hp, j.hp), (1, 2))   # G4 dispara a quien tiene encima; F5, al jeep que tiene al lado

    def test_al_capturar_la_plaza_la_torreta_cambia_de_dueno(self):
        g = empty(CP, plaza_turrets=True)
        f = put(g, 0, "F", "G4"); put(g, 1, "F", "L8")
        g.capture[cell("G4")] = [0, f.id, 2]
        g.start_turn()
        act(g, f, "G4", "capture")
        self.assertEqual(g.turrets[cell("G4")]["owner"], 0)
        e = put(g, 1, "F", "H4")
        g.apply(Action("end")); g.start_turn(); g.apply(Action("end"))
        self.assertEqual(e.hp, 1)                            # ahora dispara al rival

    def test_ingeniero_sabotea_repara_y_reconstruye(self):
        g = empty(CP, plaza_turrets=True)
        i = put(g, 0, "I", "H4"); put(g, 1, "F", "L8")
        g.start_turn()
        act(g, i, "H4", "sabotage", cell("G4"))
        g.apply(Action("end"))
        self.assertEqual(i.hp, 3)                            # apagada: no dispara
        t = g.turrets[cell("G4")]
        t["owner"], t["hp"] = 0, 0
        g.owner[cell("G4")] = 0
        g.start_turn(); g.apply(Action("end")); g.start_turn()
        act(g, i, "H4", "repair_turret", cell("G4"))
        self.assertEqual(t["hp"], 3)

    def test_atacar_torreta(self):
        g = empty(CP, plaza_turrets=True)
        tk = put(g, 0, "T", "H5"); put(g, 1, "F", "L8")
        g.start_turn()
        self.assertIn(cell("G4"), g.turret_targets(tk, cell("H4")))
        f = put(g, 0, "F", "H3")
        self.assertEqual(g.turret_targets(f, cell("H3")), [])   # el fusilero no hace dano a blindados
        act(g, tk, "H4", "attack_turret", cell("G4"))
        self.assertEqual(g.turrets[cell("G4")]["hp"], 3)

    def test_cartas_ronda_minima_coste_y_recarga(self):
        g = Game(CP, 0, {0: ["F"], 1: ["F"]}, Config(cards=True), {0: ["aereo", "marcha", "torreta"], 1: []})
        put(g, 0, "F", "A1"); e = put(g, 1, "T", "D3")
        g.start_turn()
        self.assertFalse(any(a.kind == "card" and a.sub == "aereo" for a in g.legal_actions()))   # desde la ronda 4
        g.round = 4
        g.apply(Action("card", None, cell("D3"), "aereo"))
        self.assertEqual((e.hp, g.pm), (4, 2))
        self.assertFalse(any(a.kind == "card" and a.sub == "aereo" for a in g.legal_actions()))   # recargando

    def test_carta_torreta_bloquea_la_casilla(self):
        g = Game(CP, 0, {0: ["F"], 1: ["F"]}, Config(cards=True), {0: ["torreta"], 1: []})
        put(g, 0, "F", "A1"); put(g, 1, "F", "L8")
        g.round = 3
        g.start_turn()
        g.apply(Action("card", None, cell("B3"), "torreta"))
        self.assertEqual(g.terrain[cell("B3")], "O")
        self.assertFalse(g.passable(cell("B3"), 0))

    def test_pem_inmoviliza_vehiculos(self):
        g = Game(CP, 0, {0: ["F"], 1: ["T"]}, Config(cards=True), {0: ["pem"], 1: []})
        put(g, 0, "F", "A1"); t = put(g, 1, "T", "D3")
        g.round = 4
        g.start_turn()
        g.apply(Action("card", None, cell("D3"), "pem"))
        g.apply(Action("end")); g.start_turn()
        self.assertFalse(any(a.kind == "activate" and a.unit == t.id for a in g.legal_actions()))

    def test_v6_torreta_resistente_y_autorreparable(self):
        g = empty(CP, plaza_turrets=True, plaza_hp=10, plaza_armor=1, plaza_regen=1)
        tk = put(g, 0, "T", "H4"); put(g, 1, "F", "L8")
        t = g.turrets[cell("G4")]
        self.assertEqual((t["hp"], g.turret_damage(tk, cell("G4"))), (10, 2))
        t["owner"], t["hp"] = 1, 5
        g.current = 1
        g.start_turn()
        self.assertEqual(t["hp"], 6)

    def test_v6_cartas_ajustadas(self):
        g = Game(CP, 0, {0: ["F"], 1: ["F"]}, Config(cards=True, card_overrides={"pem": [1, 6, 4]}), {0: ["pem"], 1: []})
        self.assertEqual(g.card_def["pem"][0], 1)

    def test_repeticion_con_torretas_y_cartas(self):
        cfg = Config(plaza_turrets=True, cards=True, damage={"A:bli": 4, "T:pie": 2, "R:bli": 3}, build_extra=1)
        g = play_game(CP, "ingenieros4", "hacker4", first=0, seed=11, config=cfg)
        r = replay(CP, "ingenieros4", "hacker4", 0, 11, list(g.log), config=cfg)
        self.assertEqual(r.state_hash(), g.state_hash())


class Reproducibilidad(unittest.TestCase):
    def test_misma_semilla_misma_partida(self):
        a = play_game(E, "equilibrado", "equilibrado", first=0, seed=42)
        b = play_game(E, "equilibrado", "equilibrado", first=0, seed=42)
        self.assertEqual(a.state_hash(), b.state_hash())
        self.assertEqual(a.log, b.log)

    def test_repeticion_legal_y_exacta(self):
        for m, seed in ((E, 7), (R, 8)):
            g = play_game(m, "infanteria", "blindado", first=1, seed=seed)
            r = replay(m, "infanteria", "blindado", 1, seed, [x for x in g.log])
            self.assertEqual(r.state_hash(), g.state_hash())

    def test_repeticion_con_personaje(self):
        cfg = Config(build_extra=1, damage={"A:bli": 4, "T:pie": 2, "R:bli": 3})
        g = play_game(E, "equilibrado4", "rapido4", first=0, seed=5, config=cfg)
        r = replay(E, "equilibrado4", "rapido4", 0, 5, list(g.log), config=cfg)
        self.assertEqual(r.state_hash(), g.state_hash())

    def test_invariantes(self):
        g = play_game(R, "rapido", "artilleria", first=0, seed=3)
        for u in g.on_board():
            self.assertEqual(g.occ[u.pos], u.id)
            self.assertTrue(g.passable(u.pos, __import__("tw_sim.rules", fromlist=["UNIT"]).UNIT[u.t][1]))
            self.assertGreater(u.hp, 0)


if __name__ == "__main__":
    unittest.main()
