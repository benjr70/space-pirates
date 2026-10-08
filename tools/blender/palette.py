"""The weapon palette: worn, baked PBR finishes."""
import kit


def metal():
    """Dark parkerised steel, rubbed bright on its edges."""
    return kit.surface("Steel", (0.050, 0.052, 0.058), rough=0.45, metallic=1.0,
                       wear=(0.56, 0.56, 0.58), wear_rough=0.26, grain=0.25)


def bare():
    """Bare machined steel: barrels, bolts, pins."""
    return kit.surface("BareSteel", (0.30, 0.30, 0.32), rough=0.32, metallic=1.0,
                       wear=(0.62, 0.62, 0.64), wear_rough=0.2, grain=0.15)


def dark():
    """Matte black polymer, scuffing to grey."""
    return kit.surface("Polymer", (0.020, 0.020, 0.022), rough=0.62,
                       wear=(0.10, 0.10, 0.105), wear_rough=0.75, wear_amount=0.7, grain=0.9, grain_scale=900.0)


def wood():
    """Oiled walnut."""
    return kit.surface("Walnut", (0.17, 0.075, 0.028), rough=0.5,
                       wear=(0.30, 0.17, 0.08), wear_rough=0.65, wear_amount=0.6, grain=0.5, grain_scale=300.0, streak=0.8)


def brass():
    """Aged brass."""
    return kit.surface("Brass", (0.42, 0.27, 0.085), rough=0.42, metallic=1.0,
                       wear=(0.85, 0.66, 0.30), wear_rough=0.22, grain=0.15)


def glow():
    return kit.surface("Glow", (0.10, 0.75, 1.0), rough=0.3, wear_amount=0.0, grain=0.0, emission=3.0)


def hull():
    """Red plastic shotgun shell."""
    return kit.surface("Hull", (0.36, 0.022, 0.018), rough=0.4,
                       wear=(0.55, 0.12, 0.10), wear_rough=0.6, wear_amount=0.5, grain=0.2)
