#!/usr/bin/env python3
"""Gera os 4 pedidos AX a partir da fonte real salva (valores atuais preservados)."""
import json, os, copy
HERE = os.path.dirname(os.path.abspath(__file__))
IN = os.path.join(HERE, "..", "terra_in")
ROOT = "C:\\Users\\João Pedro\\Documents\\ChatGPT\\RagRPG\\.tools\\map-editor-m5"
POP = ROOT + "\\data\\map_authoring\\sanctuary_woods.population.json"
PAT = ROOT + "\\data\\map_authoring\\sanctuary_woods.patrol.json"
SPECIES = [{"species_id": "pilot_bulwark_species", "category": "normal", "origin_id": "trial_stage_1", "weight": 1}]
HOME_SURFACE = "overpass/c_e33596bc5a5c9222_0_0_4_10"
WAYPOINTS = [
    {"point_id": "alley_north", "surface_id": HOME_SURFACE, "position_xyz": [1640, 0, 840], "wait_seconds": 2.5},
    {"point_id": "alley_south", "surface_id": HOME_SURFACE, "position_xyz": [1640, 0, 1100], "wait_seconds": 2.0},
]

def act(screen, id_, parameters):
    return {"screen": screen, "id": id_, "parameters": parameters}

def dump(name, actions):
    with open(os.path.join(HERE, name), "w", encoding="utf-8") as f:
        json.dump({"ax_version": 1, "actions": actions}, f, ensure_ascii=False, indent=2)
        f.write("\n")

src = json.load(open(os.path.join(IN, "sanctuary_woods.population.json"), encoding="utf-8"))
brush = copy.deepcopy(next(b for b in src["brushes"] if b["brush_id"] == "alley_patrol"))
brush["species"] = copy.deepcopy(SPECIES)
slot = copy.deepcopy(next(s for s in src["slots"] if s["slot_id"] == "alley_guard"))
slot.update({"fixed": True, "species_id": "pilot_bulwark_species", "category": "normal", "origin_id": "trial_stage_1"})

pre = [
    act("population", "population/document/open", {"path": POP, "confirm_discard": True}),
    act("population", "population/brush/upsert", brush),
    act("population", "population/slot/upsert", slot),
    act("population", "population/plan/preview", {}),
]
dump("population_update_preview.request.json", pre)
dump("population_update_apply.request.json", pre + [
    act("population", "population/plan/apply", {"expected_source_hash": "{{EXPECTED_SOURCE_HASH}}", "proposal_hash": "{{PROPOSAL_HASH}}", "confirm_apply": True}),
    act("population", "population/document/save", {"path": POP}),
])
dump("patrol_author.request.json", [
    act("patrol", "patrol/document/new", {"document_id": "sanctuary_woods_patrols", "name": "Bosque do Santuário — Patrulhas", "confirm_discard": True}),
    act("patrol", "patrol/population/import", {"path": POP, "confirm_discard": True}),
    act("patrol", "patrol/map/query", {}),
    act("patrol", "patrol/route/upsert", {"patrol_id": "alley_watch", "revision": 1, "mode": "ping_pong", "slot_ids": ["alley_guard"], "waypoints": WAYPOINTS}),
    act("patrol", "patrol/document/save", {"path": PAT}),
])
dump("patrol_compile_launch.request.json", [
    act("patrol", "patrol/document/open", {"path": PAT, "confirm_discard": True}),
    act("patrol", "patrol/compile", {}),
    act("patrol", "patrol/gameplay/launch", {"class_id": "swordsman", "headless": False}),
])
