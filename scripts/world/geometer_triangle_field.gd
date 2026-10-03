class_name GeometerTriangleField
extends RefCounted
## A/B maintenance + one C resolution. No edge effects, terrain or combat formulas.

const INTERVAL := 1.0
const SLOW_RESIDUAL := 0.6
const LINK_RANGE := 110.0
const ROOT_DURATION := 0.7
var casting: GeometerCasting
var enabled := true
var _identity := 0
var _snapshot: Dictionary = {}
var _elapsed := 0.0
var _next_tick := INTERVAL

func configure(adapter: GeometerCasting) -> void:
	casting = adapter

func clear() -> void:
	_identity = 0
	_snapshot = {}
	_elapsed = 0.0
	_next_tick = INTERVAL

func _valid_triangle() -> bool:
	if not enabled or not is_instance_valid(casting) or not is_instance_valid(casting.player) or not casting.player.is_alive() or (casting.is_inside_tree() and casting.get_tree().paused):
		return false
	casting.construction.refresh(casting.alive_positions(), casting.player.navigation)
	return casting.construction.has_active_figure() and casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE

func _active() -> bool:
	return _valid_triangle() and _identity == casting.construction.construction_id and not _snapshot.is_empty()

func form(snapshot: Dictionary = {}) -> void:
	if not _valid_triangle() or _identity == casting.construction.construction_id:
		return
	_identity = casting.construction.construction_id
	# A projectile can be born inside immediately after formation, before the next frame.
	casting.interaction_ledger.sync(_identity)
	_snapshot = snapshot if not snapshot.is_empty() else casting.player.geometer_triangle_snapshot()
	_elapsed = 0.0
	_next_tick = INTERVAL
	if _snapshot.is_empty():
		return
	# Claim closure before emitting any damage: death/clear callbacks cannot replay C.
	var element := casting.construction.elements()[2]
	resolve_captured(casting.construction.positions(), element, _snapshot[StringName("resolution_" + String(element))], _identity)

func resolve_captured(points: PackedVector2Array, element: StringName, prototype: DamageRequest, formation_identity: int = 0) -> void:
	# Also used by explicit collapse AFTER consumption. No maintenance or snapshot replay.
	var occupants := _occupants_for(points)
	var links := PackedVector2Array()
	if element == &"lightning":
		var origin := points[2]
		for index: int in range(3):
			var victim := _nearest(occupants, origin, INF if index == 0 else LINK_RANGE)
			if victim == null or not _can_resolve(formation_identity):
				break
			occupants.erase(victim)
			links.append(origin)
			links.append(victim.global_position)
			origin = victim.global_position
			_damage(prototype, victim)
	else:
		for victim: CombatActor in occupants:
			if not _can_resolve(formation_identity):
				break
			_damage(prototype, victim)
			if element == &"ice" and is_instance_valid(victim) and victim.is_alive():
				victim.apply_root(ROOT_DURATION, &"magic")
	if _can_resolve(formation_identity):
		casting.show_triangle_reaction(points, element, links)

func _can_resolve(formation_identity: int) -> bool:
	return is_instance_valid(casting.player) and casting.player.is_alive() and not (casting.is_inside_tree() and casting.get_tree().paused) and (formation_identity == 0 or (_identity == formation_identity and _active()))

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not is_instance_valid(casting) or (casting.is_inside_tree() and casting.get_tree().paused):
		return
	if _identity != casting.construction.construction_id:
		clear()
		return
	if _identity == 0:
		return
	_elapsed += delta
	var tick := _elapsed + GeometerInteractionLedger.TIME_EPSILON >= _next_tick
	if tick:
		# Keep the original one-second phase, discard missed ticks (no catch-up).
		_next_tick += (floorf(maxf(0.0, _elapsed + GeometerInteractionLedger.TIME_EPSILON - _next_tick) / INTERVAL) + 1.0) * INTERVAL
	if not _active():
		return
	var elements := casting.construction.elements()
	var slow := 0.20 if elements[1] == &"ice" else (0.10 if elements[0] == &"ice" else 0.0)
	var request: DamageRequest
	if elements[0] == &"fire":
		request = (_snapshot[&"foundation_fire"] as DamageRequest).copy()
	if elements[1] == &"fire":
		if request == null:
			request = (_snapshot[&"rule_fire"] as DamageRequest).copy()
		else:
			request.magic_damage += (_snapshot[&"rule_fire"] as DamageRequest).magic_damage
	if request != null:
		request.skill_id = &"geometer_triangle_maintenance"
	for actor: CombatActor in _occupants():
		if not _active():
			break
		if slow > 0.0:
			actor.apply_slow(slow, SLOW_RESIDUAL, &"geometer_triangle")
		if tick and request != null:
			_damage(request, actor)
	if tick and request != null and _active():
		casting.show_triangle_reaction(casting.construction.positions(), &"fire", PackedVector2Array(), 0.20)

func _occupants() -> Array[CombatActor]:
	return _occupants_for(casting.construction.positions())

func _occupants_for(points: PackedVector2Array) -> Array[CombatActor]:
	var occupants: Array[CombatActor] = []
	for actor: CombatActor in casting.targets.duplicate():
		if is_instance_valid(actor) and actor.is_alive() and actor != casting.player and _inside_visible_points(actor, points):
			occupants.append(actor)
	return occupants

func _inside_visible(actor: CombatActor) -> bool:
	return _inside_visible_points(actor, casting.construction.positions())

func _inside_visible_points(actor: CombatActor, points: PackedVector2Array) -> bool:
	return GeometerGeometry.triangle_contains(points, actor.global_position, actor.collision_radius) and casting.player.navigation.is_segment_clear((points[0] + points[1] + points[2]) / 3.0, actor.global_position, 0.0)

func _nearest(candidates: Array[CombatActor], origin: Vector2, limit: float) -> CombatActor:
	var best: CombatActor
	var distance := INF
	for actor: CombatActor in candidates:
		if not is_instance_valid(actor) or not actor.is_alive():
			continue
		var current := origin.distance_to(actor.global_position)
		if current > limit or not casting.player.navigation.is_segment_clear(origin, actor.global_position, 0.0):
			continue
		if current < distance or (is_equal_approx(current, distance) and (best == null or actor.get_instance_id() < best.get_instance_id())):
			best = actor
			distance = current
	return best

func _damage(prototype: DamageRequest, actor: CombatActor) -> void:
	if is_instance_valid(actor) and actor.is_alive():
		var request := prototype.copy()
		request.target_id = actor.get_instance_id()
		casting.hit.emit(request, actor)

func owned_contact(projectile: PlayerProjectile, from: Vector2, to: Vector2) -> Dictionary:
	if not _active() or projectile is GeometerTraceProjectile or projectile.request == null or projectile.request.is_secondary or GeometerCastCommand.is_trace_skill(projectile.request.skill_id) or projectile.request.source_id != casting.player.get_instance_id():
		return {}
	var elements := casting.construction.elements()
	var ledger := casting.interaction_ledger
	var foundation := elements[0] == &"lightning" and not ledger.projectile_claimed(projectile.get_instance_id(), GeometerInteractionLedger.Component.LIGHTNING_FOUNDATION)
	var rule := elements[1] == &"lightning" and not ledger.projectile_claimed(projectile.get_instance_id(), GeometerInteractionLedger.Component.LIGHTNING_RULE)
	if not foundation and not rule:
		return {}
	return GeometerGeometry.triangle_contact(casting.construction.positions(), from - PlayerProjectile.BODY_OFFSET, to - PlayerProjectile.BODY_OFFSET, projectile.projectile_radius)

func apply_owned_contact(projectile: PlayerProjectile) -> void:
	if not _active():
		return
	var elements := casting.construction.elements()
	var owner := casting.player.get_instance_id()
	var ledger := casting.interaction_ledger
	var transformed := false
	if elements[0] == &"lightning" and ledger.claim_owned_projectile(projectile.get_instance_id(), GeometerInteractionLedger.Component.LIGHTNING_FOUNDATION, projectile.request, owner):
		projectile.geometer_triangle_foundation_request = (_snapshot[&"foundation_lightning"] as DamageRequest).copy()
		transformed = true
	if elements[1] == &"lightning" and ledger.claim_owned_projectile(projectile.get_instance_id(), GeometerInteractionLedger.Component.LIGHTNING_RULE, projectile.request, owner):
		projectile.geometer_triangle_arc_request = (_snapshot[&"rule_lightning"] as DamageRequest).copy()
		transformed = true
	if transformed:
		projectile.geometer_triangle_identity = _identity
		casting.show_wall_reaction(projectile.global_position - PlayerProjectile.BODY_OFFSET, &"lightning")

func projectile_impact(projectile: PlayerProjectile, victim: CombatActor) -> void:
	var foundation := projectile.geometer_triangle_foundation_request
	var arc := projectile.geometer_triangle_arc_request
	var identity := projectile.geometer_triangle_identity
	projectile.geometer_triangle_foundation_request = null
	projectile.geometer_triangle_arc_request = null
	if not _active() or identity != _identity or not is_instance_valid(victim) or not _inside_visible(victim):
		return
	var origin := victim.global_position
	if foundation != null:
		_damage(foundation, victim)
	if arc == null or not _active():
		return
	var candidates := _occupants().filter(func(actor: CombatActor) -> bool: return not projectile._hit_actor_ids.has(actor.get_instance_id()))
	var neighbor := _nearest(candidates, origin, LINK_RANGE)
	if neighbor != null:
		_damage(arc, neighbor)
		casting.show_triangle_reaction(casting.construction.positions(), &"lightning", PackedVector2Array([origin, neighbor.global_position]), 0.25)
