"""Independent design oracle; never loaded by the game or personal saves.

Generate deterministic numeric evidence before changing progression/runtime.
Only standard-library dependencies; all output belongs to this worktree.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = ("str", "agi", "vit", "int", "dex", "luk")
ORIGINS = {
    "swordsman": (8, 5, 8, 2, 5, 2),
    "mage": (2, 5, 5, 9, 7, 2),
    "archer": (3, 7, 5, 2, 10, 3),
}
LEVELS = (5, 10, 15, 20, 30)
ROLES = {
    "melee": ("swordsman", ("str", "vit", "dex", "agi")),
    "mage": ("mage", ("int", "dex", "vit", "agi")),
    "sentinel_critical": ("archer", ("dex", "luk", "agi", "vit")),
    "sentinel_caster": ("archer", ("int", "dex", "vit", "agi")),
}
PATTERNS = {
    "concentrated": (1,),
    "two": (0.7, 0.3),
    "splash_three": (0.7, 0.2, 0.1),
    "splash_four": (0.6, 0.2, 0.1, 0.1),
    "balanced": (1, 1, 1, 1, 1, 1),
}


def step_cost(permanent: int) -> int:
    assert 1 <= permanent < 60
    return 2 + (permanent - 1) // 10


def cost(base: int, increments: int) -> int:
    return sum(step_cost(n) for n in range(base, base + increments))


def grant(source_level: int) -> int:
    return 13 + (source_level + 1) // 5


def budget(level: int) -> int:
    return sum(grant(n) for n in range(1, level))


def derived(values: tuple | list, level: int, proposed: bool = True) -> dict:
    s, a, v, i, d, k = values
    result = {
        "max_hp": 100 + 10*v + 8*(level-1),
        "max_sp": 40 + 5*i + 3*(level-1),
        "hp_regen": 0.5 + 0.05*v,
        "sp_regen": 2 + 0.12*i,
        "melee_attack": 10 + 2*s + 0.4*d,
        "precision_attack": 10 + 2*d + 0.4*s,
        "magic_attack": 10 + 2*i + 0.4*d,
        "physical_defense": 2*v + 0.5*s,
        "magic_defense": 2*i + 0.5*v,
        "hit_rating": 100 + level + 2*d + 0.2*k,
        "flee_rating": 100 + level + 1.5*a + 0.2*k,
        "crit_chance": 0.05 + 0.003*k + 0.0005*d,
        "crit_resistance": 0.0,
        "attacks_per_second": 1 + 0.015*a + 0.005*d,
        "variable_cast_multiplier": 1 - 0.003*d - 0.001*i,
        "move_speed": 220.0,
    }
    if proposed:
        f = math.floor
        result["max_hp"] += 20*f(v/10)
        result["max_sp"] += 5*f(i/10)
        result["hp_regen"] += 0.2*f(v/5)
        result["sp_regen"] += 0.2*f(i/6)
        result["melee_attack"] += f(s/10)**2
        result["precision_attack"] += f(d/10)**2
        result["magic_attack"] += 0.25*(f(i/5)**2 + f(i/7)**2)
        result["physical_defense"] += 2*f(v/10)
        result["magic_defense"] += 2*f(i/10)
        result["hit_rating"] += 2*f(d/10)
        result["flee_rating"] += 2*f(a/10)
        result["crit_chance"] += 0.002*f(k/5)
        result["crit_resistance"] += 0.002*f(k/5)
        result["attacks_per_second"] += 0.02*f(a/10)
        result["variable_cast_multiplier"] -= 0.01*f(d/10)
    result["crit_chance"] = min(0.75, max(0, result["crit_chance"]))
    result["crit_resistance"] = min(0.5, max(0, result["crit_resistance"]))
    result["attacks_per_second"] = min(4, max(0.2, result["attacks_per_second"]))
    result["variable_cast_multiplier"] = min(2, max(0.25, result["variable_cast_multiplier"]))
    result["attack_speed_index"] = 100*result["attacks_per_second"]
    return result


def allocate(origin: str, ordered: tuple, pattern: str, level: int, proposed: bool) -> tuple:
    initial = ORIGINS[origin]
    weights = PATTERNS[pattern]
    chosen = IDS if pattern == "balanced" else ordered[:len(weights)]
    allocation = [0]*6
    remaining = budget(level) if proposed else 3*(level-1)
    # Weighted waterfill of invested primary increments, NOT equal money spent.
    # A strict concentrated build leaves money unspent once its one stat is capped.
    while True:
        candidates = []
        for priority, (stat, weight) in enumerate(zip(chosen, weights)):
            n = IDS.index(stat)
            if initial[n] + allocation[n] >= 60:
                continue
            price = step_cost(initial[n]+allocation[n]) if proposed else 1
            if price <= remaining:
                candidates.append((allocation[n]/weight, priority, n, price))
        if not candidates:
            break
        _, _, n, price = min(candidates)
        allocation[n] += 1
        remaining -= price
    return tuple(initial[n]+allocation[n] for n in range(6)), remaining


def worst_legacy(origin: str) -> list:
    """Exact bounded knapsack; each valid old allocation is covered, not sampled."""
    dp = [(0, (0,)*6)] + [(-10**9, ())]*87
    for index, base in enumerate(ORIGINS[origin]):
        cumulative = [cost(base, a) for a in range(61-base)]
        nxt = []
        for total in range(88):
            best = (-10**9, ())
            for a in range(min(total, len(cumulative)-1)+1):
                prior, vector = dp[total-a]
                if prior < 0:
                    continue
                candidate = prior+cumulative[a]
                if candidate > best[0]:
                    new_vector = list(vector)
                    new_vector[index] = a
                    best = (candidate, tuple(new_vector))
            nxt.append(best)
        dp = nxt
    return dp


def skill_sample(p: tuple, stats: dict) -> dict:
    # R1 from unchanged catalog: slash1.45/15SP/4s; fireball1.8/18SP/2.5s/0.32var.
    # Sentinel R1 raw local formulas stay INT-only or INT+DES; no new MATK leakage.
    i, d = p[3], p[4]
    cd_factor = 1 - 0.25*d/(d+100)
    return {
        "slash_r1_raw": 1.45*stats["melee_attack"],
        "fireball_r1_raw": 1.8*stats["magic_attack"],
        "fireball_r1_cast_s": 0.32*stats["variable_cast_multiplier"],
        "headshot_r1_raw": 2*stats["precision_attack"],
        "piercing_r1_raw": 10 + 2*i + 1.4*d,
        "net_r1_raw": 20 + 1.2*i,
        "explosive_r1_raw": 45 + 3*i,
        "piercing_r1_cd_s": 5*cd_factor,
        "net_r1_cd_s": 10*cd_factor,
        "explosive_r1_cd_s": 7*cd_factor,
        "fireball_full_sp_casts": int(stats["max_sp"]//18),
        "fireball_sp_recovery_s": 18/stats["sp_regen"],
    }


def render_csv(rows: list[dict]) -> str:
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue()


def evidence() -> dict[str, str]:
    migration, builds, marginal, thresholds = [], [], [], []
    fixtures = []
    for origin in ORIGINS:
        dp = worst_legacy(origin)
        for level in range(1, 31):
            amount = 3*(level-1)
            maximum, allocation = dp[amount]
            assert maximum <= budget(level), (origin, level, maximum, budget(level))
            assert sum(allocation) == amount
            assert all(b+a <= 60 for b, a in zip(ORIGINS[origin], allocation))
            migration.append(dict(origin=origin, level=level, old_increments=amount,
                                  worst_new_cost=maximum, new_budget=budget(level),
                                  minimum_remaining=budget(level)-maximum,
                                  allocations="/".join(map(str, allocation))))
    for role, (origin, order) in ROLES.items():
        for level in LEVELS:
            for pattern in PATTERNS:
                for version in ("old", "proposed"):
                    proposed = version == "proposed"
                    primary, left = allocate(origin, order, pattern, level, proposed)
                    stats = derived(primary, level, proposed)
                    row = dict(role=role, origin=origin, level=level, pattern=pattern,
                               version=version, primary="/".join(map(str, primary)),
                               budget=budget(level) if proposed else 3*(level-1), remaining=left)
                    row.update(stats)
                    row.update(skill_sample(primary, stats))
                    builds.append(row)
                    if not proposed:
                        continue
                    fixtures.append(dict(origin=origin, level=level,
                                         allocations=dict(zip(IDS, [p-b for p,b in zip(primary, ORIGINS[origin])])),
                                         spent=budget(level)-left, expected=stats))
                    for n, stat in enumerate(IDS):
                        if primary[n] >= 60:
                            continue
                        next_primary = list(primary)
                        next_primary[n] += 1
                        next_stats = derived(next_primary, level)
                        price = step_cost(primary[n])
                        item = dict(role=role, level=level, pattern=pattern, stat=stat,
                                    permanent=primary[n], cost=price)
                        item.update({"gain_per_point_"+key: (next_stats[key]-stats[key])/price for key in stats})
                        marginal.append(item)
    # Each actual derived milestone at/below investment cap: immediately before/on/after.
    # Effective-only >60 samples model modifier crossings, not forced clamp activation.
    periods = {"str": (10,), "agi": (10,), "vit": (5,10),
               "int": (5,6,7,10), "dex": (10,), "luk": (5,)}
    for n, stat in enumerate(IDS):
        marks = sorted({p*k for p in periods[stat] for k in range(1, 120//p+1)})
        for mark in marks:
            for value in (mark-1, mark, min(120, mark+1)):
                primary = [8,5,8,2,5,2]
                primary[n] = value
                row = dict(stat=stat, milestone=mark, value=value,
                           next_cost=step_cost(value) if 1 <= value < 60 else "cap_or_modifier_only")
                row.update(derived(primary, 10))
                thresholds.append(row)
    levels = [dict(level=l, xp=100*(l-1)+25*(l-1)*(l-2)//2,
                   gained_from_previous=grant(l-1) if l>1 else 0,
                   budget=budget(l), old_budget=3*(l-1)) for l in range(1,31)]
    prices = [dict(current=v, next=v+1, cost=step_cost(v)) for v in range(1,60)]
    return {
        "docs/fixtures/stat_threshold_levels.csv": render_csv(levels),
        "docs/fixtures/stat_threshold_costs.csv": render_csv(prices),
        "docs/fixtures/stat_threshold_migration.csv": render_csv(migration),
        "docs/fixtures/stat_threshold_builds.csv": render_csv(builds),
        "docs/fixtures/stat_threshold_marginals.csv": render_csv(marginal),
        "docs/fixtures/stat_threshold_milestones.csv": render_csv(thresholds),
        "docs/fixtures/stat_threshold_reference.json": json.dumps({
            "ruleset_id": "stat_thresholds_v1", "catalog_version": 7,
            "kind": "independent_design_oracle_not_runtime", "builds": fixtures,
        }, ensure_ascii=False, indent=2)+"\n",
    }


def check_invariants() -> None:
    assert [step_cost(n) for n in (9,10,11,19,20,21,29,30,31,59)] == [2,2,3,3,3,4,4,4,5,7]
    assert cost(9,3) == 7 and cost(10,2) == 5
    for base in range(1,60):
        for total in range(61-base):
            for split in (0, total//2, total):
                assert cost(base,total) == cost(base,split)+cost(base+split,total-split)
    for n in range(6):
        previous = derived([0]*6,1)
        for value in range(1,121):
            primary = [0]*6
            primary[n] = value
            current = derived(primary,1)
            for key in current:
                if key == "variable_cast_multiplier":
                    assert current[key] <= previous[key]+1e-12
                else:
                    assert current[key] >= previous[key]-1e-12
            assert current["move_speed"] == 220
            previous = current


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Read-only determinism check")
    args = parser.parse_args()
    check_invariants()
    outputs = evidence()
    for relative, content in outputs.items():
        path = ROOT/relative
        if args.check:
            assert path.read_text(encoding="utf-8") == content, relative
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    print("PASS: 90 exact migration bounds, 200 build comparisons, 100 design oracle fixtures;")
    print("batch/unit equivalence, all effective milestones and monotonicity verified.")
    print("Design evidence only: no measured DPS, TTK or gameplay acceptance.")


if __name__ == "__main__":
    main()
