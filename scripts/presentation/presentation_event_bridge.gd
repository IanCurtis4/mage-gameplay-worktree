class_name PresentationEventBridge
extends Control
## Disposable observer. Control is intentionally excluded by SnapshotRegistry's
## existing presentation boundary; no bridge clock/identity enters gameplay saves.
signal event_confirmed(event: Dictionary)
signal world_pause_changed(paused: bool)
signal world_advanced(delta: float)

const DEDUP_LIMIT := 2048
const KINDS: Array[StringName] = [&"cast_start", &"cast_cancel", &"projectile_launch", &"impact", &"area_start", &"area_end", &"teleport", &"death", &"revive", &"stage_enter", &"stage_exit", &"ui_confirm", &"ui_cancel",
	# E08 P6 (docs/epics/e08_p6_a1_delivery.md): published only after the canonical fact.
	&"melee_swing", &"movement", &"effect_start", &"heal", &"summon", &"charge_start", &"trap_trigger"]
const CLEANUP_KINDS: Array[StringName] = [&"cast_cancel", &"area_end", &"death", &"revive", &"stage_enter", &"stage_exit"]
## New P6 kinds that carry danger/telegraph information consumers must not cull.
const ESSENTIAL_P6_KINDS: Array[StringName] = [&"summon", &"charge_start", &"trap_trigger"]
const FieldView = preload("res://scripts/world/world_field_view.gd")
const Recipes = preload("res://scripts/presentation/feedback_recipe_catalog.gd")
var stage_id := ""
var world_time := 0.0
var _epoch := 0
var _sequence := 0
var _controller: WeakRef
var _connections: Array[Dictionary] = []
var _watched: Dictionary = {}
var _actors: Dictionary = {}
var _areas: Dictionary = {}
var _area_nodes: Dictionary = {}
var _flights: Dictionary = {}
var _trap_targets: Dictionary = {}
var _seen: Dictionary = {}
var _order: Array[String] = []
var _paused := false
var _disposed := false
var _clearing := false
## P6-A2: element known at the emission site (Elementalist pulses). Presentation hint only:
## consumed by the damage event of the same frame and target, never read by simulation.
var _element_hints: Dictionary = {}
const ELEMENT_HINT_LIMIT := 32

func _init() -> void:
	name = "PresentationEvents"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func world_paused() -> bool:
	return is_inside_tree() and get_tree().paused

func current_epoch() -> int:
	return _epoch

func bind_controller(controller: Node) -> void:
	if _disposed or not is_instance_valid(controller): return
	if _host() == controller: return
	clear_stage()
	_controller = weakref(controller)

func _host() -> Node:
	return _controller.get_ref() as Node if _controller != null else null

func begin_stage(id: String, resumed: bool = false) -> void:
	if _disposed or _clearing or id.is_empty(): return
	clear_stage()
	stage_id = id
	world_time = 0.0
	_paused = is_inside_tree() and get_tree().paused
	var host := _host()
	if host != null: _watch(host, true, _epoch)
	_publish(&"stage_enter", "", &"", Vector3.ZERO, "", 0.0, true,
		{"resumed":resumed, "current_state":current_state(), "position_unavailable":true})

func clear_stage() -> void:
	if _clearing: return
	_clearing = true
	if not stage_id.is_empty():
		_publish(&"stage_exit", "", &"", Vector3.ZERO, "", 0.0, true, {"position_unavailable":true})
	# Invalidate before disconnecting: a reentrant/queued old callback cannot enter.
	_epoch += 1
	for entry: Dictionary in _connections:
		var source: Object = entry.owner.get_ref()
		if is_instance_valid(source) and source.is_connected(entry.signal_name, entry.callback):
			source.disconnect(entry.signal_name, entry.callback)
	_connections.clear()
	_watched.clear(); _actors.clear(); _areas.clear(); _area_nodes.clear(); _flights.clear(); _trap_targets.clear()
	_seen.clear(); _order.clear(); _element_hints.clear()
	stage_id = ""
	world_time = 0.0
	_clearing = false

func dispose() -> void:
	if _disposed: return
	clear_stage()
	_controller = null
	_disposed = true
	set_process(false)

func _exit_tree() -> void:
	dispose()

func _listen(owner: Object, signal_name: StringName, callback: Callable) -> void:
	if owner.is_connected(signal_name, callback): return
	owner.connect(signal_name, callback)
	_connections.append({"owner":weakref(owner), "signal_name":signal_name, "callback":callback})

func _valid(epoch: int) -> bool:
	return not _disposed and epoch == _epoch and not stage_id.is_empty()

func _watch(node: Node, restoring: bool, epoch: int) -> void:
	if not _valid(epoch) or node == self or node is Control or node is CanvasLayer or node.is_queued_for_deletion(): return
	var id := str(node.get_instance_id())
	if _watched.has(id): return
	_watched[id] = true
	_listen(node, &"child_entered_tree", _child_added.bind(epoch))
	_listen(node, &"tree_exiting", _node_exiting.bind(id, epoch))
	if node is CombatActor:
		var actor := node as CombatActor
		_actors[id] = {"owner":weakref(actor), "alive":actor.is_alive(), "damage_callback":_damage.bind(weakref(actor), epoch), "heal_callback":_heal.bind(weakref(actor), epoch), "cast_skill":actor.active_cast_skill if actor is PlayerActor else &"",
			"pending_skill":&"", "pending_frame":-1, "heal_skill":&"", "heal_frame":-1}
		_listen(actor, &"presentation_action", _action.bind(weakref(actor), epoch))
		if actor.has_signal(&"presentation_fact"): _listen(actor, &"presentation_fact", _fact.bind(weakref(actor), epoch))
		_listen(actor, &"actor_died", _death.bind(epoch))
		_listen(actor, &"presentation_health_ready", _health_ready.bind(weakref(actor), epoch))
		if actor.health != null: _health_ready(actor.health, weakref(actor), epoch)
		# A companion entering after its master's canonical spawn; resume never replays it.
		if not restoring and actor is EnemyActor and actor.is_summoned: _summon(actor as EnemyActor, id)
	else:
		var flight := _projectile(node)
		if not flight.is_empty():
			_flights[id] = weakref(node)
			if not restoring: _from_description(&"projectile_launch", id, flight, false)
		var area := _area(node)
		if not area.is_empty():
			_areas[id] = area
			_area_nodes[id] = weakref(node)
			if not restoring: _from_description(&"area_start", id, area, true)
			if node is PlayerTrap:
				_listen(node, &"triggered", _trap_triggered.bind(id, epoch))
				_listen(node, &"removed", _trap_removed.bind(id, epoch))
	for child: Node in node.get_children(): _watch(child, restoring, epoch)

func _child_added(node: Node, epoch: int) -> void:
	_watch(node, false, epoch)

func _node_exiting(id: String, epoch: int) -> void:
	if not _valid(epoch): return
	var host := _host()
	if host != null and str(host.get_instance_id()) == id:
		clear_stage(); _controller = null
		return
	if _areas.has(id):
		var ended: Dictionary = _areas[id].duplicate(true); ended.duration = 0.0
		var reason := _end_reason(_area_nodes[id].get_ref() if _area_nodes.has(id) else null)
		if not reason.is_empty(): ended.payload["reason"] = reason
		_from_description(&"area_end", id, ended, true)
	var health_id := ""
	if _actors.has(id):
		var actor := _actors[id].owner.get_ref() as CombatActor
		if is_instance_valid(actor) and actor.health != null: health_id = str(actor.health.get_instance_id())
	_areas.erase(id); _area_nodes.erase(id); _flights.erase(id); _actors.erase(id); _watched.erase(id); _trap_targets.erase(id)
	# Release records for dead sources as well as live subscriptions. This list
	# must not grow with every projectile over a long stage.
	for index: int in range(_connections.size()-1, -1, -1):
		var entry: Dictionary = _connections[index]
		var source: Object = entry.owner.get_ref()
		if not is_instance_valid(source) or str(source.get_instance_id()) in [id, health_id]:
			if is_instance_valid(source) and source.is_connected(entry.signal_name, entry.callback): source.disconnect(entry.signal_name, entry.callback)
			_connections.remove_at(index)

func _health_ready(state: HealthState, owner: WeakRef, epoch: int) -> void:
	if not _valid(epoch): return
	var actor := owner.get_ref() as CombatActor
	if not is_instance_valid(actor): return
	var id := str(actor.get_instance_id())
	if not _actors.has(id): return
	var previous: WeakRef = _actors[id].get("health")
	if previous != null and previous.get_ref() == state: return
	if previous != null:
		var old: Object = previous.get_ref()
		for index: int in range(_connections.size()-1, -1, -1):
			var entry: Dictionary = _connections[index]
			if entry.owner.get_ref() == old:
				if is_instance_valid(old) and old.is_connected(entry.signal_name, entry.callback): old.disconnect(entry.signal_name, entry.callback)
				_connections.remove_at(index)
	_actors[id].health = weakref(state)
	_actors[id].alive = actor.is_alive()
	_actors[id].last_damage_sequence = state.damage_sequence
	_actors[id].last_heal_sequence = state.heal_sequence
	_listen(state, &"damage_applied", _actors[id].damage_callback)
	_listen(state, &"healed", _actors[id].heal_callback)

func _actor_description(actor: CombatActor) -> Dictionary:
	var point := actor.world_point()
	if point != null:
		if not actor.world_motion.is_current_world() or point.stage_id != stage_id: return {}
		return {"position":point.position, "surface_id":point.surface_id, "skill_id":&"", "duration":0.0, "payload":{}}
	return {"position":Vector3.ZERO, "surface_id":"", "skill_id":&"", "duration":0.0,
		"payload":{"legacy_position_2d":actor.global_position, "position_unavailable":true}}

## Declares the element of the hit about to be applied to `target` in this frame
## (Elementalist pulses/arc: the element is only known at the call site). The next
## `impact` for that target in the same frame carries it as `payload.element`.
func note_element(target: Object, element: StringName) -> void:
	if _disposed or stage_id.is_empty() or not is_instance_valid(target) or element not in Recipes.ELEMENTS: return
	var frame := Engine.get_process_frames()
	if _element_hints.size() >= ELEMENT_HINT_LIMIT:
		for key: String in _element_hints.keys():
			if int(_element_hints[key].frame) != frame: _element_hints.erase(key)
		if _element_hints.size() >= ELEMENT_HINT_LIMIT: _element_hints.clear()
	_element_hints[str(target.get_instance_id())] = {"element":element, "frame":frame}

func _take_element_hint(id: String) -> StringName:
	if not _element_hints.has(id): return &""
	var hint: Dictionary = _element_hints[id]
	_element_hints.erase(id)
	return hint.element if int(hint.frame) == Engine.get_process_frames() else &""

func _action(action: StringName, direction: Vector2, duration: float, owner: WeakRef, epoch: int) -> void:
	if not _valid(epoch): return
	var actor := owner.get_ref() as CombatActor
	if not is_instance_valid(actor): return
	var id := str(actor.get_instance_id())
	if not _actors.has(id): return
	var hint := _take_hint(id) # Skill committed in this frame, consumed by the first following action.
	if action == &"cast_release":
		_actors[id].cast_skill = &""
		return
	if action in [&"slash", &"basic_attack", &"dash"]:
		_swing_or_move(action, actor, hint, direction, duration)
		return
	var kind: StringName = {&"cast":&"cast_start", &"cast_cancel":&"cast_cancel", &"teleport":&"teleport"}.get(action, &"")
	if kind == &"": return # Requests are never an impact.
	var data := _actor_description(actor)
	if data.is_empty(): return
	data.duration = duration
	data.payload["direction_2d"] = direction
	if actor is PlayerActor:
		var player := actor as PlayerActor
		data.skill_id = player.active_cast_skill
		if kind == &"cast_start":
			# P6: instant casts (no timed cast) carry the committed skill identity.
			data.payload["instant"] = player.active_cast_skill.is_empty()
			if data.skill_id.is_empty(): data.skill_id = hint
		if kind == &"cast_cancel": data.skill_id = _actors[id].cast_skill
		if kind == &"teleport": data.skill_id = &"teleport"
		if kind == &"cast_start": _actors[id].cast_skill = data.skill_id
		data.payload.merge(player.presentation_cast_context())
	if kind == &"cast_cancel": data.skill_id = _actors[id].cast_skill
	if actor is EnemyActor and not actor._mob_cast.is_empty():
		var request: DamageRequest = actor._mob_cast.get("request")
		if request != null: data.skill_id = request.skill_id
	if kind == &"cast_start": _actors[id].cast_skill = data.skill_id
	if kind == &"cast_cancel": _actors[id].cast_skill = &""
	var variant := _variant(actor)
	if not variant.is_empty(): data.payload["actor_variant"] = variant
	_from_description(kind, id, data, kind != &"teleport")

func _take_hint(id: String) -> StringName:
	var record: Dictionary = _actors[id]
	var skill: StringName = record.pending_skill if int(record.pending_frame) == Engine.get_process_frames() else &""
	record.pending_skill = &""; record.pending_frame = -1
	return skill

## Player class or enemy species: selects recipe variants (basic attacks, warden).
func _variant(actor: CombatActor) -> StringName:
	if actor is PlayerActor: return (actor as PlayerActor).class_id
	if actor is EnemyActor and (actor as EnemyActor).occurrence != null: return (actor as EnemyActor).occurrence.mob_base_id
	return &""

func _variant_by_id(id: String) -> StringName:
	if not _actors.has(id): return &""
	var actor := _actors[id].owner.get_ref() as CombatActor
	return _variant(actor) if is_instance_valid(actor) else &""

## Swing = requested strike with direction (never a hit); dash = committed displacement.
func _swing_or_move(action: StringName, actor: CombatActor, hint: StringName, direction: Vector2, duration: float) -> void:
	var variant := _variant(actor)
	var kind := &"movement" if action == &"dash" else &"melee_swing"
	var skill := hint
	if action == &"dash" and skill.is_empty(): skill = &"dash"
	if action == &"basic_attack":
		# Identity-free actors cannot be classified; ranged basics are covered by projectile_launch.
		if variant.is_empty(): return
		if skill.is_empty(): skill = &"basic_attack"
		if not Recipes.is_melee(skill, variant): return
	var data := _actor_description(actor)
	if data.is_empty(): return
	data.skill_id = skill; data.duration = duration
	data.payload["direction_2d"] = direction
	if kind == &"movement": data.payload["phase"] = "start"
	if not variant.is_empty(): data.payload["actor_variant"] = variant
	_from_description(kind, str(actor.get_instance_id()), data, false)

## Presentation-only facts declared by PlayerActor/EnemyActor after the canonical change.
func _fact(kind: StringName, skill: StringName, direction: Vector2, duration: float, owner: WeakRef, epoch: int) -> void:
	if not _valid(epoch): return
	var actor := owner.get_ref() as CombatActor
	if not is_instance_valid(actor): return
	var id := str(actor.get_instance_id())
	if not _actors.has(id): return
	var variant := _variant(actor)
	match kind:
		&"skill_committed":
			_actors[id].pending_skill = skill; _actors[id].pending_frame = Engine.get_process_frames()
			if not Recipes.is_commit_effect(skill, variant): return
			var data := _actor_description(actor)
			if data.is_empty(): return
			data.skill_id = skill
			if actor is PlayerActor: data.payload.merge((actor as PlayerActor).presentation_cast_context())
			if not variant.is_empty(): data.payload["actor_variant"] = variant
			_from_description(&"effect_start", id, data, false)
		&"heal_source":
			_actors[id].heal_skill = skill; _actors[id].heal_frame = Engine.get_process_frames()
		&"movement", &"charge_start":
			var data := _actor_description(actor)
			if data.is_empty(): return
			data.skill_id = skill; data.duration = maxf(0.0, duration) if is_finite(duration) else 0.0
			data.payload["direction_2d"] = direction if direction.is_finite() else Vector2.ZERO
			data.payload["phase"] = "start"
			if not variant.is_empty(): data.payload["actor_variant"] = variant
			if kind == &"charge_start" and actor is EnemyActor: _charge_target(actor as EnemyActor, data)
			_from_description(kind, id, data, kind in ESSENTIAL_P6_KINDS)

func _charge_target(enemy: EnemyActor, data: Dictionary) -> void:
	var target: CombatActor = enemy.player
	if not is_instance_valid(target): return
	data.payload["target_id"] = str(target.get_instance_id())
	var from := enemy.world_point()
	var to := target.world_point()
	if from != null and to != null:
		var flat := Vector3(to.position.x-from.position.x, 0.0, to.position.z-from.position.z)
		if not flat.is_zero_approx(): data.payload["direction"] = flat.normalized()
	elif from == null and to == null and not enemy.global_position.is_equal_approx(target.global_position):
		data.payload["direction_2d"] = enemy.global_position.direction_to(target.global_position)

func _summon(companion: EnemyActor, id: String) -> void:
	var data := _actor_description(companion)
	if data.is_empty(): return
	var master := str(companion.summoner_id)
	data.payload["companion_id"] = id
	var variant := _variant_by_id(master)
	if not variant.is_empty(): data.payload["actor_variant"] = variant
	_publish(&"summon", master, &"enemy_summon", data.position, data.surface_id, 0.0, true, data.payload, "summon/" + id)

func _heal(amount: float, sequence: int, owner: WeakRef, epoch: int) -> void:
	if not _valid(epoch): return
	var actor := owner.get_ref() as CombatActor
	if not is_instance_valid(actor) or actor.health == null: return
	var id := str(actor.get_instance_id())
	if not _actors.has(id) or sequence <= int(_actors[id].get("last_heal_sequence", 0)): return
	_actors[id].last_heal_sequence = sequence
	var skill: StringName = _actors[id].heal_skill if int(_actors[id].heal_frame) == Engine.get_process_frames() else &""
	_actors[id].heal_skill = &""; _actors[id].heal_frame = -1
	# Continuous regeneration/leash recovery has no discrete source and is not feedback.
	if skill.is_empty() or not is_finite(amount) or amount <= 0.0: return
	var data := _actor_description(actor)
	if data.is_empty(): return
	data.skill_id = skill
	data.payload["amount"] = amount; data.payload["application_sequence"] = sequence; data.payload["target_id"] = id
	var variant := _variant(actor)
	if not variant.is_empty(): data.payload["actor_variant"] = variant
	_from_description(&"heal", id, data, false, "heal/%d/%d" % [actor.health.get_instance_id(), sequence])

func _trap_triggered(_trap: PlayerTrap, target: CombatActor, id: String, epoch: int) -> void:
	if _valid(epoch) and is_instance_valid(target): _trap_targets[id] = str(target.get_instance_id())

## `removed` follows every `triggered` handler: the trap effect is already applied.
func _trap_removed(_trap: PlayerTrap, reason: StringName, id: String, epoch: int) -> void:
	if not _valid(epoch) or reason != PlayerTrap.REASON_TRIGGERED or not _areas.has(id): return
	var data: Dictionary = _areas[id].duplicate(true); data.duration = 0.0
	data.payload["reason"] = "trigger"
	if _trap_targets.has(id): data.payload["target_id"] = _trap_targets[id]
	_from_description(&"trap_trigger", id, data, true, "trap/" + id)

## Why an area ended, when the node says so: trigger | expire | cleanup.
func _end_reason(node: Object) -> String:
	if not is_instance_valid(node): return ""
	if node is PlayerTrap:
		return {PlayerTrap.REASON_TRIGGERED:"trigger", PlayerTrap.REASON_DURATION:"expire"}.get(node.removal_reason, "cleanup")
	if node is FoliageShelter: return "expire" if node.removal_reason == FoliageShelter.REASON_EXPIRED else "cleanup"
	if node is ArrowRain: return "expire" if node.volleys_emitted >= ArrowRain.VOLLEY_COUNT else "cleanup"
	var remaining: Variant = _property(node, &"remaining")
	if typeof(remaining) in [TYPE_FLOAT, TYPE_INT]: return "expire" if float(remaining) <= 0.0 else "cleanup"
	return ""

func _damage(result: Dictionary, owner: WeakRef, epoch: int) -> void:
	if not _valid(epoch) or not result.get("landed", false): return
	var actor := owner.get_ref() as CombatActor
	if not is_instance_valid(actor): return
	var data := _actor_description(actor)
	if data.is_empty(): return
	var id := str(actor.get_instance_id())
	var sequence := int(result.get("application_sequence", 0))
	if not _actors.has(id) or sequence <= int(_actors[id].get("last_damage_sequence", 0)): return
	_actors[id].last_damage_sequence = sequence
	data.skill_id = StringName(result.get("skill_id", &""))
	# Copy confirmed scalar/geometry data; strip live gameplay context/ledger.
	for key: Variant in result:
		if _data_only(result[key]): data.payload[key] = result[key]
	data.payload["target_id"] = str(actor.get_instance_id())
	var hinted := _take_element_hint(id)
	if not hinted.is_empty(): data.payload["element"] = String(hinted)
	data.payload["contact_position_unavailable"] = true # Actor anchor != collision point.
	var source_variant := _variant_by_id(str(result.get("source_id", "")))
	if not source_variant.is_empty(): data.payload["source_variant"] = source_variant
	var identity := "damage/%d/%d" % [actor.health.get_instance_id(), int(result.get("application_sequence", 0))]
	_from_description(&"impact", str(actor.get_instance_id()), data, false, identity)

func _death(actor: CombatActor, epoch: int) -> void:
	if not _valid(epoch): return
	var id := str(actor.get_instance_id())
	if not _actors.has(id) or not _actors[id].alive: return
	_actors[id].alive = false
	_from_description(&"death", id, _actor_description(actor), true)

func _process(delta: float) -> void:
	if _disposed or stage_id.is_empty(): return
	var paused := is_inside_tree() and get_tree().paused
	if paused != _paused:
		_paused = paused
		world_pause_changed.emit(paused)
	# Recovery can restore health while the tree is paused. Observe the edge,
	# without reviving/healing/mutating the actor or replaying damage sequences.
	for id: String in _actors.keys():
		if not _actors.has(id): continue
		var actor := _actors[id].owner.get_ref() as CombatActor
		if not is_instance_valid(actor): continue
		var alive := actor.is_alive()
		if alive and not _actors[id].alive: _from_description(&"revive", id, _actor_description(actor), true)
		_actors[id].alive = alive
	if not paused and is_finite(delta) and delta > 0.0:
		world_time += delta
		world_advanced.emit(delta)

func _property(node: Object, key: StringName) -> Variant:
	for item: Dictionary in node.get_property_list():
		if item.name == key: return node.get(key)
	return null

func _projectile(node: Node) -> Dictionary:
	if not (node is PlayerProjectile or node is ArrowProjectile): return {}
	var projectile: Variant = node
	if projectile.request == null: return {}
	var flight: WorldProjectileMotion = projectile.world_flight
	var payload := {"source_id":str(projectile.request.source_id), "target_id":str(projectile.request.target_id), "speed":projectile.speed, "range":projectile.max_distance, "projectile_id":str(projectile.get_instance_id())}
	if flight != null:
		if flight.stage_id != stage_id or flight._configuration_revision != flight.geometry.configuration_revision: return {}
		payload["collider"] = flight.collider.duplicate(true); payload["direction"] = flight.direction
		_projectile_element(node, payload)
		return {"position":flight.position, "surface_id":"", "skill_id":projectile.request.skill_id, "duration":0.0, "payload":payload}
	_projectile_element(node, payload)
	payload["legacy_position_2d"] = projectile.global_position; payload["position_unavailable"] = true
	payload["radius"] = projectile.projectile_radius; payload["direction_2d"] = projectile.direction
	return {"position":Vector3.ZERO, "surface_id":"", "skill_id":projectile.request.skill_id, "duration":0.0, "payload":payload}

## Geometer traces know their element (fire/ice/lightning) at the emission site.
func _projectile_element(node: Node, payload: Dictionary) -> void:
	if node is GeometerTraceProjectile and (node as GeometerTraceProjectile).element in Recipes.ELEMENTS:
		payload["element"] = String((node as GeometerTraceProjectile).element)

func _area(node: Node) -> Dictionary:
	var description := {}
	var anchor: ExpeditionWorldPoint
	var duration := 0.0
	var skill: StringName = &""
	if node is ArrowRain or node is FoliageShelter or node is PlayerTrap:
		var area: WorldEffectArea = node.get("world_area")
		if area != null:
			if not area.is_current_world(): return {}
			anchor = area.anchor()
			description["geometry_rule_id"] = area._rule
		if node is ArrowRain:
			if node.damage_request == null: return {}
			skill = node.damage_request.skill_id
			description["source_id"] = str(node.damage_request.source_id)
			description["radius"] = ArrowRain.RADIUS
			duration = maxf(0.0, ArrowRain.WARNING_DURATION + (ArrowRain.VOLLEY_COUNT-1)*ArrowRain.VOLLEY_INTERVAL-node.elapsed)
		elif node is FoliageShelter:
			skill = &"foliage_shelter"
			if is_instance_valid(node.player_owner): description["source_id"] = str(node.player_owner.get_instance_id())
			description["radius"] = node.radius
			duration = node.remaining
		else:
			if not node._configured or node.state == PlayerTrap.State.EXPIRED: return {}
			skill = node.source_skill_id
			description["source_id"] = str(node.owner_id)
			description["radius"] = node.radius
			if node is HunterTrap: description["effect_radius"] = node.effect_radius
			duration = node.arming_remaining + node.lifetime_remaining
		description["shape"] = &"circle"
		if anchor == null:
			description["legacy_position_2d"] = node.global_position
			description["position_unavailable"] = true
	else:
		if not (node is FireWall or node is LightningWall or node is PhantomBarrier or node is IceWall): return {}
		var host := _host()
		if host == null: return {}
		var player: Variant = _property(host, &"player")
		if not player is CombatActor or player.world_motion == null: return {}
		description = FieldView.describe(node, player.world_motion.geometry)
		if description.is_empty(): return {}
		var point: Dictionary = description.get("anchor", {})
		if point.is_empty(): return {}
		anchor = ExpeditionWorldPoint.create(point.stage_id, point.surface_id, point.position)
		skill = StringName(description.kind)
		duration = float(node.get("remaining"))
		var request: Variant = _property(node, &"burn_request") if node is FireWall else _property(node, &"request")
		if request is DamageRequest: description["source_id"] = str(request.source_id)
	if anchor != null and anchor.stage_id != stage_id: return {}
	return {"position":anchor.position if anchor != null else Vector3.ZERO, "surface_id":anchor.surface_id if anchor != null else "", "skill_id":skill, "duration":duration, "payload":description}

func current_state() -> Dictionary:
	var actors: Array[Dictionary] = []
	for id: String in _actors.keys():
		if not _actors.has(id): continue
		var actor := _actors[id].owner.get_ref() as CombatActor
		if not is_instance_valid(actor): continue
		var data := _actor_description(actor)
		if data.is_empty(): continue
		data["actor_id"] = id; data["alive"] = actor.is_alive()
		if actor is PlayerActor:
			data["cast_skill"] = actor.active_cast_skill
			data["cast_remaining"] = actor.active_cast_remaining
			data.payload.merge(actor.presentation_cast_context())
		elif actor is EnemyActor and not actor._mob_cast.is_empty():
			var request: DamageRequest = actor._mob_cast.get("request")
			data["cast_skill"] = request.skill_id if request != null else &""
			data["cast_remaining"] = float(actor._mob_cast.get("remaining",0.0))
		actors.append(data)
	var areas := {}
	for id: String in _area_nodes:
		var node := _area_nodes[id].get_ref() as Node
		if is_instance_valid(node):
			var data := _area(node)
			if not data.is_empty(): areas[id] = data
	var projectiles := {}
	for id: String in _flights:
		var node := _flights[id].get_ref() as Node
		if is_instance_valid(node):
			var data := _projectile(node)
			if not data.is_empty(): projectiles[id] = data
	return {"actors":actors, "areas":areas, "projectiles":projectiles}

func _from_description(kind: StringName, actor: String, data: Dictionary, essential: bool, identity: String = "") -> void:
	if data.is_empty(): return
	var payload: Dictionary = data.payload.duplicate(true)
	if kind in [&"projectile_launch", &"area_start", &"area_end", &"trap_trigger"]:
		payload["entity_id"] = actor
		actor = str(payload.get("source_id", ""))
		var source_variant := _variant_by_id(actor)
		if not source_variant.is_empty(): payload["source_variant"] = source_variant
	_publish(kind, actor, data.skill_id, data.position, data.surface_id, data.duration, essential, payload, identity)

func _publish(kind: StringName, actor: String, skill: StringName, position: Vector3, surface: String, duration: float, essential: bool, payload: Dictionary, identity: String = "") -> bool:
	_sequence += 1
	var copied := payload.duplicate(true)
	copied["presentation_epoch"] = _epoch
	return emit_confirmed({"event_id":("%d/%s" % [_epoch, identity]) if not identity.is_empty() else ("%d/%d" % [_epoch, _sequence]), "kind":kind, "stage_id":stage_id,
		"actor_id":actor, "skill_id":skill, "position":position, "surface_id":surface,
		"duration":duration, "essential":essential, "payload":copied})

func _data_only(value: Variant, depth: int = 0) -> bool:
	if depth > 16: return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR2, TYPE_VECTOR3: return value.is_finite()
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY:
			for item: Variant in value:
				if not _data_only(item, depth+1): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT] or not _data_only(value[key], depth+1): return false
			return true
	return false

func emit_confirmed(event: Dictionary) -> bool:
	if _disposed or stage_id.is_empty(): return false
	for key: String in ["event_id", "stage_id", "actor_id", "surface_id"]:
		if not event.get(key) is String: return false
	if event.event_id.is_empty() or event.stage_id != stage_id: return false
	if not event.get("kind") is StringName or event.kind not in KINDS or not event.get("skill_id") is StringName: return false
	if not event.get("position") is Vector3 or not event.position.is_finite(): return false
	if typeof(event.get("duration")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(event.duration) or event.duration < 0.0: return false
	if not event.get("essential") is bool or not event.get("payload") is Dictionary or not _data_only(event.payload): return false
	if event.payload.get("presentation_epoch", -1) != _epoch: return false
	if is_inside_tree() and get_tree().paused and event.kind not in CLEANUP_KINDS and event.kind not in [&"ui_confirm", &"ui_cancel"]: return false
	if _seen.has(event.event_id): return false
	# Bounded FIFO of identity only: no essential event/indicator is dropped.
	if _order.size() >= DEDUP_LIMIT: _seen.erase(_order.pop_front())
	_seen[event.event_id] = true; _order.append(event.event_id)
	event_confirmed.emit(event.duplicate(true))
	return true
