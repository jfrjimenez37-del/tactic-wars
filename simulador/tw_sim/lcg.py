"""Generador de numeros aleatorios minimo, identico en Python y en Godot (core/tw_rng.gd).

Solo se usa para comprobar que la IA del prototipo elige exactamente las mismas jugadas que los bots
del simulador; los experimentos siguen usando random.Random.
"""


class LCG:
    def __init__(self, seed):
        self.state = seed & 0xFFFFFFFF

    def random(self):
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.state / 4294967296.0

    def uniform(self, a, b):
        return a + (b - a) * self.random()
