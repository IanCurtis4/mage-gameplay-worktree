class_name MadnessHelpers
extends RefCounted
## E10a T4 (C2) — stateless helpers of the Madness family: the owner's enemies,
## boss and enemy recognition (by method, A7), distances on both paths, event
## identities for MadnessAuthority.add and the code drawing of the Idol decoy.
## Never names MadnessAuthority (no script cycle, A7).

## Living enemies of the owner's run (RunController.enemies), or `fallback`.
static func enemies_of(owner: CombatActor, fallback: Array = []) -> Array:
	if not fallback.is_empty() or not is_instance_valid(owner): return fallback
	var parent := owner.get_parent()
	if parent == null: return []
	var listed: Variant = parent.get(&"enemies")
	return listed if listed is Array else []

## An enemy actor, recognised by method (EnemyActor), never a decoy.
static func is_enemy(actor: Object) -> bool:
	return actor != null and is_instance_valid(actor) and actor.has_method(&"set_target_override") and not KitDecoy.is_decoy(actor)

static func is_boss(actor: CombatActor) -> bool:
	return is_instance_valid(actor) and actor.hard_controls.boss

static func is_live(actor: CombatActor) -> bool:
	return is_instance_valid(actor) and actor.is_alive() and not actor.is_queued_for_deletion() and actor.is_inside_tree()

## Stable identity of an enemy for event keys: the occurrence ID (kept by the exact
## snapshot), else the instance ID.
static func enemy_key(enemy: CombatActor) -> String:
	if not is_instance_valid(enemy): return ""
	var occurrence: Variant = enemy.get(&"occurrence")
	if occurrence is MobOccurrence and not String((occurrence as MobOccurrence).occurrence_id).is_empty(): return String((occurrence as MobOccurrence).occurrence_id)
	return "actor:%d" % enemy.get_instance_id()

## Distance between two actors on the same path (flat arena or the same world), or INF.
static func distance(a: CombatActor, b: CombatActor) -> float:
	if not is_instance_valid(a) or not is_instance_valid(b): return INF
	if a.world_motion != null or b.world_motion != null:
		if a.world_motion == null or b.world_motion == null or a.world_motion.geometry != b.world_motion.geometry: return INF
		if a.world_point() == null or b.world_point() == null or a.world_point().stage_id != b.world_point().stage_id: return INF
		return a.world_distance_to(b)
	return a.global_position.distance_to(b.global_position)

## Event identity of a gain, without the target part. A CombatEventContext (or a
## dictionary carrying one) gives the EffectProcLedger identity "<root>#<event>";
## otherwise the explicit key (a String, or a dictionary "key").
static func event_identity(event: Variant) -> String:
	if event is String or event is StringName: return String(event)
	if event is CombatEventContext:
		var direct := event as CombatEventContext
		return "%s#%d" % [direct.root_event_id, direct.event_id] if not direct.root_event_id.is_empty() else ""
	if event is Dictionary:
		var context := (event as Dictionary).get("context") as CombatEventContext
		if context != null and not context.root_event_id.is_empty(): return "%s#%d" % [context.root_event_id, context.event_id]
		return String((event as Dictionary).get("key", ""))
	return ""

## Event of a confirmed damage result. A hit between enemies (Delirium relay or the
## boss deflection) is never a Madness event (C2: a Delirium kill gives no Madness).
static func result_event(result: Dictionary) -> Dictionary:
	if EnemyActor.is_relay_result(result): return {}
	return {"context": result.get("context"), "key": "result:%d:%d:%d" % [int(result.get("source_id", 0)), int(result.get("target_id", 0)), int(result.get("application_sequence", 0))]}

## Event of a committed cast (no causal context): one per skill and commit instant.
static func cast_event(cast: Dictionary, kit_time: float) -> String:
	return "cast:%s@%.5f" % [String(cast.get("skill_id", &"")), kit_time]

## Nearest live non-boss enemy to `enemy` on its path, excluding itself (Delirium).
static func nearest_non_boss(enemy: CombatActor, actors: Array) -> CombatActor:
	var best: CombatActor = null
	var best_distance := INF
	for candidate: Variant in actors:
		var other := candidate as CombatActor
		if other == null or other == enemy or not is_enemy(other) or not is_live(other) or is_boss(other): continue
		var gap := distance(enemy, other)
		if not is_finite(gap): continue
		if gap < best_distance - 0.0001 or (absf(gap - best_distance) <= 0.0001 and best != null and enemy_key(other) < enemy_key(best)):
			best = other
			best_distance = gap
	return best

## Live enemies within `radius` of `center` (an actor), center excluded, by stable key.
static func neighbours(center: CombatActor, actors: Array, radius: float) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for candidate: Variant in actors:
		var other := candidate as CombatActor
		if other == null or other == center or not is_enemy(other) or not is_live(other): continue
		if distance(center, other) <= radius: result.append(other)
	result.sort_custom(func(a: CombatActor, b: CombatActor) -> bool: return enemy_key(a) < enemy_key(b))
	return result

## Idol drawer (KitDecoy.register_drawer): an impossible eye on a broken spire, drawn in
## code (D8). Presentation only.
static func draw_idol(canvas: CanvasItem, decoy: CombatActor, remaining: float) -> void:
	if canvas == null or not is_instance_valid(decoy): return
	var t := float(Time.get_ticks_msec() % 4000) / 4000.0
	var hp := clampf(decoy.health.current_hp / maxf(1.0, decoy.health.max_hp), 0.0, 1.0)
	var shadow := Color(0.08, 0.07, 0.14, 0.92)
	var magenta := Color(0.86, 0.22, 0.62, 0.95)
	var turquoise := Color(0.32, 0.86, 0.78, 0.95)
	var base := Vector2(0, 0)
	# Spire: an open, asymmetric silhouette.
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-14, 0), base + Vector2(12, 0), base + Vector2(7, -46), base + Vector2(-3, -58), base + Vector2(-9, -40)]), shadow)
	canvas.draw_polyline(PackedVector2Array([base + Vector2(-14, 0), base + Vector2(-9, -40), base + Vector2(-3, -58), base + Vector2(7, -46), base + Vector2(12, 0)]), magenta, 1.6, true)
	# The eye opens and closes; the pupil drifts.
	var eye := base + Vector2(0, -36)
	var open := 0.45 + 0.35 * absf(sin(t * TAU))
	var lid := PackedVector2Array()
	for i: int in 17:
		var a := PI * float(i) / 16.0
		lid.append(eye + Vector2(cos(a) * 11.0, -sin(a) * 11.0 * open))
	for i: int in range(15, 0, -1):
		var a := PI * float(i) / 16.0
		lid.append(eye + Vector2(cos(a) * 11.0, sin(a) * 11.0 * open))
	canvas.draw_colored_polygon(lid, Color(0.95, 0.9, 0.82, 0.9))
	canvas.draw_circle(eye + Vector2(sin(t * TAU * 2.0) * 3.0, 0), 4.0 * open + 1.0, turquoise)
	canvas.draw_circle(eye + Vector2(sin(t * TAU * 2.0) * 3.0, 0), 1.6, shadow)
	# Spiral that never closes: the deadline.
	var spiral := PackedVector2Array()
	var turns := clampf(remaining / MadnessRules.IDOL_DURATION, 0.05, 1.0)
	for i: int in 25:
		var k := float(i) / 24.0 * turns
		spiral.append(base + Vector2(0, -6) + Vector2(cos(k * TAU * 1.5), sin(k * TAU * 1.5) * 0.45) * (10.0 + 14.0 * k))
	canvas.draw_polyline(spiral, Color(turquoise, 0.7), 1.4, true)
	# HP as a cracked ring.
	canvas.draw_arc(base + Vector2(0, -28), 30.0, -PI * 0.5, -PI * 0.5 + TAU * hp, 24, Color(magenta, 0.8), 2.0, true)
