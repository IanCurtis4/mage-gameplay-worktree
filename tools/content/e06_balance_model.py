"""Offline E06 tuning proposal, not production loot or StatCalculator."""
from __future__ import annotations
from collections import Counter
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
QUALITIES = ("common", "uncommon", "rare", "epic", "legendary")
# Proposed effective weights; probabilities below are absolute per occurrence.
PROFILES = {
    "normal": {"equipment": "0.04", "card": "0.01", "quality": (790, 200, 9, 1, 0)},
    "rare": {"equipment": "1", "card": "0.03", "quality": (0, 900, 90, 10, 0)},
    "elite": {"equipment": "0.12", "card": "0.03", "quality": (790, 200, 9, 1, 0)},
    "rare_elite": {"equipment": "1", "card": "0.08", "quality": (0, 0, 900, 100, 0)},
    "boss": {"equipment": "1", "card": "0.20", "quality": (0, 0, 0, 980, 20)},
}
SOCKET_WEIGHTS = (60, 25, 10, 4, 1)
CARD_BUILD_CADENCE = {"normal": "0.02", "rare": "0.06", "elite": "0.08", "rare_elite": "0.16", "boss": "0.40"}
FLOORS = {"rare": "uncommon", "rare_elite": "rare", "boss": "epic"}
QUALITY_FACTORS = dict(zip(QUALITIES, (F(1), F("1.15"), F("1.35"), F("1.65"), F(2))))

def inventory():
    entries = []
    for path in sorted((ROOT / "resources/build_effects/equipment").glob("*.tres")):
        raw = path.read_text(encoding="utf-8")
        body = raw.split("[resource]")[-1]
        def field(name, default):
            match = re.search(r"^" + re.escape(name) + r" = (.+)$", body, re.M)
            return match.group(1).strip('&"') if match else default
        entries.append({"id": field("id", ""), "quality": field("quality_id", ""),
                        "ilvl": int(field("item_level", "0")),
                        "has_non_stat_kind": any(int(v) != 0 for v in re.findall(r"^kind = (\d+)$", raw, re.M)),
                        "set_id": field("set_id", ""), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    return entries

def exact(value):
    return {"fraction": str(value), "decimal": float(value)}

def report():
    checks = 0
    def check(condition):
        nonlocal checks
        checks += 1
        if not condition:
            raise AssertionError("Offline balance invariant failed")
    rows = {}
    for category, row in PROFILES.items():
        chance = F(row["equipment"])
        card = F(row["card"])
        weights = row["quality"]
        check(0 <= chance <= 1 and 0 <= card <= 1)
        check(sum(weights) == 1000 and all(w >= 0 for w in weights))
        check(category == "boss" or weights[-1] == 0)
        if category in FLOORS:
            check(chance == 1)
            check(all(w == 0 for w in weights[:QUALITIES.index(FLOORS[category])]))
        absolute = {q: chance * F(w, 1000) for q, w in zip(QUALITIES, weights)}
        check(sum(absolute.values()) == chance)
        rows[category] = {"equipment_probability": exact(chance), "card_probability": exact(card),
                          "no_equipment_probability": exact(1 - chance),
                          "quality_weights_conditional": dict(zip(QUALITIES, weights)),
                          "absolute_equipment_probability": {q: exact(v) for q, v in absolute.items()}}
    check(sum(SOCKET_WEIGHTS) == 100)
    check(all(SOCKET_WEIGHTS[i] > SOCKET_WEIGHTS[i + 1] for i in range(4)))
    # Independent joint distributions; ineligible hosts have exactly zero sockets.
    socket_mean = sum(F(i * w, 100) for i, w in enumerate(SOCKET_WEIGHTS))
    for category, row in rows.items():
        chance = F(PROFILES[category]["equipment"])
        for quality in QUALITIES:
            pq = F(row["absolute_equipment_probability"][quality]["fraction"])
            check(sum(pq * F(w, 100) for w in SOCKET_WEIGHTS) == pq)
        check(sum(F(v["fraction"]) for v in row["absolute_equipment_probability"].values()) == chance)
    scenarios = []
    for count in (20, 60, 120):
        kills = {"normal": count - 5, "rare": 1, "elite": 2, "rare_elite": 1, "boss": 1}
        equipment = sum(n * F(PROFILES[c]["equipment"]) for c, n in kills.items())
        cards = sum(n * F(PROFILES[c]["card"]) for c, n in kills.items())
        no_card = F(1)
        for c, n in kills.items():
            no_card *= (1 - F(PROFILES[c]["card"])) ** n
        quality = {q: sum(n * F(rows[c]["absolute_equipment_probability"][q]["fraction"]) for c, n in kills.items()) for q in QUALITIES}
        check(sum(quality.values()) == equipment)
        check(0 <= 1 - no_card <= 1)
        build_cards = sum(n * F(CARD_BUILD_CADENCE[c]) for c, n in kills.items())
        build_no_card = F(1)
        for c, n in kills.items():
            build_no_card *= (1 - F(CARD_BUILD_CADENCE[c])) ** n
        check(build_cards > cards and 1 - build_no_card > 1 - no_card)
        check(all(F(CARD_BUILD_CADENCE[c]) < F(PROFILES[c]["equipment"]) for c in kills))
        scenarios.append({"label": "hypothetical_" + str(count) + "_kills", "counts": kills,
                          "equipment_expected": exact(equipment), "cards_expected": exact(cards),
                          "at_least_one_card_probability": exact(1 - no_card),
                          "recommended_build_card_cadence": {"cards_expected": exact(build_cards), "at_least_one_card_probability": exact(1 - build_no_card)},
                          "expected_equipment_by_quality": {q: exact(v) for q, v in quality.items()},
                          "augment_opportunities_assumed": 6,
                          "assumptions": ["Not current two-encounter/six-mob arena or authorized campaign",
                                          "Every species has a valid card recipe; current demo species do not",
                                          "All loot collected; no death/abandonment; independent rolls; no pity or reroll"]})
    progression = []
    for ilvl in (1, 5, 10, 20, 30):
        factor = F(1) + F("0.04") * (ilvl - 1)
        check(factor >= 1)
        progression.append({"ilvl": ilvl, "level_factor": exact(factor),
                            "reference_rare_defense_4_by_quality": {
                                q: exact(4 * factor * QUALITY_FACTORS[q] / QUALITY_FACTORS["rare"]) for q in QUALITIES}})
    for a, b in zip(progression, progression[1:]):
        check(F(b["level_factor"]["fraction"]) > F(a["level_factor"]["fraction"]))
    entries = inventory()
    check(len(entries) == 37 and all(e["ilvl"] == 1 for e in entries))
    return {"scope": "offline_unapproved_tuning_proposal", "runtime_activated": False,
            "model_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "catalog_equipment": entries, "nominal_quality_counts": dict(Counter(e["quality"] for e in entries)),
            "profiles": rows, "recommended_card_cadence_probabilities": {k: exact(F(v)) for k, v in CARD_BUILD_CADENCE.items()}, "socket_weights_conditional_on_eligible_equipment": list(SOCKET_WEIGHTS),
            "expected_sockets_per_eligible_drop": exact(socket_mean), "scenarios": scenarios,
            "progression_points_only_example": progression,
            "quality_factors_proposed": {q: exact(v) for q, v in QUALITY_FACTORS.items()},
            "scaling_exclusions": ["ratio/reduction multipliers", "ASPD/index", "proc", "skill rule", "active rank", "kit policy", "set bonus", "family limits", "cards", "augments"],
            "invariant_checks": checks,
            "limitations": ["Not a global power budget or canonical final stat/damage calculator",
                            "No actual mob exposure, kill speed, player build, inventory lifetime or combat balancing",
                            "No epic/legendary authored recipe inferred from weights",
                            "Fraction example must resolve before StatCalculator; does not bypass stat thresholds/caps",
                            "No production enablement or mutation of the 83 catalog resources"]}

if __name__ == "__main__":
    data = report()
    output = ROOT / "docs/epics/e06/e06_balance_projection.json"
    output.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("E06_BALANCE_MODEL_OK checks=" + str(data["invariant_checks"]))
    print(json.dumps({"quality_counts": data["nominal_quality_counts"],
                      "scenarios": [{"label": s["label"], "equipment": s["equipment_expected"]["decimal"],
                                     "cards": s["cards_expected"]["decimal"], "card_available": s["at_least_one_card_probability"]["decimal"], "recommended_cards": s["recommended_build_card_cadence"]["cards_expected"]["decimal"], "recommended_card_available": s["recommended_build_card_cadence"]["at_least_one_card_probability"]["decimal"]} for s in data["scenarios"]]}))
