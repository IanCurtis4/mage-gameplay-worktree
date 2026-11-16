class_name FlankRules
extends RefCounted
## E09 T6 (C3) — family rules of the Assassin: sides from the target's gameplay
## facing (A3), turn and sight-break durations, own concealment, parry window,
## Sentence sources and the execution thresholds per mob category (A4).
## Contract with the numbers: docs/epics/e09/t6_contract.md. No state here.

const FRONT := &"front"
const FLANK := &"flank"
const BACK := &"back"
## cos(60°): theta <= 60° is front; cos(120°) = -0.5: theta >= 120° is back.
const FRONT_COS := 0.5
const BACK_COS := -0.5
const COS_EPSILON := 1.0e-4
## Ground distance under which the attacker overlaps the target (classified front).
const OVERLAP_EPSILON := 0.001

const TURN_OWNER := &"flank_turn"
const TURN_DURATION := 1.5
const TURN_RANGE := Vector2(0.8, 2.5)
const SIGHT_BREAK_DURATION := 1.2
const SIGHT_BREAK_RANGE := Vector2(0.5, 3.0)
const BOSS_DURATION_FACTOR := 0.6

const CONCEALMENT_DURATION := 4.0
const CONCEALMENT_RANGE := Vector2(1.5, 8.0)
## After a reveal by attack, the first marked request inside this window opens from concealment.
const OPENING_WINDOW := 0.25

const PARRY_WINDOW := 0.35
const PARRY_RANGE := Vector2(0.2, 0.6)
const UNLIMITED_CHARGES := -1

const VICTIM_MARK := &"flank_victim"
const SENTENCE_CAP := 5
const SOURCE_BACK := &"back"
const SOURCE_CONCEALMENT := &"concealment"
const SOURCE_COMBO := &"combo"
const SOURCE_DIRECT := &"direct"
const SENTENCE_GAIN := {&"back": 2, &"concealment": 2, &"combo": 2, &"direct": 1}
const EVENT_MEMORY := 128
const KILL_MEMORY := 64

const EXECUTION_PER_CHARGE := 0.40
const EXECUTION_PER_CHARGE_RANGE := Vector2(0.25, 0.60)
const BOSS := &"boss"
const NORMAL := &"normal"
## HP fraction at commit under which a full Sentence is certain death. Bosses never.
const EXECUTION_THRESHOLDS := {&"normal": 0.30, &"rare": 0.24, &"elite": 0.18, &"rare_elite": 0.12}
const LETHAL_PROBE_STEPS := 8

const BACK_GAP := 12.0
const BACK_GAP_RANGE := Vector2(4.0, 40.0)
const BACK_ANGLES_DEG: Array[float] = [0.0, 30.0, -30.0]

## Key of the flank flags inside DamageRequest.effect_snapshot (and the result copy).
const SNAPSHOT_KEY := "flank"

## Side of a ground point seen from a target at `target_ground` facing `facing_ground`.
## Height (y) is ignored; boundaries count for the stronger side (60° front, 120° back).
static func classify(target_ground: Vector3, facing_ground: Vector3, attacker_ground: Vector3) -> Dictionary:
	var facing := Vector2(facing_ground.x, facing_ground.z)
	var offset := Vector2(attacker_ground.x - target_ground.x, attacker_ground.z - target_ground.z)
	if not facing.is_finite() or not offset.is_finite() or facing.is_zero_approx():
		return {"side": FRONT, "cos": 1.0, "overlap": false, "valid": false}
	if offset.length() < OVERLAP_EPSILON:
		return {"side": FRONT, "cos": 1.0, "overlap": true, "valid": true}
	var cosine := clampf(facing.normalized().dot(offset.normalized()), -1.0, 1.0)
	var side := FLANK
	if cosine >= FRONT_COS - COS_EPSILON: side = FRONT
	elif cosine <= BACK_COS + COS_EPSILON: side = BACK
	return {"side": side, "cos": cosine, "overlap": false, "valid": true}

## Ground position of an actor: the world point, or (x, 0, y) in the flat arena.
static func ground_position(actor: CombatActor) -> Vector3:
	if not is_instance_valid(actor): return Vector3.INF
	if actor.world_motion != null and actor.world_point() != null: return actor.world_point().position
	return Vector3(actor.global_position.x, 0.0, actor.global_position.y)

## Side of `attacker` (an actor) or of a ground point, seen from `target`'s gameplay facing.
static func side_of(target: CombatActor, attacker_ground: Vector3) -> Dictionary:
	if not is_instance_valid(target) or not attacker_ground.is_finite():
		return {"side": FRONT, "cos": 1.0, "overlap": false, "valid": false}
	return classify(ground_position(target), target.gameplay_ground_facing(), attacker_ground)

static func side_between(target: CombatActor, attacker: CombatActor) -> Dictionary:
	return side_of(target, ground_position(attacker))

## Mob category of an actor (normal, rare, elite, rare_elite, boss). Duck-typed on the
## EnemyActor occurrence so this script never closes a script cycle with the actors.
static func category_of(actor: CombatActor) -> StringName:
	if not is_instance_valid(actor): return NORMAL
	var occurrence: Variant = actor.get(&"occurrence")
	if occurrence is MobOccurrence and (occurrence as MobOccurrence).category_id in MobCatalog.CATEGORIES:
		return (occurrence as MobOccurrence).category_id
	if actor.hard_controls != null and actor.hard_controls.boss: return BOSS
	return NORMAL

## HP fraction for certain death, or -1 for categories without it (boss).
static func execution_threshold(category: StringName) -> float:
	return float(EXECUTION_THRESHOLDS.get(category, -1.0))

## Duration clamped to its range, then scaled for bosses.
static func control_duration(requested: float, default_value: float, limits: Vector2, target: CombatActor) -> float:
	var value := default_value if requested < 0.0 or not is_finite(requested) else clampf(requested, limits.x, limits.y)
	return value * (BOSS_DURATION_FACTOR if category_of(target) == BOSS else 1.0)

## Flank flags carried by a request or a result ({} when the request was not marked).
static func flags_of(effect_snapshot: Dictionary) -> Dictionary:
	var flags: Variant = effect_snapshot.get(SNAPSHOT_KEY, {})
	return flags if flags is Dictionary else {}

static func result_flags(result: Dictionary) -> Dictionary:
	var snapshot: Variant = result.get("effect_snapshot", {})
	return flags_of(snapshot) if snapshot is Dictionary else {}

## Presentation flag: the actor is somebody's victim and stays visible through obstacles.
static func victim_mark(actor: CombatActor) -> Dictionary:
	if not is_instance_valid(actor) or not actor.marks.has_mark(VICTIM_MARK): return {}
	var value: Variant = actor.marks.value(VICTIM_MARK)
	return value if value is Dictionary else {}

static func see_through(actor: CombatActor) -> bool:
	return bool(victim_mark(actor).get("see_through", false))
