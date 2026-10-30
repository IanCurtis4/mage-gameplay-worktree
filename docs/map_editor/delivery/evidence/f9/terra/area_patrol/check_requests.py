#!/usr/bin/env python3
"""Valida os 4 pedidos AX de Terra contra as entradas reais (mapa, props, fonte de encontros)."""
import json, math, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(HERE, "..", "terra_in")
ok_all = True
def check(cond, msg):
    global ok_all
    print(("PASS  " if cond else "FAIL  ") + msg)
    if not cond: ok_all = False
def load(p): return json.load(open(p, encoding="utf-8"))

POP_PATH = "C:\\Users\\João Pedro\\Documents\\ChatGPT\\RagRPG\\.tools\\map-editor-m5\\data\\map_authoring\\sanctuary_woods.population.json"
PAT_PATH = POP_PATH.replace("population.json", "patrol.json")
ID = re.compile(r"^[a-z][a-z0-9_]*$")
def t_id(v): return isinstance(v, str) and bool(ID.match(v))
def t_num(v): return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)
def t_int(v): return isinstance(v, int) and not isinstance(v, bool)
def t_v3(v): return isinstance(v, list) and len(v) == 3 and all(t_num(x) for x in v)
TYPES = {"id": t_id, "string": lambda v: isinstance(v, str), "v3": t_v3, "number": t_num, "int": t_int,
         "bool": lambda v: isinstance(v, bool), "array": lambda v: isinstance(v, list),
         "strings": lambda v: isinstance(v, list) and all(isinstance(x, str) for x in v)}
BRUSH = {"brush_id":"id","surface_id":"string","center_xyz":"v3","radius":"number","mode":"id","quota_mode":"id","quantity":"number","density":"number","spacing":"number","group_radius":"number","seed":"string","round":"number","species":"array"}
SPEC = {"species_id":"id","category":"id","origin_id":"id","weight":"int"}
SLOT = {"slot_id":"id","brush_id":"id","surface_id":"string","position_xyz":"v3","species_id":"id","category":"id","origin_id":"id","fixed":"bool","site_id":"string"}
ROUTE = {"patrol_id":"id","revision":"int","mode":"id","slot_ids":"strings","waypoints":"array"}
WAYPOINT = {"point_id":"id","surface_id":"string","position_xyz":"v3","wait_seconds":"number"}
def shape(d, spec, label):
    good = isinstance(d, dict) and set(d) == set(spec) and all(TYPES[spec[k]](d[k]) for k in spec)
    check(good, f"{label}: {len(spec)} campos exatos e tipos corretos")
    return good

reqs = {n: load(os.path.join(HERE, n)) for n in ["population_update_preview.request.json","population_update_apply.request.json","patrol_author.request.json","patrol_compile_launch.request.json"]}
for n, r in reqs.items():
    check(r.get("ax_version") == 1 and set(r) == {"ax_version","actions"}, f"{n}: JSON válido, ax_version 1")
    check(all(set(a) == {"screen","id","parameters"} and isinstance(a["parameters"], dict) for a in r["actions"]), f"{n}: ações com screen/id/parameters")
    paths = [v for a in r["actions"] for k, v in a["parameters"].items() if k == "path"]
    check(all(p.startswith("C:\\Users\\João Pedro\\Documents\\ChatGPT\\RagRPG\\.tools\\map-editor-m5\\data\\map_authoring\\") and "/" not in p for p in paths), f"{n}: caminhos Windows absolutos com barra invertida")

src = load(os.path.join(IN, "sanctuary_woods.population.json"))
q = load(os.path.join(IN, "map_query.json"))
props = load(os.path.join(IN, "props_world.json"))
surf = {s["surface_id"]: s["vertices_xyz"] for s in q["surfaces"]}

# ---------- Pedido 1 / 2
pv = reqs["population_update_preview.request.json"]["actions"]
ap = reqs["population_update_apply.request.json"]["actions"]
check([a["id"] for a in pv] == ["population/document/open","population/brush/upsert","population/slot/upsert","population/plan/preview"], "preview: sequência open, brush, slot, preview")
check(pv[0]["parameters"] == {"path": POP_PATH, "confirm_discard": True}, "preview: open na fonte real com confirm_discard")
brush = pv[1]["parameters"]; slot = pv[2]["parameters"]
shape(brush, BRUSH, "brush alley_patrol"); shape(slot, SLOT, "slot alley_guard")
for sp in brush["species"]: shape(sp, SPEC, "SPEC do brush")
cur_b = next(b for b in src["brushes"] if b["brush_id"] == "alley_patrol")
cur_s = next(s for s in src["slots"] if s["slot_id"] == "alley_guard")
check({k: v for k, v in brush.items() if k != "species"} == {k: v for k, v in cur_b.items() if k != "species"}, "brush: 12 campos não-species idênticos aos atuais")
check(brush["species"] == [{"species_id":"pilot_bulwark_species","category":"normal","origin_id":"trial_stage_1","weight":1}], "brush: species = bulwark/normal/trial_stage_1/1")
check({k: v for k, v in slot.items() if k not in ("species_id","category","origin_id")} == {k: v for k, v in cur_s.items() if k not in ("species_id","category","origin_id")} and slot["fixed"] is True, "slot: id/brush/surface/posição/site/fixed idênticos aos atuais (fixed true)")
check((slot["species_id"], slot["category"], slot["origin_id"]) == ("pilot_bulwark_species","normal","trial_stage_1"), "slot: espécie bulwark/normal/trial_stage_1")
check(slot["surface_id"] in surf, "slot: surface_id existe em map_query")
check(ap[:4] == pv, "apply: 4 primeiras ações idênticas ao preview")
check([a["id"] for a in ap[4:]] == ["population/plan/apply","population/document/save"], "apply: termina com plan/apply e document/save")
check(ap[4]["parameters"] == {"expected_source_hash":"{{EXPECTED_SOURCE_HASH}}","proposal_hash":"{{PROPOSAL_HASH}}","confirm_apply":True}, "apply: placeholders literais e confirm_apply true")
check(ap[5]["parameters"] == {"path": POP_PATH}, "apply: save no mesmo caminho da fonte")

# ---------- Pedido 3
pa = reqs["patrol_author.request.json"]["actions"]
check(all(a["screen"] == "patrol" for a in pa), "patrol_author: screen patrol")
check([a["id"] for a in pa] == ["patrol/document/new","patrol/population/import","patrol/map/query","patrol/route/upsert","patrol/document/save"], "patrol_author: sequência new, import, query, route/upsert, save")
check(pa[0]["parameters"] == {"document_id":"sanctuary_woods_patrols","name":"Bosque do Santuário — Patrulhas","confirm_discard":True}, "patrol_author: document/new")
check(pa[1]["parameters"] == {"path": POP_PATH, "confirm_discard": True}, "patrol_author: import da fonte de população")
check(pa[2]["parameters"] == {}, "patrol_author: map/query {}")
check(pa[4]["parameters"] == {"path": PAT_PATH}, "patrol_author: save em sanctuary_woods.patrol.json")
route = pa[3]["parameters"]
shape(route, ROUTE, "ROUTE alley_watch")
check(route["patrol_id"] == "alley_watch" and route["revision"] == 1 and route["mode"] == "ping_pong" and route["slot_ids"] == ["alley_guard"], "ROUTE: id, revision 1, ping_pong, slot alley_guard")
wps = route["waypoints"]
check(2 <= len(wps) <= 4, f"ROUTE: {len(wps)} waypoints (2 a 4)")
check(len({w['point_id'] for w in wps}) == len(wps), "ROUTE: point_id únicos")
for w in wps:
    shape(w, WAYPOINT, f"WAYPOINT {w['point_id']}")
    check(0 <= w["wait_seconds"] <= 300 and 1.5 <= w["wait_seconds"] <= 3, f"{w['point_id']}: espera {w['wait_seconds']} s (1,5-3)")

# ---------- Pedido 4
pc = reqs["patrol_compile_launch.request.json"]["actions"]
check([a["id"] for a in pc] == ["patrol/document/open","patrol/compile","patrol/gameplay/launch"], "compile_launch: sequência open, compile, launch")
check(pc[0]["parameters"] == {"path": PAT_PATH, "confirm_discard": True} and pc[1]["parameters"] == {} and pc[2]["parameters"] == {"class_id":"swordsman","headless":False}, "compile_launch: parâmetros")

# ---------- Geometria
def pip(x, z, poly):
    inside = False; n = len(poly)
    for i in range(n):
        x1, z1 = poly[i][0], poly[i][2]; x2, z2 = poly[(i+1) % n][0], poly[(i+1) % n][2]
        if (z1 > z) != (z2 > z) and x < (x2-x1)*(z-z1)/(z2-z1)+x1: inside = not inside
    return inside
def dseg(p, a, b):
    ax, az = a; bx, bz = b; px, pz = p
    dx, dz = bx-ax, bz-az; L = dx*dx+dz*dz
    t = 0 if L == 0 else max(0, min(1, ((px-ax)*dx+(pz-az)*dz)/L))
    return math.hypot(px-(ax+t*dx), pz-(az+t*dz))
def edge_dist(p, poly): return min(dseg(p, (poly[i][0], poly[i][2]), (poly[(i+1) % len(poly)][0], poly[(i+1) % len(poly)][2])) for i in range(len(poly)))
def plane_y(x, z, poly):
    for i in range(1, len(poly)-1):
        a, b, c = poly[0], poly[i], poly[i+1]
        den = (b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
        if den == 0: continue
        l1 = ((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
        l2 = ((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den; l3 = 1-l1-l2
        if min(l1, l2, l3) >= -1e-9: return l1*a[1]+l2*b[1]+l3*c[1]
    return None
home = cur_s["position_xyz"]; H = (home[0], home[2]); LEASH = 850
solids = [(p["placement_id"], p["definition_id"], (p["world_xyz"][0], p["world_xyz"][2])) for p in props if p["definition_id"] in ("oak_tree","moss_boulder","broken_pillar")]
slots3 = [(s["slot_id"][:13], (s["position_xyz"][0], s["position_xyz"][2])) for s in src["slots"] if s["brush_id"] == "west_group"]
check(len(slots3) == 3 and len(solids) > 0, f"entradas: {len(solids)} props sólidos, {len(slots3)} slots west_group")
pts = [("home", H, home[1])] + [(w["point_id"], (w["position_xyz"][0], w["position_xyz"][2]), w["position_xyz"][1]) for w in wps]
home_poly = surf[cur_s["surface_id"]]
print("\n--- Tabela de folgas (centro do ponto; mínimo sobre o trecho em parênteses) ---")
segs = [(pts[i][1], pts[i+1][1]) for i in range(len(pts)-1)] + [(pts[0][1], p[1]) for p in pts[1:]]
SEAM = (1280, 512, 1792, 768)  # faixa da emenda/corredor sob a ponte: x 1280-1792, z 512-768 (z 640 +/- 128)
def rect_dist(p, r):
    dx = max(r[0]-p[0], 0, p[0]-r[2]); dz = max(r[1]-p[1], 0, p[1]-r[3]); return math.hypot(dx, dz)
def samples(a, b, n=200): return [(a[0]+(b[0]-a[0])*i/n, a[1]+(b[1]-a[1])*i/n) for i in range(n+1)]
for name, p, y in pts[1:]:
    s = next(w for w in wps if w["point_id"] == name)
    poly = surf.get(s["surface_id"])
    check(poly is not None, f"{name}: surface_id existe em map_query")
    check(s["surface_id"] == cur_s["surface_id"], f"{name}: mesmo apoio do home")
    check(pip(p[0], p[1], poly), f"{name}: dentro do polígono (XZ)")
    py = plane_y(p[0], p[1], poly)
    check(py is not None and abs(py-y) < 0.01, f"{name}: Y={y} coerente com o apoio (Y apoio={py})")
    ed = edge_dist(p, poly); check(ed >= 40, f"{name}: borda do apoio {ed:.1f} >= 40")
    dl = math.dist(p, H); check(dl <= LEASH, f"{name}: leash {dl:.1f} <= {LEASH}")
    mp = min((math.dist(p, c), i) for i, _, c in solids); ms = min((math.dist(p, c), i) for i, c in slots3)
    check(mp[0] >= 64, f"{name}: prop sólido mais próximo {mp[0]:.1f} ({mp[1]}) >= 64")
    check(ms[0] >= 48, f"{name}: slot west_group mais próximo {ms[0]:.1f} ({ms[1]}) >= 48")
    check(rect_dist(p, SEAM) >= 64, f"{name}: faixa da emenda/corredor (z 512-768) {rect_dist(p, SEAM):.1f} >= 64")
    print(f"      tabela {name}: pos={p} borda={ed:.1f} leash={dl:.1f} prop_min={mp[0]:.1f}[{mp[1]}] slot_min={ms[0]:.1f}[{ms[1]}] faixa={rect_dist(p, SEAM):.1f}")
# trechos
worst_prop = (1e9, None); worst_slot = (1e9, None); worst_edge = 1e9; worst_leash = 0; worst_seam = 1e9; inside = True
for a, b in segs:
    for i, _, c in [(i, 0, c) for i, _, c in solids]:
        d = dseg(c, a, b)
        if d < worst_prop[0]: worst_prop = (d, i)
    for i, c in slots3:
        d = dseg(c, a, b)
        if d < worst_slot[0]: worst_slot = (d, i)
    for s in samples(a, b):
        inside &= pip(s[0], s[1], home_poly); worst_edge = min(worst_edge, edge_dist(s, home_poly))
        worst_leash = max(worst_leash, math.dist(s, H)); worst_seam = min(worst_seam, rect_dist(s, SEAM))
check(inside, "trechos (home<->pontos e entre pontos): todas as amostras dentro do mesmo apoio convexo, logo transitáveis sem sair do leash")
check(worst_prop[0] >= 64, f"trechos: menor distância a prop sólido {worst_prop[0]:.1f} ({worst_prop[1]}) >= 64")
check(worst_slot[0] >= 48, f"trechos: menor distância a slot west_group {worst_slot[0]:.1f} ({worst_slot[1]}) >= 48")
check(worst_edge >= 40, f"trechos: menor distância à borda {worst_edge:.1f} >= 40")
check(worst_leash <= LEASH, f"trechos: maior distância ao home {worst_leash:.1f} <= {LEASH}")
check(worst_seam >= 64, f"trechos: menor distância à faixa da emenda {worst_seam:.1f} >= 64")
ext = sum(math.dist(wps[i]["position_xyz"][::2], wps[i+1]["position_xyz"][::2]) for i in range(len(wps)-1))
check(250 <= ext <= 400, f"extensão entre waypoints {ext:.0f} (250-400)")
print("\nRESULTADO:", "PASS" if ok_all else "FAIL")
sys.exit(0 if ok_all else 1)
