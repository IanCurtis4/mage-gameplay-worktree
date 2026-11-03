"""F10 Q4 (docs/map_editor/contracts/f10_first_phase.md): the forest phase,
authored through the editor's AX session (the same commands as the GUI).

Each map runs in two AX batches: piece + map, then encounters + patrol. Between
them, encounter positions are read from the heights the editor saved, so every
marker stands on the ground the editor compiled. Run with -I from any folder:

    python -I tools/map_editor_phase/forest_phase.py <map> [<map> ...]

<map> is terraces, valleys or lair. Sources land in data/map_authoring/.
"""
import hashlib, json, math, os, random, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / ".godot/verification/e07_f1/fixture_project"
ENGINE = ROOT.parent / "godot/Godot_v4.7.2-stable_win64.exe"
DATA = ROOT / "data/map_authoring"
EVIDENCE = ROOT.parent / "f9_evidence/q4_ax"

def act(screen, id, params):
    return {"screen": screen, "id": id, "parameters": params}

def stroke(points, mode, radius, strength=1.0, hardness=1.0, target=0.0, end=None, shape="square", material="earth"):
    return act("terrain", "terrain/brush/stroke", {"points": [[round(x, 2), round(z, 2)] for x, z in points],
        "options": {"mode": mode, "radius": radius, "strength": strength, "hardness": hardness, "shape": shape,
                    "material": material, "target": target, "end_height": target if end is None else end}})

def run(name, actions, allow_last_failure=False):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%H%M%S")
    request = EVIDENCE / f"{name}_{stamp}.request.json"
    result_path = EVIDENCE / f"{name}_{stamp}.result.json"
    request.write_text(json.dumps({"ax_version": 1, "actions": actions}, ensure_ascii=False), encoding="utf-8")
    env = os.environ.copy()
    env["APPDATA"] = str(FIXTURE / ".godot/discardable_profile/Roaming")
    env["LOCALAPPDATA"] = str(FIXTURE / ".godot/discardable_profile/Local")
    env["RAGRPG_COMPILE_CACHE"] = "0"
    argv = [str(ENGINE), "--path", str(FIXTURE), "--headless", "--script", "res://scripts/map_authoring/agent/ax_session.gd",
            "--", "--ax-request=" + str(request), "--ax-result=" + str(result_path)]
    started = time.monotonic()
    proc = subprocess.run(argv, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env, timeout=3600)
    elapsed = time.monotonic() - started
    (EVIDENCE / f"{name}_{stamp}.log").write_text(proc.stdout + proc.stderr, encoding="utf-8")
    result = json.loads(result_path.read_text(encoding="utf-8")) if result_path.exists() else {}
    done = result.get("completed_actions", 0)
    print(json.dumps({"batch": name, "ok": result.get("ok", False), "completed": done, "of": len(actions), "seconds": round(elapsed, 1), "exit": proc.returncode}))
    # The failing action is reported as the last outcome; a preview that does not
    # fit is an answer, not an error, when the caller asks for it.
    if not result.get("ok", False) and allow_last_failure and done == len(actions):
        return result
    if not result.get("ok", False):
        failed = result.get("actions", [])[-1] if result.get("actions") else {}
        print(json.dumps(failed, ensure_ascii=False)[:2000])
        print((proc.stdout + proc.stderr)[-2000:])
        sys.exit(1)
    return result

# ---- Ground of a saved piece: the editor's own triangulation (a,b,c)/(a,c,d).
class Ground:
    def __init__(self, layer):
        self.ox, self.oz = layer["origin_xz"]; self.s = layer["sample_spacing"]
        self.cols, self.rows = layer["columns"], layer["rows"]; self.h = layer["heights"]; self.id = layer["layer_id"]
    def y(self, x, z):
        lx, lz = (x - self.ox) / self.s, (z - self.oz) / self.s
        i, j = min(int(lx), self.cols - 2), min(int(lz), self.rows - 2)
        u, v = lx - i, lz - j
        a = self.h[j * self.cols + i]; b = self.h[j * self.cols + i + 1]
        c = self.h[(j + 1) * self.cols + i + 1]; d = self.h[(j + 1) * self.cols + i]
        return a + (b - a) * u + (c - b) * v if u >= v else a + (c - d) * u + (d - a) * v
    def flat(self, x, z, r=80):
        ys = [self.y(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)]
        return max(ys) - min(ys) < 12
    def surface(self, instance, x, z):
        cx = int((x - self.ox) / self.s) // 16 * 16; cz = int((z - self.oz) / self.s) // 16 * 16
        return f"{instance}/g_{hashlib.sha256(self.id.encode()).hexdigest()[:16]}_{cx}_{cz}"
    def anchor(self, instance, x, z):
        return {"surface_id": self.surface(instance, x, z), "position_xyz": [x, round(self.y(x, z), 4), z]}

def spec(species, category, origin, weight=1):
    return {"species_id": species, "category": category, "origin_id": origin, "weight": weight}

def brush(ground, instance, id, x, z, radius, quantity, species, guardian=False, mode="dispersed", group=None, seed="0"):
    value = {"brush_id": id, "surface_id": ground.surface(instance, x, z), "center_xyz": [x, round(ground.y(x, z), 4), z],
             "radius": radius, "mode": mode, "quota_mode": "count", "quantity": quantity, "density": 1.0, "spacing": 24,
             "group_radius": group or min(radius, 200), "seed": seed, "round": 0, "species": species}
    if guardian: value["guardian"] = True
    return act("population", "population/brush/upsert", value)

def interaction(ground, instance, id, kind, x, z):
    a = ground.anchor(instance, x, z)
    return act("population", "population/interaction/upsert", {"interaction_id": id, "kind": kind, "surface_id": a["surface_id"], "position_xyz": a["position_xyz"], "target_id": ""})

def terrain_actions(document_id, name, layer, terrain, destination):
    actions = [act("piece", "piece/document/new", {"document_id": document_id, "name": name, "confirm_discard": True}),
               act("terrain", "terrain/grid/create", dict(layer, surface_mode="height_grid")),
               act("terrain", "terrain/layer/select", {"layer_id": layer["layer_id"]})]
    actions += terrain
    actions.append(act("piece", "piece/context/rules/set", {"biome_ids": ["forest"], "allowed_species": [], "allow_rare": False}))
    return actions + [act("piece", "piece/document/save", {"path": str(destination)})]

def scatter_params(layer_id, item, exclusions):
    definition, x, z, radius, count, spacing, seed = item
    return {"definition_id": definition, "surface_id": layer_id, "center_xz": [round(x, 1), round(z, 1)], "radius": radius,
            "count": count, "spacing": spacing, "seed_text": str(seed), "exclusions": exclusions}

def place_objects(key, layer_id, scatters, exclusions, path):
    """Scatter is preview + apply(proposal_hash) in AX: each session applies the
    previous preview by its hash, saves, and previews the next one. A preview
    that does not fit is retried with fewer objects."""
    opened = [act("piece", "piece/document/open", {"path": str(path), "confirm_discard": True}), act("terrain", "terrain/layer/select", {"layer_id": layer_id})]
    pending = None; placed = 0
    for index, item in enumerate(scatters):
        item = list(item)
        while True:
            actions = list(opened)
            if pending is not None:
                actions += [act("objects", "objects/scatter/preview", pending[0]), act("objects", "objects/scatter/apply", {"proposal_hash": pending[1]}),
                            act("piece", "piece/document/save", {"path": str(path)})]
            actions.append(act("objects", "objects/scatter/preview", scatter_params(layer_id, item, exclusions)))
            result = run(f"{key}_scatter_{index}", actions, allow_last_failure=True)
            if pending is not None: placed += pending[2]; pending = None
            last = result["actions"][-1]["result"]
            if last.get("ok"):
                pending = (scatter_params(layer_id, item, exclusions), last["proposal_hash"], item[4]); break
            if last.get("code") == "object_scatter_deficit" and item[4] > 1:
                item[4] = max(1, int(last.get("realized", item[4] - 1))); opened = [act("piece", "piece/document/open", {"path": str(path), "confirm_discard": True}), act("terrain", "terrain/layer/select", {"layer_id": layer_id})]
                continue
            print(json.dumps({"scatter_skipped": index, "result": last}, ensure_ascii=False)[:600]); break
    final = list(opened)
    if pending is not None:
        final += [act("objects", "objects/scatter/preview", pending[0]), act("objects", "objects/scatter/apply", {"proposal_hash": pending[1]})]; placed += pending[2]
    return final + [act("terrain", "terrain/compile_piece", {}), act("piece", "piece/document/save", {"path": str(path)})], placed

def buffer_polygons(points, width):
    polygons = []
    for (ax, az), (bx, bz) in zip(points, points[1:]):
        dx, dz = bx - ax, bz - az; length = math.hypot(dx, dz) or 1.0
        nx, nz = -dz / length * width, dx / length * width
        ex, ez = dx / length * width, dz / length * width
        polygons.append([[round(ax - ex + nx, 1), round(az - ez + nz, 1)], [round(bx + ex + nx, 1), round(bz + ez + nz, 1)],
                         [round(bx + ex - nx, 1), round(bz + ez - nz, 1)], [round(ax - ex - nx, 1), round(az - ez - nz, 1)]])
    return polygons

def circle_polygon(x, z, r):
    return [[round(x + r * math.cos(k * math.pi / 4), 1), round(z + r * math.sin(k * math.pi / 4), 1)] for k in range(8)]

def map_actions(document_id, name, piece_path, destination):
    return [act("map", "map/document/new", {"document_id": document_id, "name": name, "confirm_discard": True}),
            act("map", "map/piece/add", {"instance_id": "field", "position_xz": [0, 0], "rotation_quarters": 0, "path": str(piece_path)}),
            act("map", "map/context/set", {"biome_id": "forest", "instance_id": "", "rules": [], "reason": ""}),
            act("map", "map/compile_map", {}),
            act("map", "map/document/save", {"path": str(destination)})]

def scatter(rng, count, region, keep_out, spacing, existing):
    """Deterministic points in region (x0,z0,x1,z1) away from keep_out lines/points."""
    x0, z0, x1, z1 = region; result = []; tries = 0
    while len(result) < count and tries < count * 60:
        tries += 1
        x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)
        if any(keep(x, z) for keep in keep_out): continue
        if any((x - px) ** 2 + (z - pz) ** 2 < spacing ** 2 for _, px, pz in existing + result): continue
        result.append((None, x, z))
    return [(x, z) for _, x, z in result]

def near_polyline(points, distance):
    def test(x, z):
        for (ax, az), (bx, bz) in zip(points, points[1:]):
            dx, dz = bx - ax, bz - az; length = dx * dx + dz * dz
            t = 0 if length == 0 else max(0, min(1, ((x - ax) * dx + (z - az) * dz) / length))
            if (x - ax - t * dx) ** 2 + (z - az - t * dz) ** 2 < distance ** 2: return True
        return False
    return test

def near_point(px, pz, distance):
    return lambda x, z: (x - px) ** 2 + (z - pz) ** 2 < distance ** 2

# ======================= Field 1: meadow terraces with a river =======================
# Local coordinates: the layer spans -5120..5120 in x and z. North is -z.
def terraces():
    rng = random.Random(1010)
    half, edge = 5120, 4560            # rim from |x|,|z| > edge
    layer = {"layer_id": "ground", "name": "Prado em terraços", "origin_xz": [-half, -half], "columns": 161, "rows": 161, "sample_spacing": 64, "height": 0}
    t = []
    # Terraces: high (240) in the north, middle (120), low (0) in the south.
    for z in (-4100, -3100, -2100, -1700):
        t.append(stroke([(-half, z), (half, z)], "flatten", 512, target=240))
    for z in (-900, 0, 900, 1250):
        t.append(stroke([(-half, z), (half, z)], "flatten", 512, target=120))
    # Thick border: a steep slope (over 45 degrees) up to the edge of the map, so no
    # ground up there is walkable, with steep spires along its foot for an organic line.
    def level(z):
        return 240 if z < -1300 else (120 if z < 1700 else 0)
    inner = half - 220
    for k in range(-5, 5):
        x = (k + 0.5) * 1024
        t.append(stroke([(x, -inner), (x, -half)], "ramp", 512, target=240, end=512))
        t.append(stroke([(x, inner), (x, half)], "ramp", 512, target=0, end=480))
    for z0, z1 in ((-half, -1300), (-1300, 1700), (1700, half)):
        for k in range(int((z1 - z0) // 1000) + 1):
            z = min(z1 - 120, z0 + 120 + k * 1000)
            t.append(stroke([(-inner, z), (-half, z)], "ramp", 500, target=level(z), end=min(512, level(z) + 280)))
            t.append(stroke([(inner, z), (half, z)], "ramp", 500, target=level(z), end=min(512, level(z) + 280)))
    for k in range(36):
        side = k % 4; s_ = -edge + (k // 4) * (2 * edge / 9) + rng.uniform(-200, 200)
        x, z = [(s_, -edge), (s_, edge), (-edge, s_), (edge, s_)][side]
        t.append(stroke([(x, z)], "raise", rng.uniform(110, 170), strength=128, hardness=0.0, shape="circle"))
    # Ramps between terraces (road crossings).
    ramps = [(-2600, 1700, 0, 120), (2400, 1700, 0, 120), (-600, -1300, 120, 240), (3600, -1300, 120, 240)]
    for x, z, low, high in ramps:
        t.append(stroke([(x, z + 360), (x, z - 360)], "ramp", 170, target=low, end=high))
    # River across the low terrace, steep banks, two fords.
    river = [(-half, 3000)] + [(-half + i * 640, 3000 + 380 * math.sin(i * 0.9)) for i in range(1, 16)] + [(half, 3100)]
    # A shallow brook: a V this narrow, sampled along a diagonal, always leaves an
    # isolated flat strip at the bottom; terraces and ramps do the gating instead.
    t.append(stroke(river, "lower", 180, strength=40, hardness=0.3, shape="circle"))
    t.append(stroke(river, "material", 220, strength=1.0, hardness=0.4, material="sand", shape="circle"))
    # Structuring masses: rocky mesas on each terrace, away from the road.
    road = [(-4200, 4000), (-2600, 2300), (-2600, 1100), (-600, -700), (-600, -1900), (2000, -2900), (4100, -3900)]
    branch = [(-2600, 2300), (2400, 2300), (2400, 1100), (3600, -700), (3600, -1900)]
    mesas = []
    for x, z in [(-3800, -3200), (-1800, -3700), (1200, -2200), (3000, -3500), (-4000, -200), (-1600, 400), (1000, -500),
                 (2600, 900), (-3600, 2400), (200, 2500), (3200, 3900), (-1200, 4000)]:
        x += rng.uniform(-150, 150); z += rng.uniform(-150, 150)
        mesas.append((x, z))
        for dx, dz in [(0, 0), (130, 40), (-90, 110), (40, -130)]:
            t.append(stroke([(x + dx, z + dz)], "raise", 150, strength=128, hardness=0.0, shape="circle"))
            t.append(stroke([(x + dx, z + dz)], "raise", 110, strength=110, hardness=0.0, shape="circle"))
    t.append(stroke(road, "material", 120, strength=1.0, hardness=0.5, material="earth", shape="circle"))
    t.append(stroke(branch, "material", 110, strength=1.0, hardness=0.5, material="earth", shape="circle"))
    exclusions = buffer_polygons(road, 220) + buffer_polygons(branch, 200) + buffer_polygons(river, 230)         + [circle_polygon(x, z, 420) for x, z in mesas] + [circle_polygon(x, z, 480) for x, z, _, _ in ramps]
    scatters = []
    for k, (gx, gz) in enumerate([(-2600, -2900), (1600, -2600), (-1800, 700), (2600, 500), (-2600, 3300), (1600, 3300)]):
        scatters.append(("oak_tree", gx, gz, 1100, 22, 40, 100 + k))
    for k, (gx, gz) in enumerate([(-1500, -1500), (1500, 1500)]):
        scatters.append(("woodland_shrub", gx, gz, 2600, 45, 80, 200 + k))
    scatters.append(("moss_boulder", 0, 0, 3800, 16, 200, 300))
    return {"layer": layer, "terrain": t, "scatters": scatters, "exclusions": exclusions, "road": road}

def terraces_encounters(ground, instance, origin):
    a = []
    entrance = ground.anchor(instance, -4200, 4000)
    a.append(act("population", "population/entrance/set", entrance))
    wolves = [(-3000, 3600), (-500, 3400), (1800, 4000), (-3400, 400), (-200, -200), (2600, -100), (-2600, -3000), (900, -3200)]
    for k, (x, z) in enumerate(wolves):
        a.append(brush(ground, instance, f"wolves_{k}", x, z, 420, 5, [spec("forest_wolf", "normal", origin, 4), spec("forest_wolf", "elite", origin, 1)], seed=str(10 + k)))
    for k, (x, z) in enumerate([(1200, 2600), (-1800, -800), (3200, -2800)]):
        a.append(brush(ground, instance, f"boars_{k}", x, z, 360, 3, [spec("forest_boar", "normal", origin)], seed=str(30 + k)))
    for k, (x, z) in enumerate([(-1200, 1500), (1600, -1500)]):
        a.append(brush(ground, instance, f"stalkers_{k}", x, z, 380, 3, [spec("forest_stalker", "normal", origin)], seed=str(40 + k)))
    for k, (x, z) in enumerate([(-200, 1100), (2200, -2200)]):
        a.append(brush(ground, instance, f"archers_{k}", x, z, 300, 3, [spec("forest_canopy_archer", "normal", origin)], seed=str(50 + k)))
    a.append(brush(ground, instance, "guardian", 3300, -3500, 160, 1, [spec("forest_boar", "elite", origin)], guardian=True, mode="concentrated", group=120, seed="60"))
    a.append(interaction(ground, instance, "shrine", "stage_unlock", 3600, -3800))
    a.append(interaction(ground, instance, "trail_north", "early_exit", 4200, -4100))
    return a

def steep_rim(t, half, inner, level, top):
    """A border that rises over 45 degrees to the map edge: no walkable ground on it."""
    count = max(1, int(2 * half // 1024))
    for k in range(count):
        c = -half + (k + 0.5) * (2 * half / count)
        t.append(stroke([(c, -inner), (c, -half)], "ramp", min(512, half / count + 16), target=level(c, -inner), end=top))
        t.append(stroke([(c, inner), (c, half)], "ramp", min(512, half / count + 16), target=level(c, inner), end=top))
        t.append(stroke([(-inner, c), (-half, c)], "ramp", min(512, half / count + 16), target=level(-inner, c), end=top))
        t.append(stroke([(inner, c), (half, c)], "ramp", min(512, half / count + 16), target=level(inner, c), end=top))

def ridges(t, x0, z0, x1, z1, spacing=384, radius=192, origin=-5120, step=64):
    """A massif of parallel steep ridges with sharp valleys. Ridge lines and the
    valley bottoms between them sit on sample rows, so both slopes stay steep
    (no flat strip at the bottom)."""
    z = origin + math.ceil((z0 + radius - origin) / step) * step
    while z <= z1 - radius + 1:
        line = [(x0 + radius, z), (x1 - radius, z)]
        t.append(stroke(line, "raise", radius, strength=128, hardness=0.0, shape="circle"))
        t.append(stroke(line, "raise", radius, strength=128, hardness=0.0, shape="circle"))
        z += spacing

# ======================= Field 2: tree of valleys between walls =======================
def valleys():
    rng = random.Random(2020)
    half, inner = 5120, 4900
    layer = {"layer_id": "ground", "name": "Vales em árvore", "origin_xz": [-half, -half], "columns": 161, "rows": 161, "sample_spacing": 64, "height": 0}
    t = []
    # Massifs between the corridors: the trunk x in [-260, 260]; branches west at
    # z = 2500 and -1500, east at z = 1000 and -3200 (corridors 400 wide).
    for block in [(-inner, 2700, -260, inner), (-inner, -1300, -260, 2300), (-inner, -inner, -260, -1700),
                  (260, 1200, inner, inner), (260, -3000, inner, 800), (260, -inner, inner, -3400)]:
        ridges(t, *block)
    # Twigs: dead-end side valleys across each massif, one per 1024 u column, so
    # every 1024 u stretch has floor the player's body reaches (game preparation).
    for x in (-4500, -3584, -2560, -1536):
        for z0, z1 in ((2500, 4700), (-1500, 2500), (-1500, -4700)):
            t.append(stroke([(x, z0), (x, z1)], "flatten", 180, target=0, hardness=1.0))
    for x in (1536, 2560, 3584, 4500):
        for z0, z1 in ((1000, 4700), (-3200, 1000), (-3200, -4700)):
            t.append(stroke([(x, z0), (x, z1)], "flatten", 180, target=0, hardness=1.0))
    steep_rim(t, half, inner, lambda x, z: 0, 480)
    clearings = [(0, 3700, 600), (0, 2500, 520), (-2600, 2500, 560), (-4100, 2500, 480), (0, 1000, 520), (2600, 1000, 600),
                 (0, -1500, 520), (-2400, -1500, 620), (0, -3200, 500), (2800, -3200, 560), (4000, -3200, 520), (0, -4300, 480)]
    for x, z, r in clearings:
        # An abrupt edge: a partial blend into the ridges would leave isolated shelves.
        t.append(stroke([(x, z)], "flatten", min(512, r), target=0, hardness=1.0, shape="circle"))
    for x, z, r in clearings:
        t.append(stroke([(x + rng.uniform(-120, 120), z + rng.uniform(-120, 120))], "rounded_hill", 160, strength=30, hardness=0.3, shape="circle"))
    trunk = [(0, 4600), (0, -4500)]
    branches = [[(0, 2500), (-4300, 2500)], [(0, -1500), (-4300, -1500)], [(0, 1000), (4300, 1000)], [(0, -3200), (4300, -3200)]]
    t.append(stroke(trunk, "material", 140, strength=1.0, hardness=0.5, material="earth", shape="circle"))
    for line in branches:
        t.append(stroke(line, "material", 120, strength=1.0, hardness=0.5, material="earth", shape="circle"))
    for x0, z0, x1, z1 in [(-inner, 2700, -260, inner), (-inner, -1300, -260, 2300), (260, -3000, inner, 800)]:
        t.append(stroke([(x0 + 400, (z0 + z1) / 2), (x1 - 400, (z0 + z1) / 2)], "material", 512, strength=0.7, hardness=0.2, material="stone", shape="square"))
    exclusions = buffer_polygons(trunk, 180) + [p for line in branches for p in buffer_polygons(line, 170)]
    scatters = []
    for k, (x, z, r) in enumerate(clearings):
        if k in (1, 4, 6, 8): continue
        scatters.append(("oak_tree", x, z, r + 150, 6, 30, 400 + k))
    scatters.append(("woodland_shrub", 0, 0, 4600, 40, 80, 500))
    scatters.append(("moss_boulder", 0, 0, 4600, 14, 200, 501))
    return {"layer": layer, "terrain": t, "scatters": scatters, "exclusions": exclusions}

def valleys_encounters(ground, instance, origin):
    a = [act("population", "population/entrance/set", ground.anchor(instance, 0, 4500))]
    wolves = [(0, 3700), (-2600, 2500), (2600, 1000), (-2400, -1500), (0, -1500), (2800, -3200), (-4000, 2500), (0, 1000)]
    for k, (x, z) in enumerate(wolves):
        a.append(brush(ground, instance, f"wolves_{k}", x, z, 420, 5, [spec("forest_wolf", "normal", origin, 4), spec("forest_wolf", "elite", origin, 1)], seed=str(70 + k)))
    for k, (x, z) in enumerate([(-1600, 2500), (1800, -3200)]):
        a.append(brush(ground, instance, f"boars_{k}", x, z, 300, 3, [spec("forest_boar", "normal", origin)], seed=str(80 + k)))
    for k, (x, z) in enumerate([(1500, 1000), (-1500, -1500)]):
        a.append(brush(ground, instance, f"stalkers_{k}", x, z, 300, 3, [spec("forest_stalker", "normal", origin)], seed=str(85 + k)))
    for k, (x, z) in enumerate([(0, -3200), (0, 2500)]):
        a.append(brush(ground, instance, f"archers_{k}", x, z, 360, 3, [spec("forest_canopy_archer", "normal", origin)], seed=str(90 + k)))
    a.append(brush(ground, instance, "guardian", 4000, -3100, 160, 1, [spec("forest_stalker", "elite", origin)], guardian=True, mode="concentrated", group=120, seed="95"))
    a.append(interaction(ground, instance, "shrine", "stage_unlock", 4200, -3300))
    a.append(interaction(ground, instance, "trail_north", "early_exit", 0, -4450))
    return a

# ======================= Boss lair: a ringed clearing =======================
def lair():
    rng = random.Random(3030)
    half, inner = 1536, 1340
    layer = {"layer_id": "ground", "name": "Covil do Guardião", "origin_xz": [-half, -half], "columns": 49, "rows": 49, "sample_spacing": 64, "height": 0}
    t = []
    steep_rim(t, half, inner, lambda x, z: 0, 420)
    for k in range(16):
        if k in (4, 12): continue   # the south gate (entrance) and the north gate (exit)
        angle = k / 16 * math.tau
        t.append(stroke([(math.cos(angle) * 1150, math.sin(angle) * 1150)], "raise", 140, strength=128, hardness=0.0, shape="circle"))
    t.append(stroke([(0, 0)], "rounded_hill", 420, strength=24, hardness=0.6, shape="circle"))
    t.append(stroke([(0, 1200), (0, 0), (0, -1150)], "material", 110, strength=1.0, hardness=0.5, material="earth", shape="circle"))
    t.append(stroke([(0, 0)], "material", 380, strength=0.8, hardness=0.3, material="stone", shape="circle"))
    exclusions = [circle_polygon(0, 0, 520)] + buffer_polygons([(0, 1300), (0, -1300)], 160)
    scatters = [("oak_tree", -800, 300, 420, 6, 40, 600), ("oak_tree", 800, -300, 420, 6, 40, 601), ("woodland_shrub", 0, 0, 1200, 14, 60, 602)]
    # A boss needs a thematic context area that allows it.
    context = [act("piece", "piece/context/rules/set", {"biome_ids": ["forest"], "allowed_species": [], "allow_rare": True}),
               act("piece", "piece/context/area/upsert", {"region_id": "warden_ground", "layer_id": "ground", "min_xz": [-520, -620], "max_xz": [520, 420], "allowed_species": [], "allow_rare": True, "reserved": []})]
    return {"layer": layer, "terrain": t, "scatters": scatters, "exclusions": exclusions, "context": context}

def lair_encounters(ground, instance, origin):
    a = [act("population", "population/entrance/set", ground.anchor(instance, 0, 1050))]
    a.append(brush(ground, instance, "warden", 0, -150, 260, 1, [spec("forest_ancient_warden", "boss", origin)], guardian=True, mode="concentrated", group=180, seed="97"))
    a.append(brush(ground, instance, "pack", 0, 250, 300, 4, [spec("forest_wolf", "normal", origin)], seed="98"))
    a.append(interaction(ground, instance, "warden_exit", "phase_completion", 0, -1100))
    return a

PLANS = {"terraces": {"title": "Prado dos Terraços", "build": terraces, "encounters": terraces_encounters, "origin": "trial_stage_1"},
         "valleys": {"title": "Vales da Mata", "build": valleys, "encounters": valleys_encounters, "origin": "trial_stage_2"},
         "lair": {"title": "Covil do Guardião", "build": lair, "encounters": lair_encounters, "origin": "trial_stage_3"}}

def author(key):
    plan = PLANS[key]; built = plan["build"]()
    base = f"forest_{key}"
    piece_path = DATA / f"{base}.source.json"; map_path = DATA / f"{base}.map.json"
    population_path = DATA / f"{base}.population.json"; patrol_path = DATA / f"{base}.patrol.json"
    if os.environ.get("FOREST_FROM") == "patrol" and population_path.exists():
        if patrol_path.exists(): patrol_path.unlink()
        run(f"{key}_patrol", [act("patrol", "patrol/document/new", {"document_id": base + "_patrol", "name": plan["title"], "confirm_discard": True}),
            act("patrol", "patrol/population/import", {"path": str(population_path), "confirm_discard": True}),
            act("patrol", "patrol/compile", {}), act("patrol", "patrol/document/save", {"path": str(patrol_path)})])
        return
    keep_terrain = os.environ.get("FOREST_KEEP_TERRAIN") == "1" and piece_path.exists()
    for path in ((map_path, population_path, patrol_path) if keep_terrain else (piece_path, map_path, population_path, patrol_path)):
        if path.exists(): path.unlink()
    if not keep_terrain: run(f"{key}_terrain", terrain_actions(base, plan["title"], built["layer"], built["terrain"], piece_path))
    ground = Ground(json.loads(piece_path.read_text(encoding="utf-8"))["layers"][0])
    saved = json.loads(piece_path.read_text(encoding="utf-8"))
    if os.environ.get("FOREST_KEEP_OBJECTS") == "1" and saved["placements"]:
        final, placed = [act("piece", "piece/document/open", {"path": str(piece_path), "confirm_discard": True}), act("terrain", "terrain/compile_piece", {}), act("piece", "piece/document/save", {"path": str(piece_path)})], len(saved["placements"])
    else:
        final, placed = place_objects(key, built["layer"]["layer_id"], built["scatters"], built["exclusions"], piece_path)
    # Piece context (e.g. a boss ground) goes in before the piece is compiled and saved.
    final = final[:-2] + built.get("context", []) + final[-2:]
    run(f"{key}_objects", final + map_actions(base + "_map", plan["title"], piece_path, map_path))
    ground = Ground(json.loads(piece_path.read_text(encoding="utf-8"))["layers"][0])
    encounters = [act("population", "population/document/new", {"document_id": base + "_population", "name": plan["title"], "confirm_discard": True}),
                  act("population", "population/map/import", {"path": str(map_path)})]
    encounters += plan["encounters"](ground, "field", plan["origin"])
    run(f"{key}_encounters", encounters + [act("population", "population/document/save", {"path": str(population_path)})])
    applied = [act("population", "population/document/open", {"path": str(population_path), "confirm_discard": True}),
               act("population", "population/plan/preview", {})]
    probe = run(f"{key}_preview", applied)["actions"][-1]["result"]
    finish = applied + [act("population", "population/plan/apply", {"expected_source_hash": probe["base_hash"], "proposal_hash": probe["proposal_hash"], "confirm_apply": True}),
              act("population", "population/compile", {}),
              act("population", "population/document/save", {"path": str(population_path)}),
              act("patrol", "patrol/document/new", {"document_id": base + "_patrol", "name": plan["title"], "confirm_discard": True}),
              act("patrol", "patrol/population/import", {"path": str(population_path), "confirm_discard": True}),
              act("patrol", "patrol/compile", {}),
              act("patrol", "patrol/document/save", {"path": str(patrol_path)})]
    run(f"{key}_apply", finish)
    print(json.dumps({"map": key, "objects": placed, "strokes": len(built["terrain"])}))

if __name__ == "__main__":
    for key in sys.argv[1:]: author(key)
