#!/usr/bin/env python3
"""Generate the original two-colour E06 skill icon set from the live skill catalog."""
from __future__ import annotations
import argparse, hashlib, json, math, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLASS_SOURCE = ROOT / "scripts/data/class_catalog.gd"
SENTINEL_SOURCE = ROOT / "scripts/data/sentinel_tuning.gd"
HUNTER_SOURCE = ROOT / "scripts/data/hunter_tuning.gd"
OUT = ROOT / "assets/art/skills"
PALETTES = {
    "swordsman": {"background": "#263a47", "silhouette": "#f1c879"},
    "mage": {"background": "#302b58", "silhouette": "#87d8ed"},
    "archer": {"background": "#25483d", "silhouette": "#f1d17b"},
    "defender": {"background": "#344958", "silhouette": "#e8c27a"},
    "berserker": {"background": "#552e3b", "silhouette": "#f0a66e"},
    "elementalist": {"background": "#303d67", "silhouette": "#a7e1e4"},
    "spiritualist": {"background": "#382e57", "silhouette": "#d8b6ef"},
    "geometer": {"background": "#35434d", "silhouette": "#8fe0c5"},
    "sentinel": {"background": "#234b59", "silhouette": "#f0cf7f"},
    "hunter": {"background": "#34513a", "silhouette": "#f3d17a"},
    # E09 hybrids: two colours per class, from the "Visual" of each sheet in HYBRIDS_56_V3.
    "paladin": {"background": "#2b4a78", "silhouette": "#f4e3a8"},        # sky blue + silver-gold
    "thaumaturge": {"background": "#2a3a8c", "silhouette": "#fff0c2"},    # blue + white-gold
    "duelist": {"background": "#2b1318", "silhouette": "#d8dde4"},        # dark red/black + silver
    "arcane_blade": {"background": "#24272d", "silhouette": "#8fcfff"},   # lead grey/black + crystal blue
    # E10a Acolyte family (docs/epics/e10a_contract.md section 6). The base splits its tile in two halves with the
    # colours swapped: left half plum + gold, right half gold + plum ("light and shadow, side not chosen yet").
    "acolyte": {"background": "#3d2a52", "silhouette": "#f0cf7f"},                         # plum (shadow) + gold (light)
    "priest": {"background": "#315f95", "silhouette": "#f6efd9", "accent": "#e8cf85"},      # sky blue + ivory + pale gold
    "cultist": {"background": "#0c1426", "silhouette": "#e64fc3", "accent": "#35d6c6"},     # blue-black + magenta + turquoise
}

# Semantic glyphs are intentionally drawn from primitives, not copied from existing art.
# Each entry changes the central silhouette and usually its negative-space counterform.
SPECIAL = {
    "slash": "cleave", "dash": "comet", "shield_wall": "shieldwall", "provoke": "horn",
    "perseverance": "pillar", "piercing_shout": "soundwave", "fury": "flameblade",
    "brutal_strike": "hammerfall", "concentrated_rage": "crossedblades", "terrifying_shout": "roar",
    "swordsman_resistance": "ward", "vigor": "heartbeat", "blood_thirst": "fang",
    "fireball": "fireorb", "fire_wall": "flamewall", "fire_spear": "firespear", "ice_spear": "icespear",
    "lightning": "forkedbolt", "electric_discharge": "arcburst", "lightning_wall": "stormwall",
    "soul_impact": "soulburst", "haunt": "wisp", "phantom_barrier": "veilshield", "ice_wall": "icewall",
    "teleport": "foldgate", "mage_mana_regeneration": "manaorbit",
    "double_shot": "twinarrow", "piercing_arrow": "lancearrow", "arrow_rain": "arrowfall",
    "extended_aim": "sightline", "snare_trap": "snare", "explosive_trap": "bursttrap",
    "slowing_arrow": "frostarrow", "foliage_shelter": "leafward", "archer_precision": "bullseye",
    "archer_cadence": "featherbeat", "trap_technique": "traploop",
    "defender_counterstroke": "countercut", "defender_watch": "watchtower", "defender_anchor": "anchor",
    "defender_line_lock": "lockline", "defender_guard_return": "returnguard", "defender_wall_advance": "advancingwall",
    "defender_reprisal_wave": "reprisalwave", "berserker_rupture": "rupture", "berserker_obstinacy": "ironroot",
    "berserker_wound_leap": "woundleap", "berserker_execution": "execution", "berserker_pursuit": "pursuit",
    "berserker_blood_rift": "bloodrift", "berserker_breath_steal": "breathsteal",
    "elementalist_flame_burst": "flameburst", "elementalist_prismatic_focus": "prismfocus",
    "elementalist_glacial_ring": "glacialring", "elementalist_lightning_arc": "lightningarc",
    "elementalist_prismatic_resonance": "resonance", "elementalist_ember_path": "emberpath",
    "elementalist_tri_nova": "trinova", "spiritualist_echo_curse": "echocurse",
    "spiritualist_echo_recovery": "echorecovery", "spiritualist_soul_drain": "souldrain",
    "spiritualist_spectral_veil": "spectralveil", "spiritualist_channel_focus": "channelbeads",
    "spiritualist_procession": "procession", "spiritualist_dissipation": "dissipation",
    "geometer_trace": "trace", "geometer_triangulation": "triangle", "geometer_incidence": "incidence",
    "geometer_translation": "translation", "geometer_vector_memory": "vectormemory",
    "geometer_collapse": "collapse", "geometer_rewrite": "rewrite",
    "sentinel_headshot": "headshot", "sentinel_observe": "observe", "sentinel_precision_stance": "precisionstance",
    "sentinel_piercing_shot": "piercingshot", "sentinel_net_shot": "netshot", "sentinel_explosive_shot": "explosiveshot",
    "sentinel_opening_read": "openingread", "sentinel_concussion_shot": "concussion", "sentinel_absolute_focus": "absolutefocus",
    "hunter_freezing_trap": "freezingtrap", "hunter_tar_trap": "tartrap", "hunter_thorn_trap": "thorntrap",
    "hunter_mark": "huntermark", "hunter_shooting_discipline": "discipline", "hunter_covering_shot": "covershot",
    "hunter_easy_prey": "easyprey", "hunter_total_cover": "totalcover",
}

# Composable, 64px high-contrast glyphs; all use only the selected silhouette colour.
SHAPES = {
    "cleave": '<path d="M14 43 39 16l11 4-24 27-8 4z"/><path d="m15 47-3 6 6-3"/>',
    "comet": '<path d="M39 13 51 25 30 46 19 35z"/><path d="m19 35-8 15 15-8"/>',
    "shieldwall": '<path d="M32 12 49 18v13c0 11-7 18-17 23-10-5-17-12-17-23V18z"/><path d="M32 20v25"/>',
    "horn": '<path d="M15 43Q29 38 27 19l10-5q-1 15 12 21l-3 9q-13-8-22 5z"/>',
    "pillar": '<path d="M21 13h22v6l-5 5v15l5 6v6H21v-6l5-6V24l-5-5z"/><path d="M26 31h12"/>',
    "soundwave": '<path d="M14 29h10l9-10v26l-9-10H14z"/><path d="M39 25q9 7 0 14m5-20q15 13 0 26" fill="none" stroke="currentColor"/>',
    "flameblade": '<path d="M32 10q12 13 3 19 10-3 11-10 12 20-3 31-11 8-23-1-11-12 1-25 0 11 8 12-4-12 3-26z"/>',
    "hammerfall": '<path d="M16 16h29v12H16zM26 28h8v25h-8z"/><path d="m44 36 7 7-7 7" fill="none" stroke="currentColor"/>',
    "crossedblades": '<path d="m18 14 7 1 21 29-5 6-25-27zM46 14l-7 1-21 29 5 6 25-27z"/>',
    "roar": '<path d="M14 26h9l10-9v30l-10-9h-9z"/><path d="M39 22q12 10 0 20m5-27q20 17 0 34" fill="none" stroke="currentColor"/>',
    "ward": '<path d="M32 12 49 20v12q-2 13-17 20Q17 45 15 32V20z" fill="none" stroke="currentColor" stroke-width="5"/><path d="M32 22v17m-8-8h16"/>',
    "heartbeat": '<path d="M11 33h11l5-13 9 25 6-12h11" fill="none" stroke="currentColor" stroke-width="5" stroke-linejoin="round"/>',
    "fang": '<path d="M18 15q14 8 28 0l-3 24q-1 12-8 12l-5-12-5 12q-7 0-8-12z"/>',
    "fireorb": '<circle cx="32" cy="35" r="14"/><path d="M31 12q9 11 2 17 8-3 9-8 8 13-1 21-7 6-15 0-8-8 0-16 0 5 5 7-2-9 5-21z"/>',
    "flamewall": '<path d="M14 51V31q8 0 8-14 11 8 6 19 9-4 8-16 13 11 7 22 8-4 8-15 9 8 4 24z"/>',
    "firespear": '<path d="M32 10 43 27 36 27 38 46 26 46 28 27 21 27z"/><path d="m32 18 4 8h-8z"/>',
    "icespear": '<path d="M32 10 42 27 36 27 37 47 27 47 28 27 22 27z"/><path d="M32 16v28m-5-16 10 7m0-7-10 7" fill="none" stroke="currentColor" stroke-width="2"/>',
    "forkedbolt": '<path d="M35 10 19 33h11l-2 21 18-28H35z"/>',
    "arcburst": '<path d="M32 13v12m0 14v12M13 32h12m14 0h12M19 19l9 9m8 8 9 9m0-26-9 9m-8 8-9 9" fill="none" stroke="currentColor" stroke-width="5"/><circle cx="32" cy="32" r="8"/>',
    "stormwall": '<path d="M12 18h40v8H12zm0 20h40v8H12z"/><path d="m34 13-9 16h8l-4 22 12-20h-8z"/>',
    "soulburst": '<path d="M32 12q5 10 14 12-9 7-7 18-9-4-15 7-1-11-11-16 10-4 9-15 7 5 10-6z"/><circle cx="32" cy="32" r="5"/>',
    "wisp": '<path d="M32 12q18 4 13 24-2 9-13 17-11-8-13-17-5-20 13-24z"/><circle cx="27" cy="30" r="2"/><circle cx="37" cy="30" r="2"/><path d="M26 38q6 5 12 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "veilshield": '<path d="M32 12 48 19v13q-2 13-16 20Q18 45 16 32V19z"/><path d="M22 32q5-9 10 0t10 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "icewall": '<path d="m14 18 10-6 9 6 8-5 9 8v25l-9 7-9-6-8 6-10-8z"/><path d="m24 12 2 35m15-34-2 34" fill="none" stroke="currentColor" stroke-width="2"/>',
    "foldgate": '<path d="M18 50V25q0-14 14-14t14 14v25h-8V25q0-7-6-7t-6 7v25z"/><path d="M12 43h11m18 0h11"/>',
    "manaorbit": '<circle cx="32" cy="32" r="9"/><ellipse cx="32" cy="32" rx="21" ry="10" fill="none" stroke="currentColor" stroke-width="3" transform="rotate(-35 32 32)"/><circle cx="47" cy="20" r="3"/>',
    "twinarrow": '<path d="m15 22 34 10-34 10 7-10z"/><path d="m19 15 29 17-29 17 6-17z"/>',
    "lancearrow": '<path d="M10 32 47 18 39 32l8 14z"/><path d="M13 32h31" fill="none" stroke="currentColor" stroke-width="3"/>',
    "arrowfall": '<path d="m18 12 9 5-5 8-9-5zm15 2 9 5-5 8-9-5zm11 10 9 5-5 8-9-5z"/><path d="m18 29 8 4-5 17-7-3zm17 4 8 4-5 14-7-3zm13-3 8 4-5 16-7-3z"/>',
    "sightline": '<circle cx="32" cy="32" r="17" fill="none" stroke="currentColor" stroke-width="4"/><path d="M32 9v14m0 18v14M9 32h14m18 0h14M32 32l14-14" fill="none" stroke="currentColor" stroke-width="3"/>',
    "snare": '<circle cx="32" cy="34" r="15" fill="none" stroke="currentColor" stroke-width="4"/><path d="M32 10v11m-18 4 9 5m18 0 9-5M32 49v6" fill="none" stroke="currentColor" stroke-width="4"/>',
    "bursttrap": '<path d="M32 10 37 24 51 18 44 31 55 38 40 39 40 54 31 43 20 53 23 39 9 35 22 29 17 15 29 23z"/>',
    "frostarrow": '<path d="M12 32 46 20 39 32l7 12z"/><path d="M25 14v10m-7-5 7 5m14 16v10m-7-5 7-5" fill="none" stroke="currentColor" stroke-width="3"/>',
    "leafward": '<path d="M12 47Q13 16 50 13q-1 34-31 37l14-22z"/><path d="M18 48 38 28" fill="none" stroke="currentColor" stroke-width="3"/>',
    "bullseye": '<circle cx="32" cy="32" r="19" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="32" cy="32" r="9" fill="none" stroke="currentColor" stroke-width="3"/><circle cx="32" cy="32" r="3"/>',
    "featherbeat": '<path d="M47 12Q20 12 17 35q-1 10 8 14l-2-14q9 8 16 0 9-9 8-23z"/><path d="M14 50q12-12 25-24" fill="none" stroke="currentColor" stroke-width="3"/>',
    "traploop": '<path d="M14 32q0-17 18-17t18 17q0 17-18 17t-18-17z" fill="none" stroke="currentColor" stroke-width="4"/><path d="M32 13v13l9 6" fill="none" stroke="currentColor" stroke-width="4"/>',
    "countercut": '<path d="m18 47 25-30 6 5-25 30z"/><path d="M13 18h16v6H19v10h-6z"/>',
    "watchtower": '<path d="M20 50V25h24v25zM16 25l16-13 16 13z"/><circle cx="32" cy="31" r="5"/>',
    "anchor": '<path d="M28 13h8v27q0 8-9 8t-11-9h8q1 4 5 3 3-1 3-4V13z"/><circle cx="32" cy="15" r="6"/><path d="M14 38q4 12 18 12t18-12" fill="none" stroke="currentColor" stroke-width="4"/>',
    "lockline": '<path d="M10 27h44v10H10z"/><path d="M25 27v-7q0-8 7-8t7 8v7m-14 10v6q0 8 7 8t7-8v-6" fill="none" stroke="currentColor" stroke-width="4"/>',
    "returnguard": '<path d="M32 12 48 19v12q-2 13-16 20Q18 44 16 31V19z"/><path d="M39 25q-3-7-11-5l-5 5m0-8v8h8" fill="none" stroke="currentColor" stroke-width="3"/>',
    "advancingwall": '<path d="M14 21h32v23H14z"/><path d="m36 14 12 18-12 18" fill="none" stroke="currentColor" stroke-width="5"/>',
    "reprisalwave": '<path d="M12 42q10-22 20 0t20 0" fill="none" stroke="currentColor" stroke-width="6"/><path d="M12 28q10-22 20 0t20 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "rupture": '<path d="M32 10 26 27l9-3-7 30 17-25-10 2 7-21z"/><path d="M13 33h10m18 0h10" stroke="currentColor" stroke-width="3"/>',
    "ironroot": '<path d="M22 11h20l-2 16 8 10-5 14-11-7-11 7-5-14 8-10z"/><path d="M32 28v16m-9-8h18" fill="none" stroke="currentColor" stroke-width="3"/>',
    "woundleap": '<path d="M13 43q18 2 27-24l-7-2 13-9 3 16-5-3q-7 29-31 30z"/><path d="m20 22 7 6-7 6"/>',
    "execution": '<path d="M18 13h28v8H18zM28 21h8v29h-8z"/><path d="m24 42 8-8 8 8-8 8z"/>',
    "pursuit": '<path d="M14 43Q25 14 49 18 42 42 14 43z"/><path d="m14 43 25-19" fill="none" stroke="currentColor" stroke-width="3"/><path d="m39 16 10 2-2 10" fill="none" stroke="currentColor" stroke-width="3"/>',
    "bloodrift": '<path d="M32 10Q47 28 42 40q-3 10-10 10T22 40Q17 28 32 10z"/><path d="m21 32 8-5-3 9 9-6-2 8 11-7" fill="none" stroke="currentColor" stroke-width="3"/>',
    "breathsteal": '<path d="M32 12q16 0 16 15 0 14-16 25Q16 41 16 27q0-15 16-15z"/><path d="M21 32h8l4-8 5 16 4-8h4" fill="none" stroke="currentColor" stroke-width="3"/>',
    "flameburst": '<circle cx="32" cy="34" r="9"/><path d="M32 10 37 23 50 18 43 31 54 39 40 39 39 53 31 43 21 52 23 39 10 35 22 29 17 16 29 23z"/>',
    "prismfocus": '<path d="m32 11 18 13-7 23H21l-7-23z" fill="none" stroke="currentColor" stroke-width="4"/><path d="m32 18 10 8-4 14H26l-4-14z"/>',
    "glacialring": '<circle cx="32" cy="32" r="18" fill="none" stroke="currentColor" stroke-width="6"/><path d="M32 8v14m0 20v14M8 32h14m20 0h14" stroke="currentColor" stroke-width="3"/>',
    "lightningarc": '<path d="M13 40q10-23 20 0t18 0" fill="none" stroke="currentColor" stroke-width="5"/><path d="m32 10-7 17h9l-3 18 11-23h-9z"/>',
    "resonance": '<circle cx="32" cy="32" r="5"/><path d="M32 12q13 9 0 20-13-11 0-20zm20 20q-9 13-20 0 11-13 20 0zM32 52q-13-9 0-20 13 11 0 20zM12 32q9-13 20 0-11 13-20 0z"/>',
    "emberpath": '<path d="M12 48q10-3 10-17 10 2 10-16 13 13 3 23 9-1 14-10 6 25-37 20z"/>',
    "trinova": '<path d="m32 11 6 13 14 2-10 10 2 15-12-7-13 7 3-15-10-10 14-2z"/><circle cx="32" cy="32" r="5"/>',
    "echocurse": '<path d="M17 32a15 15 0 1 1 5 11" fill="none" stroke="currentColor" stroke-width="5"/><path d="m17 32 1-11 9 7z"/><path d="M47 32a15 15 0 1 1-5-11" fill="none" stroke="currentColor" stroke-width="3"/>',
    "echorecovery": '<path d="M32 13q14 4 10 19-3 9-10 16-7-7-10-16-4-15 10-19z"/><path d="M20 30q12 9 24 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "souldrain": '<path d="M32 11q13 14 9 24-2 7-9 7t-9-7q-4-10 9-24z"/><path d="M18 47q14-14 28 0m-23 4q9-9 18 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "spectralveil": '<path d="M13 34q19-25 38 0-19 25-38 0z"/><circle cx="32" cy="34" r="7"/><path d="M18 51q8-7 15 0t14 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "channelbeads": '<path d="M32 12v40M12 32h40M18 18l28 28m0-28L18 46" stroke="currentColor" stroke-width="3"/><circle cx="32" cy="12" r="5"/><circle cx="52" cy="32" r="5"/><circle cx="32" cy="52" r="5"/><circle cx="12" cy="32" r="5"/><circle cx="32" cy="32" r="7"/>',
    "procession": '<path d="M13 38q6-9 12 0t12 0 14 0" fill="none" stroke="currentColor" stroke-width="4"/><path d="M20 30q-3-10 4-14 7 4 4 14zm16 0q-3-10 4-14 7 4 4 14z"/>',
    "dissipation": '<path d="M14 25h20l-7 8h23M50 39H30l7-8H14" fill="none" stroke="currentColor" stroke-width="5"/><circle cx="32" cy="32" r="4"/>',
    "trace": '<path d="M15 47V17h34v30z" fill="none" stroke="currentColor" stroke-width="3"/><path d="m20 42 11-22 12 22z" fill="none" stroke="currentColor" stroke-width="4"/>',
    "triangle": '<path d="m32 12 20 36H12z" fill="none" stroke="currentColor" stroke-width="5"/><circle cx="32" cy="12" r="4"/><circle cx="52" cy="48" r="4"/><circle cx="12" cy="48" r="4"/>',
    "incidence": '<path d="M12 43 46 14M14 19l36 27" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="30" cy="31" r="7"/>',
    "translation": '<path d="M14 18h25v25H14z" fill="none" stroke="currentColor" stroke-width="4"/><path d="m35 14 14 14-14 14m13-14H25" fill="none" stroke="currentColor" stroke-width="4"/>',
    "vectormemory": '<path d="M32 11 51 32 32 53 13 32z" fill="none" stroke="currentColor" stroke-width="4"/><path d="M32 18v28m-14-14h28" stroke="currentColor" stroke-width="3"/><circle cx="32" cy="32" r="5"/>',
    "collapse": '<path d="M13 13 27 27m24-14L37 27M13 51l14-14m24 14L37 37" stroke="currentColor" stroke-width="5"/><path d="m32 22 10 10-10 10-10-10z"/>',
    "rewrite": '<path d="M16 43 39 20l7 7-23 23-10 3z"/><path d="M35 18 40 13q3-3 6 0l5 5q3 3 0 6l-5 5"/><path d="M12 15h13m-13 7h9" stroke="currentColor" stroke-width="3"/>',
    "headshot": '<path d="M11 32 47 20l-7 12 7 12z"/><circle cx="35" cy="32" r="3"/>',
    "observe": '<circle cx="32" cy="32" r="17" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="32" cy="32" r="6"/><path d="M32 9v7m0 32v7" stroke="currentColor" stroke-width="3"/>',
    "precisionstance": '<path d="M16 48V27q0-16 16-16t16 16v21h-9V27q0-7-7-7t-7 7v21z"/><path d="M22 39h20" stroke="currentColor" stroke-width="3"/>',
    "piercingshot": '<path d="M9 32 47 19l-8 13 8 13z"/><path d="M17 32h37m-8-8 8 8-8 8" fill="none" stroke="currentColor" stroke-width="3"/>',
    "netshot": '<path d="M14 17 49 47M49 17 14 47M14 17h35v30H14z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M14 32h35M31 17v30" stroke="currentColor" stroke-width="2"/>',
    "explosiveshot": '<circle cx="32" cy="32" r="9"/><path d="M32 10v10m0 24v10M10 32h10m24 0h10M16 16l8 8m16 16 8 8m0-32-8 8m-16 16-8 8" stroke="currentColor" stroke-width="4"/>',
    "openingread": '<path d="M14 46 31 17l19 29z" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="32" cy="34" r="6"/><path d="M8 19h12m24 0h12" stroke="currentColor" stroke-width="3"/>',
    "concussion": '<circle cx="32" cy="32" r="8"/><path d="M32 11q14 7 0 13-14-6 0-13zm20 21q-7 14-13 0 6-14 13 0zM32 53q-14-7 0-13 14 6 0 13zM12 32q7-14 13 0-6 14-13 0z"/>',
    "absolutefocus": '<circle cx="32" cy="32" r="19" fill="none" stroke="currentColor" stroke-width="4"/><path d="M32 16v32M16 32h32m-28-11 23 23m0-23L20 44" stroke="currentColor" stroke-width="2"/><circle cx="32" cy="32" r="5"/>',
    "freezingtrap": '<path d="M32 10v44M13 21l38 22M13 43l38-22" stroke="currentColor" stroke-width="4"/><circle cx="32" cy="32" r="7"/>',
    "tartrap": '<path d="M13 28q0-14 19-14t19 14q0 13-19 13T13 28z"/><path d="M17 41q0 10 15 10t15-10" fill="none" stroke="currentColor" stroke-width="4"/>',
    "thorntrap": '<path d="M32 10 38 25 53 20 43 33 53 45 37 40 32 55 27 40 11 45 21 33 11 20 26 25z"/>',
    "huntermark": '<path d="M32 11 51 32 32 53 13 32z"/><circle cx="32" cy="32" r="7" fill="none" stroke="currentColor" stroke-width="3"/>',
    "discipline": '<path d="M19 12h26v40H19z"/><path d="M24 23h16m-16 9h16m-16 9h10" stroke="currentColor" stroke-width="3"/>',
    "covershot": '<path d="M12 46 32 14l20 32z"/><path d="M17 42q15-14 30 0" fill="none" stroke="currentColor" stroke-width="3"/>',
    "easyprey": '<path d="M12 28q20-17 40 0-20 18-40 0z"/><circle cx="32" cy="28" r="6"/><path d="m35 40 8 9m-7-13 11 4" stroke="currentColor" stroke-width="3"/>',
    "totalcover": '<path d="M32 11 49 19v13q-2 13-17 20Q17 45 15 32V19z"/><path d="M22 31h20M32 21v21" stroke="currentColor" stroke-width="4"/>',
}

# ---- E09: 28 hybrid skills (T3). IDs are fixed by docs/epics/e09_contract.md section 1. ----
# They are not in ClassCatalog yet (T1 and the kit tasks register them), so --check covers them by this list.
HYBRID_SKILLS = {
    "paladin": ["paladin_oath", "paladin_guard_grace", "paladin_consecrated_impact", "paladin_oath_aegis",
                "paladin_unshaken_faith", "paladin_condemned_seal", "paladin_oath_hour"],
    "thaumaturge": ["thaumaturge_votive_circle", "thaumaturge_votive_prism", "thaumaturge_healing_refraction",
                    "thaumaturge_altar_shift", "thaumaturge_elemental_choir", "thaumaturge_prismatic_judgment",
                    "thaumaturge_convergent_dawn"],
    "duelist": ["duelist_parry", "duelist_read_opponent", "duelist_fatal_riposte", "duelist_feint",
                "duelist_patient_guard", "duelist_guarded_retreat", "duelist_duel"],
    "arcane_blade": ["arcane_blade_refracted_mark", "arcane_blade_enchanted_edge", "arcane_blade_refraction",
                     "arcane_blade_prismatic_leap", "arcane_blade_light_fracture", "arcane_blade_prismatic_sentence",
                     "arcane_blade_prism_specter"],
}
HYBRID_IDS = [i for ids in HYBRID_SKILLS.values() for i in ids]
HYBRID_PASSIVES = {"paladin_guard_grace", "paladin_unshaken_faith", "thaumaturge_votive_prism", "thaumaturge_elemental_choir",
                   "duelist_read_opponent", "duelist_patient_guard", "arcane_blade_enchanted_edge", "arcane_blade_light_fracture"}
HYBRID_CLASSES = tuple(HYBRID_SKILLS)
# Catalog skills added after the E06 icon batch; they have no icon and are outside T3's 28. Reported, not generated.
PENDING_ICON_IDS = {"berserker_deep_bleeding", "berserker_pursuit_cut", "defender_retreat_guard", "defender_riposte"}


def _xy(cx: float, cy: float, r: float, deg: float) -> tuple[float, float]:
    a = math.radians(deg)
    return round(cx + r * math.cos(a), 1), round(cy + r * math.sin(a), 1)


def _rays(cx: float, cy: float, r1: float, r2: float, n: int, start: float = -90.0, span: float = 360.0, closed: bool = True) -> str:
    step = span / (n if closed else max(n - 1, 1))
    out = []
    for i in range(n):
        x1, y1 = _xy(cx, cy, r1, start + i * step)
        x2, y2 = _xy(cx, cy, r2, start + i * step)
        out.append(f"M{x1:g} {y1:g}L{x2:g} {y2:g}")
    return "".join(out)


def _ringd(cx: float, cy: float, r: float) -> str:
    return f"M{cx - r:g} {cy:g}a{r:g} {r:g} 0 1 0 {2 * r:g} 0a{r:g} {r:g} 0 1 0 {-2 * r:g} 0z"


def _line(w: float, extra: str = "") -> str:
    return f'fill="none" stroke="currentColor" stroke-width="{w:g}"{extra}'


def _dots(cx: float, cy: float, r: float, angles, dot: float) -> str:
    return "".join(f'<circle cx="{x:g}" cy="{y:g}" r="{dot:g}"/>' for x, y in (_xy(cx, cy, r, a) for a in angles))


HYBRID_SHAPES = {
    # Paladin: shield, cone/column/halo of light
    "oathcone": '<path d="M32 38 13 19Q32 12 51 19z"/><path d="M25 42h14v5q0 6-7 9-7-3-7-9z"/>',
    "gracepips": f'<path d="{_ringd(32, 32, 10)}" {_line(3)}/>' + _dots(32, 32, 21, (-90, -18, 54, 126, 198), 3.5),
    "lightcolumn": '<path d="M27 15h10l5 27H22z"/><path d="M13 48a19 5.5 0 1 0 38 0a19 5.5 0 1 0-38 0z"/>',
    "haloburst": f'<path d="M41.5 15.5A17 17 0 1 0 49 27" {_line(6)}/><path d="M45 8l3 7m8 2-7 3m7 7-8 1" {_line(3.5)}/><circle cx="32" cy="32" r="5"/>',
    "faithcross": '<path d="M27 8h10v16h15v10H37v22H27V34H12V24h15z"/>',
    "sealring": f'<path d="{_ringd(32, 32, 19)}" {_line(4)}/><path d="M32 14 27 24h10zM32 50 27 40h10zM14 32l10-5v10zM50 32 40 27v10z"/><circle cx="32" cy="32" r="4.5"/>',
    "sunhour": f'<circle cx="32" cy="32" r="8"/><path d="{_ringd(32, 32, 15)}" {_line(3)}/><path d="{_rays(32, 32, 20, 27, 12)}" {_line(4)}/>',
    # Thaumaturge: elemental circle, prism, altar
    "votivering": f'<path d="{_ringd(32, 32, 21)}" {_line(3)}/><path d="{_ringd(32, 32, 15)}" {_line(2)}/>'
                  '<path d="M32 24Q39 31 36 36a4.5 4.5 0 0 1-9 0Q25 31 32 24z"/>' + _dots(32, 32, 21, (-90, 30, 150), 3.5),
    "prismfan": f'<path d="M30 14 48 46H12z" {_line(4)}/><path d="M5 34h14m22-4 16-8m-16 10h17m-17 6 15 9" {_line(3)}/>',
    "healcross": f'<path d="M27 14h10v13h13v10H37v13H27V37H14V27h13z"/><path d="M9 22q-5 10 0 20m46-20q5 10 0 20" {_line(3)}/>',
    "altarshift": f'<path d="M16 19h24l-6-6m6 6-6 6M48 31H24l6-6m-6 6 6 6" {_line(4)}/><path d="M12 43h40v6H12zM18 49h28v8H18z"/>',
    "elemchoir": '<g transform="translate(8 24)"><path d="M8 0Q18 9 14 15 18 14 16 20a8 8 0 0 1-16 0Q0 12 8 0z"/></g>'
                 '<g transform="translate(24 24)"><path d="M8 0Q16 10 16 16a8 8 0 0 1-16 0Q0 10 8 0z"/></g>'
                 '<g transform="translate(40 24)"><path d="M10 0 0 14h7l-2 10 11-15H9z"/></g>'
                 f'<path d="M10 17Q32 2 54 17" {_line(3)}/>',
    "judgmentpulses": f'<path d="M27 6h10l3 22H24z"/><path d="M19 36a13 4 0 1 0 26 0a13 4 0 1 0-26 0zM13 44a19 5 0 1 0 38 0a19 5 0 1 0-38 0zM9 53a23 5 0 1 0 46 0a23 5 0 1 0-46 0z" {_line(3)}/>',
    "dawnsun": f'<path d="M16 44a16 16 0 0 1 32 0z"/><path d="M6 50h52" {_line(4)}/><path d="{_rays(32, 44, 22, 31, 7, 180, 180, False)}" {_line(4)}/><path d="M14 57h36" {_line(2)}/>',
    # Duelist: rapier, parry, silver and shadow
    "parryarc": f'<path d="M10 54 38 14l5 4z"/><path d="M20 36l-8 6 12 8 3-9z"/><path d="M34 12q16 2 20 18m0 0-7-2m7 2 1-7" {_line(3.5)}/>',
    "slitseye": f'<path d="M8 32Q32 12 56 32Q32 52 8 32z"/><path d="M32 23v18" {_line(3)}/><path d="M32 6v6m-15 0 3 5m27-5-3 5" {_line(3)}/>',
    "thruststar": f'<path d="M5 34 44 29v10z"/><path d="M11 22q-7 12 0 24" {_line(4)}/><path d="{_rays(52, 34, 3, 9, 8)}" {_line(3.5)}/><circle cx="52" cy="34" r="3"/>',
    "sidestep": f'<path d="M10 48Q24 20 46 26" {_line(5)}/><path d="M38 14 54 27 38 36z"/><path d="M10 54h44" {_line(3, " stroke-dasharray=\"3 5\"")}/>',
    "hourglass": f'<path d="M18 10h28M18 54h28M21 10q0 15 11 22-11 7-11 22M43 10q0 15-11 22 11 7 11 22" {_line(3)}/><path d="M26 47h12" {_line(3)}/>',
    "retreatchevrons": f'<path d="M32 12 16 32l16 20M46 18 34 32l12 14" {_line(5)}/><path d="M53 10v44" {_line(4)}/>',
    "dueltips": f'<path d="M5 38 28 31 29 37zM59 38 36 31 35 37z"/><path d="M5 26v24M59 26v24M12 55h40" {_line(4)}/><path d="{_rays(32, 31, 3, 11, 8)}" {_line(3.5)}/><circle cx="32" cy="31" r="3"/>',
    # Arcane Blade: crystal, prism, refracted light
    "markprism": f'<path d="{_ringd(32, 32, 19)}" {_line(3)}/><path d="M32 21 43 41H21z"/><path d="M32 6v7m0 38v7M6 32h7m38 0h7" {_line(3.5)}/>',
    "crystaledge": f'<path d="M32 6 40 16v26l-8 8-8-8V16z" {_line(3)}/><path d="M32 6v44M19 50h26M32 50v8" {_line(3.5)}/>',
    "bentghost": f'<path d="M32 10a9 9 0 1 0 .1 0zM14 46q0-14 18-14t18 14z" {_line(4, " stroke-dasharray=\"4 4\"")}/><path d="M6 24 24 30 36 22 58 34" {_line(3.5)}/>',
    "prismleap": f'<path d="M12 44Q30 2 50 38" {_line(4, " stroke-dasharray=\"1 7\"")}/><path d="M42 36 50 52 58 34z"/><path d="M12 36l7 9-7 9-7-9z"/>',
    "fracturegem": f'<path d="M32 8 52 20v24L32 56 12 44V20z" {_line(3)}/><path d="M32 8 27 24 38 32 29 46 32 56" {_line(3.5)}/>',
    "tricut": f'<path d="M32 56 22 24 32 8 42 24z"/><path d="M8 20l12 5M6 32l14 3M10 44l11 1M56 20l-12 5M58 32l-14 3M54 44l-11 1" {_line(3.5)}/>',
    "specterthree": f'<path d="M32 8 45 28 32 54 19 28z"/><path d="M12 20 19 31 12 46 5 31zM52 20l7 11-7 15-7-15z" {_line(3)}/>',
}
SHAPES.update(HYBRID_SHAPES)
SPECIAL.update({
    "paladin_oath": "oathcone", "paladin_guard_grace": "gracepips", "paladin_consecrated_impact": "lightcolumn",
    "paladin_oath_aegis": "haloburst", "paladin_unshaken_faith": "faithcross", "paladin_condemned_seal": "sealring",
    "paladin_oath_hour": "sunhour",
    "thaumaturge_votive_circle": "votivering", "thaumaturge_votive_prism": "prismfan", "thaumaturge_healing_refraction": "healcross",
    "thaumaturge_altar_shift": "altarshift", "thaumaturge_elemental_choir": "elemchoir",
    "thaumaturge_prismatic_judgment": "judgmentpulses", "thaumaturge_convergent_dawn": "dawnsun",
    "duelist_parry": "parryarc", "duelist_read_opponent": "slitseye", "duelist_fatal_riposte": "thruststar",
    "duelist_feint": "sidestep", "duelist_patient_guard": "hourglass", "duelist_guarded_retreat": "retreatchevrons",
    "duelist_duel": "dueltips",
    "arcane_blade_refracted_mark": "markprism", "arcane_blade_enchanted_edge": "crystaledge", "arcane_blade_refraction": "bentghost",
    "arcane_blade_prismatic_leap": "prismleap", "arcane_blade_light_fracture": "fracturegem",
    "arcane_blade_prismatic_sentence": "tricut", "arcane_blade_prism_specter": "specterthree",
})


# ---- E10a: 22 Acolyte-family skills (T3). IDs are fixed by docs/epics/e10a_contract.md section 1. ----
E10A_SKILLS = {
    "acolyte": ["acolyte_punishing_light", "acolyte_prayer", "acolyte_votive_shield", "acolyte_shadow_seal",
                "acolyte_disturbing_whisper", "acolyte_eldritch_vision", "acolyte_devotion", "acolyte_protective_faith"],
    "priest": ["priest_sanctuary", "priest_grace", "priest_aegis", "priest_judgment", "priest_exorcist",
               "priest_light_seal", "priest_holy_hour"],
    "cultist": ["cultist_abyss_gaze", "cultist_ecstasy", "cultist_impossible_idol", "cultist_shared_delirium",
                "cultist_open_pupil", "cultist_impossible_geometry", "cultist_revelation"],
}
E10A_IDS = [i for ids in E10A_SKILLS.values() for i in ids]
E10A_PASSIVES = {"acolyte_devotion", "acolyte_protective_faith", "priest_grace", "priest_exorcist",
                 "cultist_ecstasy", "cultist_open_pupil"}
E10A_CLASSES = tuple(E10A_SKILLS)
# --check enforces these exact kit lists (28 from E09 + 22 from E10a = 50), independent of the catalog.
EXPECTED_KIT_COUNTS = {"E09": 28, "E10a": 22}


def _star(cx: float, cy: float, r1: float, r2: float, n: int, start: float = -90.0) -> str:
    pts = []
    for i in range(2 * n):
        x, y = _xy(cx, cy, r1 if i % 2 == 0 else r2, start + i * 180.0 / n)
        pts.append(f"{x:g} {y:g}")
    return "M" + "L".join(pts) + "z"


def _spiral(cx: float, cy: float, r0: float, r1: float, turns: float, start: float = 0.0, steps: int = 48) -> str:
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x, y = _xy(cx, cy, r0 + (r1 - r0) * t, start + 360.0 * turns * t)
        pts.append(f"{x:g} {y:g}")
    return "M" + "L".join(pts)


def _arc(cx: float, cy: float, r: float, a0: float, a1: float) -> str:
    x0, y0 = _xy(cx, cy, r, a0)
    x1, y1 = _xy(cx, cy, r, a1)
    large = 1 if abs(a1 - a0) > 180 else 0
    return f"M{x0:g} {y0:g}A{r:g} {r:g} 0 {large} 1 {x1:g} {y1:g}"


def _eye(cx: float, cy: float, w: float, h: float) -> str:
    return f"M{cx - w:g} {cy:g}Q{cx:g} {cy - h:g} {cx + w:g} {cy:g}Q{cx:g} {cy + h:g} {cx - w:g} {cy:g}z"


BGSTROKE = ' stroke="@bg"'
# "@bg" is replaced by the tile colour (negative space); "@acc" by the accent colour.
E10A_SHAPES = {
    # Base: light and shadow share each symbol
    "lightbeam": '<circle cx="46" cy="32" r="8"/>' f'<path d="M6 32h31M12 23h18M12 41h18" {_line(4)}/>'
                 f'<path d="{_rays(46, 32, 12, 19, 5, -60, 120, False)}" {_line(3)}/>',
    "prayhands": '<path d="M32 9Q47 22 42 53H22Q17 22 32 9z"/>' f'<path d="M32 24v24" {_line(3, BGSTROKE)}/>'
                 f'<path d="M13 30q-5 8 0 16M51 30q5 8 0 16" {_line(3)}/>',
    "votiveshield": '<path d="M32 7 51 15v14c0 13-8 22-19 28C21 51 13 42 13 29V15z"/>'
                    '<path d="M32 21q9 9 4 15a6.5 6.5 0 0 1-8 0q-5-6 4-15z" fill="@bg" stroke="none"/>',
    "shadowseal": f'<path d="{_ringd(32, 32, 20)}" {_line(4)}/><path d="M39 21a12 12 0 1 0 0 22 9 9 0 1 1 0-22z"/>'
                  f'<path d="M32 4v6M32 54v6M4 32h6M54 32h6" {_line(3.5)}/>',
    "whispercone": '<path d="M7 32 55 11v42z"/>' f'<path d="M24 32q4-6 8 0t8 0M24 23q4-6 8 0t8 0M24 41q4-6 8 0t8 0" {_line(2.8, BGSTROKE)}/>',
    "farsight": '<path d="M3 32Q21 12 39 32Q21 52 3 32z"/><circle cx="21" cy="32" r="6" fill="@bg" stroke="none"/>'
                f'<path d="M43 32h5" {_line(3.5, " stroke-dasharray=\"1 4\"")}/>'
                f'<path d="{_ringd(55, 32, 5.5)}" {_line(3)}/><circle cx="55" cy="32" r="1.8"/>',
    "sunmoon": f'<path d="{_ringd(19, 32, 8)}" {_line(3)}/><path d="{_rays(19, 32, 12, 17, 8)}" {_line(3)}/>'
               f'<path d="M50 17a15 15 0 1 0 0 30 11 11 0 1 1 0-30z" {_line(3)}/>'
               f'<path d="M19 55q13 8 26 0M19 9q13-8 26 0" {_line(2.5)}/>',
    "faitharch": f'<path d="M14 54V30Q14 10 32 10T50 30V54z" {_line(3.5)}/><path d="M32 24v22M23 34h18" {_line(3.5)}/>'
                 f'<path d="M8 54h48" {_line(3)}/>',
    # Priest: closed rings, circles and verticals
    "sanctuarycircle": f'<path d="M8 45a24 10 0 1 0 48 0a24 10 0 1 0-48 0z" {_line(4)}/>'
                       f'<path d="M18 45a14 5.5 0 1 0 28 0a14 5.5 0 1 0-28 0z" {_line(2.5)}/>'
                       '<circle cx="8" cy="45" r="3"/><circle cx="56" cy="45" r="3"/><circle cx="32" cy="35" r="3"/><circle cx="32" cy="55" r="3"/>'
                       '<circle cx="32" cy="13" r="5"/><path d="M32 21 23 41h18z"/>',
    "halostack": f'<path d="M18 17a14 4.5 0 1 0 28 0a14 4.5 0 1 0-28 0zM14 31a18 5.5 0 1 0 36 0a18 5.5 0 1 0-36 0zM10 46a22 7 0 1 0 44 0a22 7 0 1 0-44 0z" {_line(3.5)}/>'
                 f'<path d="M32 4v5M32 55v5" {_line(3)}/>',
    "haloaegis": f'<path d="{_ringd(32, 34, 20)}" {_line(4)}/><path d="{_ringd(32, 34, 27)}" {_line(2.5, " stroke-dasharray=\"2 5\"")}/>'
                 '<circle cx="32" cy="26" r="5"/><path d="M32 33 23 49h18z"/>',
    "judgmentarrow": '<path d="M26 4h12v24h9L32 44 17 28h9z"/>' f'<path d="M10 8v26M54 8v26" {_line(3.5)}/>'
                     f'<path d="M8 51a24 7 0 1 0 48 0a24 7 0 1 0-48 0z" {_line(3.5)}/>',
    "crackedshield": f'<path d="M32 9 47 15v13q0 12-15 20Q17 40 17 28V15z" {_line(3.5)}/>'
                     f'<path d="M33 9 27 22l8 6-6 10 3 10" {_line(3.5)}/><path d="M41 44l5 7M24 45l-5 7M50 32h6" {_line(3)}/>',
    "closingring": f'<path d="M28 10A22 22 0 0 0 28 54M36 10A22 22 0 0 1 36 54" {_line(5)}/>'
                   '<path d="M32 16 27 6h10zM32 48 27 58h10z"/><path d="M32 25l7 7-7 7-7-7z"/>',
    "grandcircle": f'<path d="M4 47a28 11 0 1 0 56 0a28 11 0 1 0-56 0z" {_line(3, " stroke-dasharray=\"6 4\"")}/>'
                   f'<path d="M14 47a18 7 0 1 0 36 0a18 7 0 1 0-36 0z" {_line(4)}/>'
                   f'<path d="{_star(32, 24, 17, 7, 8)}"/>',
    # Cultist: eyes and open spirals
    "abyssgaze": '<path d="M3 27Q32 2 61 27Q32 52 3 27z"/>' f'<path d="{_spiral(32, 27, 1.5, 11, 2.2, -90)}" {_line(3, BGSTROKE)}/>'
                 f'<path d="M20 50v6M32 52v6M44 50v6" {_line(3.5)}/>',
    "grinring": f'<path d="{_arc(32, 33, 22, -60, 240)}" {_line(4)}/><path d="M20 27l9 4M44 27l-9 4" {_line(3.5)}/>'
                f'<path d="M18 40Q32 55 46 40" {_line(4.5)}/>',
    "idolstele": '<path d="M19 57V28L32 7l13 21v29z"/>' f'<path d="{_eye(32, 36, 9, 14)}" fill="@bg" stroke="none"/><circle cx="32" cy="36" r="3.2"/>'
                 f'<path d="M11 57h42" {_line(4)}/>',
    "eyechain": f'<path d="{_eye(16, 17, 10, 11)}"/><path d="{_eye(48, 17, 10, 11)}"/><path d="{_eye(32, 49, 10, 11)}"/>'
                '<circle cx="16" cy="17" r="3" fill="@bg" stroke="none"/><circle cx="48" cy="17" r="3" fill="@bg" stroke="none"/>'
                '<circle cx="32" cy="49" r="3" fill="@bg" stroke="none"/>'
                f'<path d="M29 17h6M20 27l8 14M44 27l-8 14" {_line(3, " stroke-dasharray=\"2 4\"")}/>',
    "dilatedeye": f'<path d="{_eye(32, 32, 28, 26)}" {_line(3.5)}/><path d="{_ringd(32, 32, 11)}" {_line(3)}/>'
                  f'<path d="{_ringd(32, 32, 4)}" {_line(2.5)}/><path d="{_rays(32, 32, 14, 19, 8, 22.5)}" {_line(2.5)}/>',
    "squarespiral": f'<path d="M9 9H55V55H15V19H47V47H23V27H39V39H31" {_line(4.5, " stroke-linejoin=\"miter\"")}/><circle cx="31" cy="33" r="2.5"/>',
    "revelationburst": f'<path d="{_star(32, 32, 29, 17, 12)}"/>' f'<path d="{_eye(32, 32, 13, 11)}" fill="@bg" stroke="none"/><circle cx="32" cy="32" r="4.5"/>',
}
SHAPES.update(E10A_SHAPES)
SPECIAL.update({
    "acolyte_punishing_light": "lightbeam", "acolyte_prayer": "prayhands", "acolyte_votive_shield": "votiveshield",
    "acolyte_shadow_seal": "shadowseal", "acolyte_disturbing_whisper": "whispercone", "acolyte_eldritch_vision": "farsight",
    "acolyte_devotion": "sunmoon", "acolyte_protective_faith": "faitharch",
    "priest_sanctuary": "sanctuarycircle", "priest_grace": "halostack", "priest_aegis": "haloaegis",
    "priest_judgment": "judgmentarrow", "priest_exorcist": "crackedshield", "priest_light_seal": "closingring",
    "priest_holy_hour": "grandcircle",
    "cultist_abyss_gaze": "abyssgaze", "cultist_ecstasy": "grinring", "cultist_impossible_idol": "idolstele",
    "cultist_shared_delirium": "eyechain", "cultist_open_pupil": "dilatedeye",
    "cultist_impossible_geometry": "squarespiral", "cultist_revelation": "revelationburst",
})


def ids_from_catalog() -> list[str]:
    source = CLASS_SOURCE.read_text(encoding="utf-8-sig")
    ids = set(re.findall(r'_add_(?:passive_)?skill\(&"([^\"]+)"', source))
    for file in (SENTINEL_SOURCE, HUNTER_SOURCE):
        data = file.read_text(encoding="utf-8-sig")
        block = re.search(r'const SKILL_IDS[^=]*=\s*\[(.*?)\]', data, re.S)
        if not block:
            raise ValueError(f"SKILL_IDS not found in {file}")
        ids.update(re.findall(r'&"([^\"]+)"', block.group(1)))
    # These executable item adapters are real IDs and intentionally reuse their catalog art.
    ids.update(("fire_spear", "ice_spear", "teleport"))
    ids.update(HYBRID_IDS)  # E09 IDs: explicit list until T1/K1-K4 register them in ClassCatalog
    ids.update(E10A_IDS)  # E10a IDs: explicit list until the E10a modules register them
    ids -= PENDING_ICON_IDS
    return sorted(ids)


def category_for(skill_id: str) -> str:
    if skill_id in {"swordsman_resistance", "vigor", "blood_thirst", "mage_mana_regeneration", "archer_precision", "archer_cadence", "trap_technique", "defender_watch", "defender_guard_return", "berserker_obstinacy", "berserker_pursuit", "elementalist_prismatic_focus", "elementalist_prismatic_resonance", "spiritualist_echo_recovery", "spiritualist_channel_focus", "geometer_incidence", "geometer_vector_memory", "sentinel_precision_stance", "sentinel_opening_read", "hunter_shooting_discipline", "hunter_easy_prey"}:
        return "passive"
    if skill_id in HYBRID_PASSIVES or skill_id in E10A_PASSIVES:
        return "passive"
    return "active"


def class_for(skill_id: str) -> str:
    for prefix in HYBRID_CLASSES + E10A_CLASSES:
        if skill_id.startswith(prefix + "_"):
            return prefix
    for prefix in ("defender", "berserker", "elementalist", "spiritualist", "geometer", "sentinel", "hunter"):
        if skill_id.startswith(prefix + "_"):
            return prefix
    if skill_id.startswith("archer_") or skill_id in {"double_shot", "piercing_arrow", "arrow_rain", "extended_aim", "snare_trap", "explosive_trap", "slowing_arrow", "foliage_shelter", "trap_technique"}:
        return "archer"
    if skill_id.startswith(("fire", "ice", "lightning", "electric", "soul", "haunt", "phantom", "mage_")) or skill_id in {"teleport"}:
        return "mage"
    return "swordsman"


def _frame(cls: str, category: str, bg: str, fg: str, acc: str) -> str:
    """Tile behind the glyph. Mirrors the E06/E09 convention: passives sit on the plain rounded square."""
    if cls == "acolyte":
        return f'<rect x="4" y="4" width="56" height="56" rx="8" fill="{bg}"/><path d="M7 18V7h11M46 7h11v11M7 46v11h11M46 57h11V46" fill="none" stroke="{fg}" stroke-width="2"/>'
    if category == "passive":
        if cls in ("priest", "cultist"):
            return f'<rect x="5" y="5" width="54" height="54" rx="8" fill="{bg}"/><rect x="8.5" y="8.5" width="47" height="47" rx="5" fill="none" stroke="{acc}" stroke-width="2"/>'
        return f'<rect x="5" y="5" width="54" height="54" rx="8" fill="{bg}"/>'
    if cls == "priest":
        return f'<circle cx="32" cy="32" r="29" fill="{bg}"/><circle cx="32" cy="32" r="26" fill="none" stroke="{acc}" stroke-width="2.5"/>'
    if cls == "cultist":
        pinch = "M7 6Q32 12 57 6Q53 32 57 58Q32 52 7 58Q11 32 7 6z"
        return f'<path d="{pinch}" fill="{bg}"/><path d="{pinch}" fill="none" stroke="{acc}" stroke-width="2.5" stroke-linejoin="round"/>'
    if cls in ("mage", "elementalist", "thaumaturge"):
        return f'<path d="M15 8h33q9 0 9 8v31q0 9-9 9H15q-8 0-8-7V15q0-7 8-7z" fill="{bg}"/><path d="M15 8q-7 1-7 7t7 7V8m33 48q8-1 8-7t-8-7v14M15 8h32M16 56h32" fill="none" stroke="{fg}" stroke-width="2.5"/>'
    if cls == "spiritualist":
        return f'<path d="M32 3C42 2 44 10 50 12S59 23 57 31 62 44 52 48 44 62 34 59 21 62 17 54 4 49 7 39 1 26 10 19 16 8 24 8Z" fill="{bg}"/><path d="M15 10q16-10 32 5M53 48q-16 16-33 6" fill="none" stroke="{fg}" stroke-width="2"/>'
    if cls in ("defender", "paladin"):
        return f'<path d="M7 7h50v24q0 20-25 29Q7 51 7 31Z" fill="{bg}"/><path d="M10 11h44M10 34q2 14 22 23 20-9 22-23" fill="none" stroke="{fg}" stroke-width="2"/>'
    if cls == "berserker":
        return f'<path d="M6 12 15 4 32 7 49 4 58 12 55 31 59 50 49 59 32 56 15 59 5 50 9 31Z" fill="{bg}"/><path d="M7 14 15 7M57 49l-8 7" stroke="{fg}" stroke-width="3"/>'
    if cls == "hunter":
        return f'<path d="M5 31Q11 5 38 5L59 12Q57 49 28 59L6 52Z" fill="{bg}"/><path d="M9 49q0-30 28-39M54 16q-3 25-23 36" fill="none" stroke="{fg}" stroke-width="2"/>'
    if cls == "geometer":
        return f'<path d="M32 3 61 57H3Z" fill="{bg}"/><path d="M27 9 7 52h50L37 9" fill="none" stroke="{fg}" stroke-width="2"/>'
    if cls == "sentinel":
        return f'<rect x="4" y="4" width="56" height="56" rx="8" fill="{bg}"/><path d="M7 18V7h11M46 7h11v11M7 46v11h11M46 57h11V46" fill="none" stroke="{fg}" stroke-width="2.5"/>'
    if cls == "arcane_blade":
        return f'<path d="M20 4h24l16 16v24L44 60H20L4 44V20z" fill="{bg}"/><path d="M21 8h22l13 13M8 43l13 13M43 56l13-13" fill="none" stroke="{fg}" stroke-width="2.5"/>'
    if cls == "archer":
        return f'<path d="M5 10h40L60 32 45 54H5Z" fill="{bg}"/><path d="M8 13h35M8 51h35m7-9 7-10-7-10" fill="none" stroke="{fg}" stroke-width="2"/>'
    return f'<rect x="4" y="4" width="56" height="56" rx="4" fill="{bg}"/><path d="M7 18V7h11M46 7h11v11M7 46v11h11M46 57h11V46" fill="none" stroke="{fg}" stroke-width="2"/>'


def _tile(skill_id: str, cls: str, category: str, bg: str, fg: str, acc: str) -> str:
    """One complete tile (frame + glyph) with the given colours."""
    shape = SHAPES[SPECIAL[skill_id]].replace("currentColor", fg).replace("@bg", bg).replace("@acc", acc)
    # Passive glyphs are contour-only; active glyphs use solid silhouettes.
    paint = 'fill="none" stroke="%s" stroke-width="3"' % fg if category == "passive" else 'fill="%s" stroke="%s"' % (fg, fg)
    xf = "translate(6.4 6.4) scale(.8)" if cls == "priest" and category != "passive" else "translate(4 4) scale(.875)"  # round tile: more margin
    return (f'{_frame(cls, category, bg, fg, acc)}\n'
            f'  <g {paint} stroke-linecap="round" stroke-linejoin="round" transform="{xf}">{shape}</g>')


def svg_for(skill_id: str, cls: str, category: str) -> str:
    glyph = SPECIAL.get(skill_id)
    if glyph is None or glyph not in SHAPES:
        raise ValueError(f"No original glyph defined for {skill_id}")
    pal = PALETTES[cls]
    bg, fg, acc = pal["background"], pal["silhouette"], pal.get("accent", pal["silhouette"])
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" shape-rendering="geometricPrecision">'
    if cls == "acolyte":
        # Light (gold on plum) on the left half, shadow (plum on gold) on the right half.
        return (f'{head}\n'
                '  <defs><clipPath id="lt"><rect x="0" y="0" width="32" height="64"/></clipPath>'
                '<clipPath id="sh"><rect x="32" y="0" width="32" height="64"/></clipPath></defs>\n'
                f'  <g clip-path="url(#lt)">\n  {_tile(skill_id, cls, category, bg, fg, acc)}\n  </g>\n'
                f'  <g clip-path="url(#sh)">\n  {_tile(skill_id, cls, category, fg, bg, acc)}\n  </g>\n'
                '</svg>\n')
    return f'{head}\n  {_tile(skill_id, cls, category, bg, fg, acc)}\n</svg>\n'


def build(write: bool) -> dict:
    ids = ids_from_catalog()
    if len(set(SPECIAL.values())) != len(SPECIAL):
        raise ValueError("Every skill needs a distinct motif")
    if len(ids) != len(SPECIAL):
        missing = sorted(set(ids) - SPECIAL.keys())
        extra = sorted(SPECIAL.keys() - set(ids))
        raise ValueError(f"Catalog/glyph mismatch ({len(ids)} ids, {len(SPECIAL)} motifs); missing={missing}, extra={extra}")
    # Exact kit lists: 28 (E09) + 22 (E10a) = 50, each ID once, each present in the icon ID set.
    kit = {"E09": HYBRID_IDS, "E10a": E10A_IDS}
    for name, expected in EXPECTED_KIT_COUNTS.items():
        if len(kit[name]) != expected or len(set(kit[name])) != expected:
            raise ValueError(f"{name} kit list must hold exactly {expected} distinct IDs, found {len(kit[name])}")
    if len(set(HYBRID_IDS) | set(E10A_IDS)) != sum(EXPECTED_KIT_COUNTS.values()):
        raise ValueError("E09 and E10a kit lists overlap")
    if not (set(HYBRID_IDS) | set(E10A_IDS)) <= set(ids):
        raise ValueError("kit IDs missing from the icon ID set")
    entries = []
    for skill_id in ids:
        cls, category = class_for(skill_id), category_for(skill_id)
        svg = svg_for(skill_id, cls, category)
        digest = hashlib.sha256(svg.encode()).hexdigest()
        entries.append({"id": skill_id, "category": category, "class": cls, "palette": PALETTES[cls], "sha256": digest})
        if write:
            (OUT / f"{skill_id}.svg").write_text(svg, encoding="utf-8", newline="\n")
    return {"schema": 1, "source": "ClassCatalog + SentinelTuning.SKILL_IDS + HunterTuning.SKILL_IDS + ItemSkillAdapters.IDS + E09 HYBRID_SKILLS + E10a E10A_SKILLS", "canvas": [64, 64], "entries": entries}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate catalog and existing generated outputs without writing")
    args = parser.parse_args()
    if not args.check:
        OUT.mkdir(parents=True, exist_ok=True)
    manifest = build(write=not args.check)
    if not args.check:
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        readme = OUT / "README.md"
        section = (
            "\n\n## Ícones de habilidades E06\n\n"
            f"Lote original de {len(manifest['entries'])} símbolos vetoriais em 64×64, gerados por `tools/prepare_skill_icons.py`. "
            "A API de runtime consome `res://assets/art/skills/<skill_id>.svg`. Cada asset usa fundo e silhueta em duas cores; "
            "passivas usam contorno. Motivos são desenhados por primitivas SVG e diferenciados por skill e classe.\n\n"
            "`manifest.json` registra ID, categoria, classe, paleta e SHA-256 do conteúdo SVG. Para reproduzir, execute o gerador "
            "na raiz do repositório; `--check` confere catálogo e cobertura sem gravar. Os IDs vêm do ClassCatalog e das listas "
            "Sentinel/Hunter; os IDs de ItemSkillAdapters reutilizam os motivos catalogados.\n"
        )
        current = readme.read_text(encoding="utf-8-sig") if readme.exists() else ""
        if "## Ícones de habilidades E06" not in current:
            readme.write_text(current.rstrip() + section, encoding="utf-8", newline="\n")
            current = readme.read_text(encoding="utf-8-sig")
        if "## Ícones das híbridas E09" not in current:
            e09 = (
                "\n\n## Ícones das híbridas E09\n\n"
                "28 ícones SVG 64×64 das quatro híbridas (Paladino `paladin_`, Taumaturgo `thaumaturge_`, Duelista `duelist_`, "
                "Lâmina Arcana `arcane_blade_`; IDs do contrato `docs/epics/e09_contract.md`), gerados pelo mesmo script. "
                "Paletas de duas cores por classe, a partir das fichas; passivas com contorno. Enquanto o `ClassCatalog` não registra "
                "essas skills, o gerador e o `--check` as cobrem pela lista explícita `HYBRID_SKILLS`. "
                "Um ícone pintado que vier depois substitui o SVG pelo mesmo ID. "
                "Prancha de revisão: `docs/epics/e09/t3_icons_review.png`.\n"
            )
            readme.write_text(current.rstrip() + e09, encoding="utf-8", newline="\n")
            current = readme.read_text(encoding="utf-8-sig")
        if "## Ícones da família Acólito E10a" not in current:
            e10a = (
                "\n\n## Ícones da família Acólito E10a\n\n"
                "22 ícones SVG 64×64: base Acólito (`acolyte_`, 8), Sacerdote (`priest_`, 7) e Cultista (`cultist_`, 7); IDs do contrato "
                "`docs/epics/e10a_contract.md` §1, gerados pelo mesmo script e cobertos pelo `--check` por lista exata (`E10A_SKILLS`). "
                "A base divide o ladrilho ao meio com as cores trocadas (luz dourada sobre ameixa, sombra ameixa sobre dourado); o Sacerdote "
                "usa azul-céu, marfim e dourado pálido com moldura circular; o Cultista, preto-azulado, magenta e turquesa. Passivas com contorno. "
                "Um PNG pintado em `painted/<id>.png` substitui o SVG pelo mesmo ID. Prancha de revisão: `docs/epics/e10a/t3_icons_review.png`.\n"
            )
            readme.write_text(current.rstrip() + e10a, encoding="utf-8", newline="\n")
    else:
        have = {e["id"] for e in manifest["entries"]}
        missing_kit = sorted((set(HYBRID_IDS) | set(E10A_IDS)) - have)
        if missing_kit:
            raise SystemExit(f"Kit icons missing from manifest: {missing_kit}")
        print(f"kit IDs checked by exact list: E09={len(HYBRID_IDS)} E10a={len(E10A_IDS)} total={len(HYBRID_IDS) + len(E10A_IDS)}")
        for entry in manifest["entries"]:
            file = OUT / f"{entry['id']}.svg"
            if not file.exists() or hashlib.sha256(file.read_bytes()).hexdigest() != entry["sha256"]:
                raise SystemExit(f"Missing or stale: {file}")
    if PENDING_ICON_IDS:
        print("catalog skills without icon (outside T3, not generated):", ", ".join(sorted(PENDING_ICON_IDS)))
    print(f"{len(manifest['entries'])} icons; active={sum(e['category']=='active' for e in manifest['entries'])}; passive={sum(e['category']=='passive' for e in manifest['entries'])}")

if __name__ == "__main__":
    main()
