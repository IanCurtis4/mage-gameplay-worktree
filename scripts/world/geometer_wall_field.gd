class_name GeometerWallField
extends RefCounted
## Six ordered walls. No terrain obstacle, triangle maintenance or damage formula.

const PULSE_RADIUS := 45.0
const REDIRECT_RANGE := 110.0 # Initial tuning, bounded around B; not global auto-aim.
var casting: GeometerCasting
var enabled := true
var _identity := 0
var _snapshot: Dictionary = {}

func configure(adapter: GeometerCasting) -> void:
	casting = adapter
	casting.wall_crossed.connect(on_crossed)

func capture_construction(snapshot: Dictionary = {}) -> void:
	var identity := casting.construction.construction_id
	if identity == _identity:
		return
	_identity = identity
	_snapshot = (snapshot if not snapshot.is_empty() else casting.player.geometer_wall_snapshot()) if identity > 0 else {}

func _available() -> bool:
	if not enabled or not is_instance_valid(casting) or not is_instance_valid(casting.player) or not casting.player.is_alive() or (casting.is_inside_tree() and casting.get_tree().paused):
		return false
	casting.construction.refresh(casting.alive_positions(), casting.player.navigation)
	capture_construction()
	return not _snapshot.is_empty() and casting.construction.has_active_figure() and casting.construction.shape == GeometerConstructionState.Shape.WALL

func on_crossed(contact: Dictionary, actor: CombatActor) -> void:
	if not _available() or contact.get("construction_id", 0) != _identity or not is_instance_valid(actor) or not actor.is_alive():
		return
	var elements := casting.construction.elements()
	var first := elements[0]
	var second := elements[1]
	if first == &"lightning" and second == &"ice":
		return # R/G has no actor effect and cannot consume its victim window.
	var center: Vector2 = contact["wall_point"]
	var candidates: Array[CombatActor] = [actor]
	if second == &"fire":
		for victim: CombatActor in casting.targets.duplicate():
			if is_instance_valid(victim) and victim.is_alive() and victim != actor and center.distance_to(victim.global_position) <= PULSE_RADIUS + victim.collision_radius:
				candidates.append(victim)
	var identity := _identity
	var affected := false
	for victim: CombatActor in candidates:
		if casting.construction.construction_id != identity or not casting.player.is_alive():
			break
		if not is_instance_valid(victim) or not victim.is_alive() or not casting.player.navigation.is_segment_clear(center, victim.global_position, 0.0) or not casting.interaction_ledger.claim_victim(victim.get_instance_id()):
			continue
		affected = true
		if victim == actor and first == &"ice":
			victim.apply_slow(_snapshot["slow_fraction"], 2.0, &"geometer_wall")
		var prototype: DamageRequest = _snapshot["entry_request"] if first == &"fire" else (_snapshot["exit_request"] if second == &"fire" else null)
		if prototype != null:
			var request := prototype.copy()
			request.target_id = victim.get_instance_id()
			casting.hit.emit(request, victim)
	if affected:
		casting.show_wall_reaction(center, &"fire" if first == &"fire" or second == &"fire" else &"ice")

func conduction_active(identity: int) -> bool:
	return _available() and identity == casting.construction.construction_id

func owned_contact(projectile: PlayerProjectile, from: Vector2, to: Vector2) -> Dictionary:
	if is_instance_valid(casting) and casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE:
		return casting.triangle_field.owned_contact(projectile, from, to)
	if not _available() or projectile is GeometerTraceProjectile or projectile.request == null or projectile.request.is_secondary or GeometerCastCommand.is_trace_skill(projectile.request.skill_id) or projectile.request.source_id != casting.player.get_instance_id():
		return {}
	var elements := casting.construction.elements()
	var ledger := casting.interaction_ledger
	var transport := (elements[0] == &"lightning" or elements[1] == &"lightning") and not ledger.projectile_claimed(projectile.get_instance_id(), GeometerInteractionLedger.Component.TRANSPORT)
	var fire := elements[1] == &"fire" and not ledger.projectile_claimed(projectile.get_instance_id(), GeometerInteractionLedger.Component.FIRE_EXIT)
	if not transport and not fire:
		return {}
	var points := casting.construction.positions()
	var contact := GeometerGeometry.wall_contact(from - PlayerProjectile.BODY_OFFSET, to - PlayerProjectile.BODY_OFFSET, points[0], points[1], projectile.projectile_radius)
	if contact.is_empty():
		return {}
	if transport and elements[0] != &"lightning" and _redirect_target(projectile, points[1], from.lerp(to, contact["fraction"])).is_empty() and not fire:
		return {}
	return contact

func apply_owned_contact(projectile: PlayerProjectile) -> void:
	if is_instance_valid(casting) and casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE:
		casting.triangle_field.apply_owned_contact(projectile)
		return
	if not _available():
		return
	var elements := casting.construction.elements()
	var points := casting.construction.positions()
	var owner := casting.player.get_instance_id()
	var transformed := false
	if elements[0] == &"lightning":
		if casting.interaction_ledger.claim_owned_projectile(projectile.get_instance_id(), GeometerInteractionLedger.Component.TRANSPORT, projectile.request, owner):
			projectile.start_geometer_conduction(points[1] + PlayerProjectile.BODY_OFFSET, _identity)
			transformed = true
	elif elements[1] == &"lightning":
		var redirect := _redirect_target(projectile, points[1])
		if not redirect.is_empty() and casting.interaction_ledger.claim_owned_projectile(projectile.get_instance_id(), GeometerInteractionLedger.Component.TRANSPORT, projectile.request, owner):
			projectile.homing = false
			projectile.direction = projectile.global_position.direction_to(redirect["actor"].global_position + PlayerProjectile.BODY_OFFSET)
			projectile.targets = casting.targets.duplicate()
			transformed = true
	if elements[1] == &"fire" and casting.interaction_ledger.claim_owned_projectile(projectile.get_instance_id(), GeometerInteractionLedger.Component.FIRE_EXIT, projectile.request, owner):
		projectile.geometer_fire_request = (_snapshot["exit_request"] as DamageRequest).copy()
		projectile.geometer_payload_identity = _identity
		transformed = true
	if transformed:
		if float(_snapshot["incidence_fraction"]) > 0.0 and projectile.geometer_bonus_request == null:
			var bonus := projectile.request.copy()
			bonus.skill_id = &"geometer_incidence"
			bonus.physical_damage *= float(_snapshot["incidence_fraction"])
			bonus.magic_damage *= float(_snapshot["incidence_fraction"])
			bonus.is_secondary = true
			bonus.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
			bonus.can_crit = false
			bonus.force_critical = false
			bonus.prismatic_resonance_damage = 0.0
			projectile.geometer_bonus_request = bonus
			projectile.geometer_payload_identity = _identity
		casting.show_wall_reaction(projectile.global_position - PlayerProjectile.BODY_OFFSET, &"lightning" if elements.has(&"lightning") else &"fire")

func _redirect_target(projectile: PlayerProjectile, exit: Vector2, origin: Vector2 = Vector2.INF) -> Dictionary:
	var from := projectile.global_position if not origin.is_finite() else origin
	var best: CombatActor
	var distance := INF
	for actor: CombatActor in casting.targets:
		if not is_instance_valid(actor) or not actor.is_alive() or projectile._hit_actor_ids.has(actor.get_instance_id()):
			continue
		var current := exit.distance_to(actor.global_position)
		if current > REDIRECT_RANGE or not casting.player.navigation.is_segment_clear(exit, actor.global_position, 0.0) or not casting.player.navigation.is_segment_clear(from, actor.global_position + PlayerProjectile.BODY_OFFSET, projectile.projectile_radius):
			continue
		if current < distance or (is_equal_approx(current, distance) and (best == null or actor.get_instance_id() < best.get_instance_id())):
			best = actor
			distance = current
	return {"actor": best} if best != null else {}

func projectile_impact(projectile: PlayerProjectile, victim: CombatActor) -> void:
	if is_instance_valid(casting):
		casting.triangle_field.projectile_impact(projectile, victim)
	var fire := projectile.geometer_fire_request
	var bonus := projectile.geometer_bonus_request
	var identity := projectile.geometer_payload_identity
	projectile.geometer_fire_request = null
	projectile.geometer_bonus_request = null
	if not _available() or identity != casting.construction.construction_id:
		return
	if bonus != null and is_instance_valid(victim) and victim.is_alive():
		bonus.target_id = victim.get_instance_id()
		casting.hit.emit(bonus, victim)
	if fire == null:
		return
	var center := projectile.global_position - PlayerProjectile.BODY_OFFSET
	for actor: CombatActor in casting.targets.duplicate():
		if casting.construction.construction_id != identity or not casting.player.is_alive():
			break
		if not is_instance_valid(actor) or not actor.is_alive() or center.distance_to(actor.global_position) > PULSE_RADIUS + actor.collision_radius or not casting.player.navigation.is_segment_clear(center, actor.global_position, 0.0) or not casting.interaction_ledger.claim_victim(actor.get_instance_id()):
			continue
		var request := fire.copy()
		request.target_id = actor.get_instance_id()
		casting.hit.emit(request, actor)
	casting.show_wall_reaction(center, &"fire")

func hostile_contact(projectile: ArrowProjectile, from: Vector2, to: Vector2) -> Dictionary:
	if not _available() or projectile.request == null or projectile.request.source_id <= 0 or projectile.request.source_id == casting.player.get_instance_id() or casting.construction.elements()[1] != &"ice":
		return {}
	var points := casting.construction.positions()
	return GeometerGeometry.wall_contact(from - ArrowProjectile.BODY_OFFSET, to - ArrowProjectile.BODY_OFFSET, points[0], points[1], projectile.projectile_radius)

func intercept_hostile(point: Vector2) -> void:
	if not _available():
		return
	var refund: float = _snapshot["incidence_sp"]
	var player := casting.player
	if refund > 0.0 and casting.interaction_ledger.claim_interception_refund(player.current_sp < player.max_sp):
		player.current_sp = minf(player.max_sp, player.current_sp + refund)
		player.resources_changed.emit()
	casting.show_wall_reaction(point, &"ice")
