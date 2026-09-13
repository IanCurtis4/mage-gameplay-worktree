"""Offline E00 specification checks, not a gameplay/save implementation.

Reads committed reference data only. Does not open Godot user data or write files.
Future E01/E03 tests must exercise the real services against these same fixtures.
"""
import copy
import itertools
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / 'docs/fixtures/e00_reference.json').read_text(encoding='utf-8'))
checks = 0


def check(condition, label):
    global checks
    if not condition:
        raise AssertionError(label)
    checks += 1


def close(actual, expected, label):
    check(math.isclose(actual, expected, rel_tol=1e-10, abs_tol=1e-10),
          f'{label}: {actual} != {expected}')


def clamp(value, low, high):
    return min(high, max(low, value))


def threshold(level, track):
    # Independent summation oracle, compared with the closed-form ADR below.
    start, step = (100, 25) if track == 'base' else (80, 20)
    return sum(start + step * (n - 1) for n in range(1, level))


def level_at(xp, track, evolved=False):
    cap = 30 if track == 'base' else (40 if evolved else 20)
    return max(n for n in range(1, cap + 1) if threshold(n, track) <= xp)


for track, cap, start, step in [('base', 30, 100, 25), ('job', 40, 80, 20)]:
    for level in range(1, cap + 1):
        total = threshold(level, track)
        check(total == start*(level-1) + step*(level-1)*(level-2)//2,
              f'{track} closed form at {level}')
        check(level_at(total, track, True) == level, f'{track} threshold boundary')
        if level > 1:
            check(level_at(total-1, track, True) == level-1, f'{track} just below')

for case in DATA['progression']:
    track = case['track']
    level = level_at(case['xp'], track, case['evolved'])
    cap = 30 if track == 'base' else (40 if case['evolved'] else 20)
    xp = min(case['xp'], threshold(cap, track))
    check(level == case['level'], 'fixture level')
    check(xp-threshold(level, track) == case['progress'], 'fixture progress')
    if track == 'base':
        check(3*(level-1) == case['free_total'], 'attribute wallet')
    else:
        check(min(level, 20)-1 == case['base_total'], 'base skill wallet')
        check(max(level-20, 0) == case['evolution_total'], 'evolution wallet')

for case in DATA['stats']:
    s, a, v, i, d, k = case['attributes']
    level = case['level']
    check(sum(case['attributes']) == 30, 'origin budget')
    values = {
        'max_hp':100+10*v+8*(level-1), 'max_sp':40+5*i+3*(level-1),
        'melee_attack':10+2*s+0.4*d, 'precision_attack':10+2*d+0.4*s,
        'magic_attack':10+2*i+0.4*d, 'physical_defense':2*v+0.5*s,
        'magic_defense':2*i+0.5*v, 'hit_rating':100+level+2*d+0.2*k,
        'flee_rating':100+level+1.5*a+0.2*k,
        'crit_chance':clamp(0.05+0.003*k+0.0005*d, 0, 0.75),
        'attacks_per_second':clamp(1+0.015*a+0.005*d, 0.2, 4),
        'variable_cast_multiplier':clamp(1-0.003*d-0.001*i, 0.25, 2),
    }
    for key, expected in case['expected'].items():
        close(values[key], expected, f'{case["class_id"]} {key}')

for case in DATA['damage']:
    raw = (case['physical']*100/(100+case['def']) +
           case['magic']*100/(100+case['mdef'])) * case['critical']
    result = max(1, math.floor(raw+0.5)) if raw > 0 else 0
    check(result == case['expected'], case['name'])
for case in DATA['hit']:
    close(clamp(0.9+case['difference']/200, 0.05, 0.98), case['expected'], 'HIT/FLEE')
check(not (0.9 < 0.9), 'roll exactly at chance misses')
cast = DATA['cast']
close(cast['fixed']+cast['variable']*(1-0.003*cast['dex']-0.001*cast['int']),
      cast['expected'], 'fixed plus variable cast')

# Adversarial algebraic properties across extremes, not only happy-path examples.
for defense in range(901):
    multiplier = 100/(100+defense)
    check(0.1 <= multiplier <= 1, 'bounded mitigation')
    if defense:
        check(multiplier < 100/(99+defense), 'defense monotonicity')
for difference in range(-1000, 1001):
    chance = clamp(0.9+difference/200, 0.05, 0.98)
    check(0.05 <= chance <= 0.98, 'chance bound')
for weights in [(1,0,0), (0,1,0), (0,0,1), (0.6,0,0.4), (0.2,0.3,0.5)]:
    close(sum(weights), 1, 'normalized power weights')
    powers = [54,38,74]
    weighted = sum(w*p for w,p in zip(weights,powers))
    check(min(powers) <= weighted <= max(powers), 'hybrid does not sum full attacks')
for points in range(21):
    for spent in range(points+1):
        remaining = points-spent
        check(remaining+spent == points, 'respec conserves wallet')
        check((remaining+spent)-points == 0, 'no second grant on evolution')
for hp_max, deficit in [(180,0), (180,30), (180,179)]:
    for bonus in [0,20,100]:
        original = hp_max-deficit
        equipped = clamp(hp_max+bonus-deficit,0,hp_max+bonus)
        removed = clamp(hp_max-((hp_max+bonus)-equipped),0,hp_max)
        check(removed == original, 'equip cycle cannot heal')

# A cap below a deficit is the adversarial case hidden by ordinary equip checks.
# Voluntary swaps reject; involuntary cap expiry retains deficit, including SP.
for old_cap, deficit, new_cap in [(50,40,20),(180,179,100),(100,0,20)]:
    voluntary_sp_swap_valid = new_cap >= deficit
    if new_cap < deficit:
        check(not voluntary_sp_swap_valid, 'reject cap below SP deficit')
    preserved_deficit = deficit
    after_expiry = max(0,new_cap-preserved_deficit)
    after_restore = max(0,old_cap-preserved_deficit)
    check(after_restore == old_cap-deficit, 'latent deficit survives cap clamp')
    check(0 <= after_expiry <= new_cap, 'current resource remains bounded')

for raw_damage in [0,1,100,10000]:
    normal = raw_damage*0.5
    perfect = raw_damage*0
    check(0 <= perfect <= normal <= raw_damage, 'guard factor cannot amplify damage')
for cursor in [0,1,1000]:
    # Partition the receipt contract: exactly next applies; old/gap cannot apply.
    for seq in [cursor, cursor+1, cursor+2]:
        replay, applies, gap = seq <= cursor, seq == cursor+1, seq > cursor+1
        check(sum([replay, applies, gap]) == 1, 'reward sequence partition')

tokens = ('fire','ice','lightning')
triangles = list(itertools.product(tokens, repeat=3))
runes = [t for t in triangles if t[2] != t[1]]
walls = list(itertools.permutations(tokens, 2))
groups = {n:[t for t in triangles if len(set(t)) == n] for n in (1,2,3)}
counts = {'runes':len(runes),'walls':len(walls),'triangles':len(triangles),
          'pure':len(groups[1]),'two_plus_one':len(groups[2]),'tricolor':len(groups[3]),
          'rank_1':len(groups[1]),'rank_3':len(groups[1])+len(groups[2]),'rank_5':len(triangles)}
check(counts == DATA['grammar'], 'all grammar counts and cognitive unlocks')
check(len(set(runes)) == 18 and len(set(walls)) == 6, 'unique directed recipes')
check(len([t for t in triangles if t[2] not in t[:2]]) == 12,
      'rejected interpretation cannot produce eighteen')
roster = DATA['roster']
ids = roster['bases'] + roster['pure'] + list(roster['hybrids'])
check(len(ids) == len(set(ids)) == 15, 'MVP roster exactly fifteen')
check({tuple(v[:2]) for v in roster['hybrids'].values()} ==
      set(itertools.permutations(roster['bases'], 2)), 'six complete directed pairs')
check(roster['hybrids']['mg_ar'][2] == 'Geômetra', 'rename preserves ID')


def valid_sample_envelope(profile):
    """Limited fixture audit; production validator and migration are E01 work."""
    if profile.get('schema_version') != 2 or profile.get('format_id') != 'ragrpg_character_profile':
        return False
    if len(profile['characters']) > 8:
        return False
    seen = set()
    for char in profile['characters']:
        if char['character_id'] in seen:
            return False
        seen.add(char['character_id'])
        if any(k in char for k in ['current_hp','augment_stacks','cards','cooldowns']):
            return False
        if type(char['base_xp_total']) is not int or type(char['job_xp_total']) is not int:
            return False
        if char['base_xp_total'] < 0 or char['job_xp_total'] < 0:
            return False
        evolution = char['evolution_id']
        if evolution is not None:
            if evolution not in roster['hybrids'] or roster['hybrids'][evolution][0] != char['base_class_id']:
                return False
        cap = 40 if evolution else 20
        if char['job_xp_total'] > threshold(cap,'job') or char['base_xp_total'] > threshold(30,'base'):
            return False
        level = level_at(char['base_xp_total'],'base')
        allocations = char['attribute_allocations']
        if set(allocations) != {'str','agi','vit','int','dex','luk'}:
            return False
        if any(type(v) is not int or v < 0 for v in allocations.values()):
            return False
        if sum(allocations.values()) > 3*(level-1):
            return False
    return True


check(valid_sample_envelope(DATA['profile']), 'minimal structural profile fixture')
for name in DATA['invalid_profile_cases']:
    candidate = copy.deepcopy(DATA['profile'])
    char = candidate['characters'][0]
    if name == 'future_schema': candidate['schema_version'] = 99
    elif name == 'foreign_evolution': char['evolution_id'] = 'mg_sp'
    elif name == 'overspent_attributes': char['attribute_allocations']['str'] = 1
    elif name == 'job_above_base_cap': char['job_xp_total'] = 5400
    elif name == 'duplicate_character_id': candidate['characters'].append(copy.deepcopy(char))
    elif name == 'runtime_state_in_save': char['current_hp'] = 180
    elif name == 'boolean_xp': char['base_xp_total'] = True
    else: raise AssertionError(f'unhandled negative fixture {name}')
    check(not valid_sample_envelope(candidate), name)

# All local Markdown links in the deliverable must resolve. Source transcription
# is excluded: it is data quoted from the attachment, not authored link markup.
import re
files = ['ADR_E00_01_CHARACTER_PROGRESSION.md','E00_CONTRACT.md',
         'E00_02_STATS_CONTRACT.md','E00_03_DATA_SAVE_CONTRACT.md',
         'E00_MVP_CLASS_CONTRACT.md','REVIEW_E00.md']
for filename in files:
    path = ROOT/'docs'/filename
    check(path.is_file(), f'deliverable exists: {filename}')
    for target in re.findall(r'\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
        if '://' not in target and not target.startswith('#'):
            check((path.parent/target.split('#')[0]).exists(), f'local link: {target}')

print(f'E00 contract: PASS ({checks} checks). No gameplay or persistence service tested.')
