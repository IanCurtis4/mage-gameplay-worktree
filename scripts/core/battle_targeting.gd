class_name BattleTargeting
extends RefCounted
## Shared mouse resolver for basic attacks and future single-target skills.

const BODY_OFFSET := Vector2(0, -18)
const ASSIST_RADIUS := 68.0
const LOCK_RADIUS := 80.0
const DIRECT_PADDING := 4.0

static func pick(point: Vector2, actors: Array[CombatActor], previous: CombatActor = null, assist: bool = true) -> CombatActor:
	var direct: CombatActor
	var nearby: CombatActor
	var direct_distance := INF
	var nearby_distance := INF
	for actor: CombatActor in actors:
		if not is_instance_valid(actor) or not actor.is_alive():
			continue
		var distance := point.distance_to(actor.global_position + BODY_OFFSET)
		if distance <= actor.collision_radius + DIRECT_PADDING and distance < direct_distance:
			direct = actor
			direct_distance = distance
		elif assist and distance <= ASSIST_RADIUS and distance < nearby_distance:
			nearby = actor
			nearby_distance = distance
	if direct != null:
		return direct
	if assist and is_instance_valid(previous) and previous.is_alive() and actors.has(previous):
		if point.distance_to(previous.global_position + BODY_OFFSET) <= LOCK_RADIUS:
			return previous
	return nearby
