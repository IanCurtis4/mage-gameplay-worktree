class_name CombatActor
extends Node2D
## Shared runtime presentation and health ownership for combat actors.

const GroundShadow = preload("res://scripts/world/ground_shadow.gd")
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const PilotVisual = preload("res://scripts/presentation/e08_pilot_visual.gd")
var contact_shadows_enabled := true
var _ground_shadow_cache := {}
var _presentation_key: Array = []

const MAX_SLOW_FRACTION := 0.50
const MAX_WEAKEN_FRACTION := 0.50

signal actor_died(actor: CombatActor)
signal damage_number(actor: CombatActor, amount: int, critical: bool)
signal attack_missed(actor: CombatActor)
signal status_damage_requested(request: DamageRequest, target: CombatActor)
signal presentation_health_ready(state: HealthState)
signal presentation_action(action: StringName, direction: Vector2, duration: float)

var actor_name := "Ator"
var actor_color := Color.WHITE
var stat_breakdown: StatBreakdown
var health: HealthState
var collision_radius := 18.0
var sprite_visual_scale := 1.0
var body_drawer: Callable
var body_visual_owner: RefCounted
var compact_control_visuals := false
var is_hovered := false
var is_selected := false
var _flash_time := 0.0
var sprite_texture: Texture2D
var sprite_rect := Rect2()
var _sprite_visible_height := 0.0
var burn_remaining := 0.0
var burn_tick_remaining := 0.0
var burn_streams: Dictionary[String, Dictionary] = {}
var burn_request: DamageRequest
var bleed_streams: Dictionary[String, Dictionary] = {}
var berserker_wound_visual_stacks := 0
var berserker_wound_visual_remaining := 0.0
var _berserker_wound_visual_pulse := 0.0
var slow_remaining := 0.0
var slow_fraction := 0.0
var electrified_remaining := 0.0
var weaken_remaining := 0.0
var weaken_fraction := 0.0
var attribute_debuffs := AttributeDebuffState.new()
var hard_controls := HardControlState.new()
var character_animation: CharacterAnimation
## E09 C1.5: generic marks (key, owner, value, expiry on the gameplay clock).
var marks := ActorMarks.new()
## E09 C1.5: temporary override of the gameplay facing ("turn"); canvas direction.
var _facing_override := Vector2.ZERO
var _facing_override_remaining := 0.0
var _facing_override_owner: StringName = &""
## E10a C1.7: generic received-damage multipliers, source -> {"multiplier", "owner_id"
## (0 = any author), "element" (empty = any), "remaining"}. CombatMath composes them once.
var received_damage_sources: Dictionary = {}
## E10a C1.7: reductions of this actor's own hit rating, source -> {"reduction",
## "owner_id", "remaining"}; read through outgoing_hit_rating().
var accuracy_sources: Dictionary = {}
## E10a C1.7: heading of the movement disorientation (hard-control family `disorient`).
var disorient_heading := Vector2.ZERO

# Explicit logical spatial binding. Rendering/input integration awaits D05 presentation.
var world_motion: WorldActorMotion
## E12 H4: presentation-only cast bar state (never read by rules, never saved). The last
## active reading survives the cancel / release flash, because the clock is already idle then.
const CAST_LABEL_CATEGORIES: Array[StringName] = [&"elite", &"rare_elite", &"boss"]
var _cast_last: Dictionary = {}
var _cast_flash_kind: StringName = &""
var _cast_flash_time := 0.0
var _cast_bar_drawn := false
func bind_world_geometry(world: WorldGeometry, point: ExpeditionWorldPoint, traversal: Dictionary, occupant_id: String) -> Dictionary:
	if world_motion != null: return {"ok":false,"error_code":&"already_bound"}
	var motion := WorldActorMotion.new()
	var result := motion.configure(world,point,traversal,occupant_id)
	if result["ok"]:
		world_motion = motion
		# Keep status clocks alive. Player/Enemy override locomotion when bound.
		set_process(true)
	return result
func world_point() -> ExpeditionWorldPoint:
	return world_motion.point() if world_motion != null else null
func move_world_to(destination: ExpeditionWorldPoint, revision: int) -> Dictionary:
	if world_motion == null: return {"ok":false,"error_code":&"spatial_binding_required"}
	return world_motion.plan(destination,revision)
func advance_world(distance: float) -> Dictionary:
	if world_motion == null: return {"ok":false,"error_code":&"spatial_binding_required"}
	return world_motion.advance(distance)
func world_distance_to(other: CombatActor) -> float:
	if world_motion == null or not world_motion.is_current_world() or not is_instance_valid(other) or other.world_motion == null or not other.world_motion.is_current_world() or world_motion.geometry != other.world_motion.geometry: return INF
	return world_point().position.distance_to(other.world_point().position)

func world_attack_query(other: CombatActor, shape: Dictionary, revision: int) -> Dictionary:
	if world_motion == null or not world_motion.is_current_world() or not is_instance_valid(other) or other.world_motion == null or not other.world_motion.is_current_world() or world_motion.geometry != other.world_motion.geometry: return {"ok":false,"error_code":&"incompatible_target","data":{}}
	return world_motion.geometry.query_attack(shape,world_point(),other.world_point(),revision)

func world_can_reach(other: CombatActor, maximum_range: float) -> bool:
	if world_motion == null or not is_instance_valid(other) or other.world_motion == null: return false
	var shape := {"geometry_rule_id":&"direct_volume","range":maximum_range,"source_offset":Vector3.UP*float(world_motion.profile()["height"])*0.5,"target_offset":Vector3.UP*float(other.world_motion.profile()["height"])*0.5}
	var result := world_attack_query(other,shape,world_motion.geometry.geometry_revision)
	return result["ok"] and result["data"]["hit"]

func set_animation_kind(kind: StringName) -> void:
	character_animation = CharacterAnimation.new()
	character_animation.configure(kind)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_visible_height = 52.0
	if not presentation_action.is_connected(_animate_action):
		presentation_action.connect(_animate_action)
	queue_redraw()

func _init() -> void:
	presentation_action.connect(_on_cast_presentation)

## E12 H4: the cast bar flash comes from the existing presentation actions, no new signal.
## Only a cast that was seen active in an earlier frame can flash (instant actions that also
## emit cast_release never draw a stale bar).
func _on_cast_presentation(action: StringName, _direction: Vector2, _duration: float) -> void:
	if (action != &"cast_cancel" and action != &"cast_release") or _cast_last.is_empty(): return
	_cast_flash_kind = &"cancel" if action == &"cast_cancel" else &"release"
	_cast_flash_time = HudPalette.FLASH_SECONDS
	queue_redraw()

func _animate_action(action: StringName, direction: Vector2, duration: float) -> void:
	if character_animation != null:
		character_animation.play(action, direction, duration)
		queue_redraw()

func set_pilot_sprite(texture: Texture2D) -> void:
	sprite_texture = texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := texture.get_size()
	var used := texture.get_image().get_used_rect()
	var display_scale := 52.0 / maxf(1.0, float(used.size.y))
	# The lowest opaque row touches the actor's existing ground origin.
	sprite_rect = Rect2(Vector2(-size.x * 0.5, -float(used.end.y)) * display_scale, size * display_scale)
	_sprite_visible_height = float(used.size.y) * display_scale
	queue_redraw()

func setup(display_name: String, color: Color, derived_stats: StatBreakdown, radius: float = 18.0) -> void:
	assert(derived_stats != null)
	hard_controls.configure(false)
	actor_name = display_name
	actor_color = color
	stat_breakdown = derived_stats
	collision_radius = radius
	health = HealthState.new(get_instance_id(), stat_breakdown)
	health.damage_applied.connect(_on_damage_applied)
	health.actor_died.connect(_on_health_died)
	presentation_health_ready.emit(health)
	queue_redraw()

func apply_damage(request: DamageRequest, rng: RandomNumberGenerator) -> Dictionary:
	if health == null or request == null:
		return {}
	var received_increase := attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED)
	var effective_request := request
	if received_increase > 0.0:
		effective_request = request.copy()
		effective_request.damage_dealt_multiplier *= 1.0 + received_increase
	# E10a C1.7: generic sources, composed once (CombatMath) and applied on a copy.
	if not received_damage_sources.is_empty():
		var multiplier := CombatMath.received_damage_multiplier(received_damage_sources, request.source_id, request_element(request))
		if multiplier != 1.0:
			if effective_request == request: effective_request = request.copy()
			effective_request.damage_dealt_multiplier *= multiplier
	return health.apply(effective_request, 0.0 if effective_request.is_secondary and not effective_request.requires_hit_roll() else rng.randf(), 1.0 if effective_request.is_secondary else rng.randf(), attribute_debuffs)

func is_alive() -> bool:
	return health != null and health.is_alive()

## E10a T15 (A15.3): the single path of a barrier the actor gains. On a player, the
## barrier_received hook of the seam modules (origin, then evolution) composes the capacity
## before HealthState.grant_shield; other actors grant it as it is. Returns the capacity
## actually granted (the composed one; HealthState keeps the larger of it and the current
## barrier), or 0 when nothing was granted (dead actor, invalid or refused capacity).
## Producers keep the answer to recognise their own barrier at expiry. The modules are reached
## by method on purpose: naming ClassKit here closes the script cycle described at request_element.
func grant_barrier(capacity: float, source: StringName = &"") -> float:
	if health == null or not health.is_alive() or not is_finite(capacity) or capacity <= 0.0: return 0.0
	var value := capacity
	if has_method(&"kit_modules"):
		var context := {"source": source, "raw_capacity": capacity}
		var modules: Array = call(&"kit_modules")
		for module: Object in modules:
			if module == null or not module.has_method(&"barrier_received"): continue
			var next: Variant = module.call(&"barrier_received", self, value, context)
			if (typeof(next) == TYPE_FLOAT or typeof(next) == TYPE_INT) and is_finite(float(next)) and float(next) >= 0.0: value = float(next)
	if value <= 0.0 or not health.grant_shield(value): return 0.0
	return value

## E10a C1.7: element tag of a request, from the SkillDefinition of its skill (light and
## shadow skills always declare it); empty when the skill has none. The catalog is reached
## by path on purpose: naming ClassCatalog here closes a script cycle (CombatActor ->
## ClassCatalog -> ClassKitRegistry -> ClassKit -> PlayerActor) that Godot 4.7.2 does not
## release at exit (the E09 seam API, limitation "ciclos de script").
const _CLASS_CATALOG_PATH := "res://scripts/data/class_catalog.gd"
static func request_element(request: DamageRequest) -> StringName:
	if request == null: return &""
	var catalog := load(_CLASS_CATALOG_PATH) as Script
	var definition: Variant = catalog.call(&"skill_definition", request.skill_id) if catalog != null else null
	return StringName(definition.get(&"element")) if definition is Resource else &""

## E10a C1.7: adds or replaces a received-damage multiplier for `duration` seconds of the
## gameplay clock (pause-frozen; cleared with the statuses). Optional author and element filters.
func add_received_damage_source(source: StringName, multiplier: float, duration: float, owner_id: int = 0, element: StringName = &"") -> bool:
	if source.is_empty() or not is_alive() or not is_finite(multiplier) or multiplier < 0.0 or not is_finite(duration) or duration <= 0.0: return false
	received_damage_sources[source] = {"multiplier": multiplier, "owner_id": owner_id, "element": element, "remaining": duration}
	return true

func remove_received_damage_source(source: StringName) -> bool:
	return received_damage_sources.erase(source)

## Composed multiplier this actor would receive from `author_id` with `element`.
func received_damage_multiplier(author_id: int, element: StringName = &"") -> float:
	return CombatMath.received_damage_multiplier(received_damage_sources, author_id, element)

## E10a C1.7: adds or replaces a reduction (0..1) of this actor's own hit rating.
func add_accuracy_source(source: StringName, reduction: float, duration: float, owner_id: int = 0) -> bool:
	if source.is_empty() or not is_alive() or not is_finite(reduction) or reduction < 0.0 or reduction > 1.0 or not is_finite(duration) or duration <= 0.0: return false
	accuracy_sources[source] = {"reduction": reduction, "owner_id": owner_id, "remaining": duration}
	return true

func remove_accuracy_source(source: StringName) -> bool:
	return accuracy_sources.erase(source)

## Hit rating of an attack of this actor after its accuracy sources (CombatMath).
func outgoing_hit_rating(base_rating: float) -> float:
	return base_rating * CombatMath.accuracy_multiplier(accuracy_sources) if not accuracy_sources.is_empty() else base_rating

## E10a C1.7: short movement disorientation in the fear pattern (hard control with the
## magic CC resistance and caps). Bosses refuse it (0). `heading` is the wrong direction
## the actor walks; zero lets the actor choose (EnemyActor rolls it).
func apply_disorient(base_duration: float, heading: Vector2 = Vector2.ZERO) -> float:
	if not is_alive() or hard_controls.boss: return 0.0
	var applied := hard_controls.apply(&"disorient", base_duration, stat_breakdown.value(&"magic_cc_resistance"))
	if applied > 0.0:
		disorient_heading = heading.normalized() if heading.is_finite() and not heading.is_zero_approx() else Vector2.ZERO
		queue_redraw()
	return applied

func is_disoriented() -> bool:
	return hard_controls.is_active(&"disorient")

func disorient_remaining() -> float:
	return hard_controls.remaining(&"disorient")

## E09 C1.5: authoritative gameplay facing, the same direction the presentation
## draws (canvas space: the 2D arena, or the projected view of the world). An
## active override wins and is also what the sprite shows.
func gameplay_facing() -> Vector2:
	if _facing_override_remaining > 0.0: return _facing_override
	if character_animation != null and character_animation.state.facing.is_finite() and not character_animation.state.facing.is_zero_approx(): return character_animation.state.facing.normalized()
	return Vector2.RIGHT

## Gameplay facing on the ground plane (x/z). In the flat arena x/y map to x/z.
func gameplay_ground_facing() -> Vector3:
	var facing := gameplay_facing()
	if world_motion == null: return Vector3(facing.x, 0.0, facing.y).normalized()
	return canvas_to_ground_direction(facing)

## Inverse of the shared projection for a horizontal direction (y = 0).
static func canvas_to_ground_direction(direction: Vector2) -> Vector3:
	var axis := ProjectionMath.AXIS
	var difference := direction.x / axis.x
	var total := direction.y / axis.y
	var ground := Vector3((difference + total) * 0.5, 0.0, (total - difference) * 0.5)
	return ground.normalized() if not ground.is_zero_approx() else Vector3.RIGHT

static func ground_to_canvas_direction(direction: Vector3) -> Vector2:
	var projected := ProjectionMath.project(Vector3(direction.x, 0.0, direction.z))
	return projected.normalized() if not projected.is_zero_approx() else Vector2.RIGHT

## Temporary "turn": the gameplay facing (and the drawn facing) becomes `direction`
## for `duration` seconds of gameplay clock. A new override replaces the previous one.
func override_gameplay_facing(direction: Vector2, duration: float, owner: StringName = &"") -> bool:
	if not is_alive() or not direction.is_finite() or direction.is_zero_approx() or not is_finite(duration) or duration <= 0.0: return false
	_facing_override = direction.normalized()
	_facing_override_remaining = duration
	_facing_override_owner = owner
	if character_animation != null: character_animation.state.face(_facing_override)
	queue_redraw()
	return true

## Same override from a ground direction; in the flat arena x/z map to x/y.
func override_gameplay_ground_facing(direction: Vector3, duration: float, owner: StringName = &"") -> bool:
	var canvas := Vector2(direction.x, direction.z) if world_motion == null else ground_to_canvas_direction(direction)
	return override_gameplay_facing(canvas, duration, owner)

func gameplay_facing_override_remaining() -> float:
	return _facing_override_remaining

func gameplay_facing_override_owner() -> StringName:
	return _facing_override_owner if _facing_override_remaining > 0.0 else &""

func clear_gameplay_facing_override() -> void:
	_facing_override = Vector2.ZERO
	_facing_override_remaining = 0.0
	_facing_override_owner = &""

func is_burning() -> bool:
	return burn_remaining > 0.0

func is_electrified() -> bool:
	return electrified_remaining > 0.0

func consume_electrified() -> bool:
	if not is_electrified():
		return false
	electrified_remaining = 0.0
	queue_redraw()
	return true

func apply_electrified(duration: float) -> void:
	if not is_alive() or duration <= 0.0:
		return
	electrified_remaining = duration
	queue_redraw()

func apply_burn(request: DamageRequest, duration: float = 3.0) -> void:
	if not is_alive() or request == null or duration <= 0.0 or request.physical_damage + request.magic_damage <= 0.0:
		return
	var key := "%d:burn_tick" % request.source_id
	if not burn_streams.has(key) and burn_streams.size() + bleed_streams.size() >= 4:
		return
	var previous: Dictionary = burn_streams.get(key, {})
	var captured := request.copy()
	captured.target_id = get_instance_id()
	captured.skill_id = &"burn_tick"
	captured.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	captured.can_crit = false
	captured.force_critical = false
	captured.is_secondary = true
	burn_streams[key] = {"request": captured, "remaining": maxf(duration, float(previous.get("remaining", 0.0))), "tick_remaining": float(previous.get("tick_remaining", minf(1.0, duration)))}
	burn_request = captured # Legacy presentation/preview of the latest applied burn.
	_sync_burn_display()
	queue_redraw()

func apply_bleed(request: DamageRequest, duration: float = 4.0) -> void:
	if not is_alive() or request == null or duration <= 0.0 or request.physical_damage <= 0.0 or request.source_id <= 0 or request.skill_id.is_empty():
		return
	var key := "%d:%s" % [request.source_id, request.skill_id]
	if not bleed_streams.has(key) and bleed_streams.size() + burn_streams.size() >= 4:
		return
	var tick_remaining := float(bleed_streams[key].get("tick_remaining", 1.0)) if bleed_streams.has(key) else 1.0
	var captured := request.copy()
	captured.target_id = get_instance_id()
	captured.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	captured.can_crit = false
	captured.force_critical = false
	captured.is_secondary = true
	bleed_streams[key] = {"request": captured, "remaining": maxf(duration, float(bleed_streams.get(key, {}).get("remaining", 0.0))), "tick_remaining": tick_remaining}
	queue_redraw()

func set_berserker_wound_visual(stacks: int, remaining: float) -> void:
	var normalized_stacks := clampi(stacks, 0, 3)
	var normalized_remaining := maxf(0.0, remaining) if normalized_stacks > 0 else 0.0
	if normalized_stacks > berserker_wound_visual_stacks:
		_berserker_wound_visual_pulse = 0.25
	if normalized_stacks == berserker_wound_visual_stacks and is_equal_approx(normalized_remaining, berserker_wound_visual_remaining):
		return
	berserker_wound_visual_stacks = normalized_stacks
	berserker_wound_visual_remaining = normalized_remaining
	queue_redraw()

func apply_attribute_debuff(attribute: StringName, source: StringName, fraction: float, duration: float) -> bool:
	if not is_alive() or not attribute_debuffs.apply(attribute, source, fraction, duration):
		return false
	_sync_debuff_display()
	queue_redraw()
	return true

func remove_attribute_debuff(attribute: StringName, source: StringName) -> bool:
	if not attribute_debuffs.remove(attribute, source):
		return false
	_sync_debuff_display()
	queue_redraw()
	return true

func apply_slow(fraction: float, duration: float, source: StringName = &"") -> void:
	# Legacy direct callers use the magnitude as identity; skill callers provide an ID.
	var resolved_source := source if not source.is_empty() else StringName("slow_%d" % roundi(fraction * 1000.0))
	apply_attribute_debuff(AttributeDebuffState.MOVE_SPEED, resolved_source, fraction, duration)

func configure_hard_control_profile(is_boss: bool) -> void:
	hard_controls.configure(is_boss)
	queue_redraw()

func apply_root(base_duration: float, control_tag: StringName = &"physical") -> float:
	if not is_alive() or control_tag not in [&"physical", &"magic"]:
		return 0.0
	var resistance_id := &"physical_cc_resistance" if control_tag == &"physical" else &"magic_cc_resistance"
	var applied_duration := hard_controls.apply(&"root", base_duration, stat_breakdown.value(resistance_id))
	if applied_duration > 0.0:
		queue_redraw()
	return applied_duration

func is_rooted() -> bool:
	return hard_controls.is_active(&"root")

func root_remaining() -> float:
	return hard_controls.remaining(&"root")

func apply_stun(base_duration: float) -> float:
	if not is_alive():
		return 0.0
	var applied_duration := hard_controls.apply(&"stun", base_duration, stat_breakdown.value(&"magic_cc_resistance"))
	if applied_duration > 0.0:
		queue_redraw()
	return applied_duration

func is_stunned() -> bool:
	return hard_controls.is_active(&"stun")

func stun_remaining() -> float:
	return hard_controls.remaining(&"stun")

func apply_fear(base_duration: float) -> float:
	if not is_alive():
		return 0.0
	var applied_duration := hard_controls.apply(&"fear", base_duration, stat_breakdown.value(&"magic_cc_resistance"))
	if applied_duration > 0.0:
		queue_redraw()
	return applied_duration

func is_feared() -> bool:
	return hard_controls.is_active(&"fear")

func fear_remaining() -> float:
	return hard_controls.remaining(&"fear")

func apply_weaken(fraction: float, duration: float, source: StringName = &"") -> void:
	var resolved_source := source if not source.is_empty() else StringName("weaken_%d" % roundi(fraction * 1000.0))
	apply_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, resolved_source, fraction, duration)

func outgoing_damage_multiplier() -> float:
	return StatCalculator.runtime_reduced_value(&"damage_dealt_multiplier", stat_breakdown.value(&"damage_dealt_multiplier"), attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT))

func attacks_per_second() -> float:
	return StatCalculator.runtime_reduced_value(&"attacks_per_second", stat_breakdown.value(&"attacks_per_second"), attribute_debuffs.fraction(AttributeDebuffState.ATTACK_SPEED))

func set_unstoppable(duration: float) -> bool:
	var changed := hard_controls.set_unstoppable(duration)
	if changed:
		queue_redraw()
	return changed

func movement_speed_multiplier() -> float:
	return 1.0 - attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED)

func _sync_debuff_display() -> void:
	slow_fraction = attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED)
	slow_remaining = attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED)
	weaken_fraction = attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT)
	weaken_remaining = attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT)

func clear_statuses() -> void:
	burn_remaining = 0.0
	burn_tick_remaining = 0.0
	burn_request = null
	burn_streams.clear()
	bleed_streams.clear()
	berserker_wound_visual_stacks = 0
	berserker_wound_visual_remaining = 0.0
	_berserker_wound_visual_pulse = 0.0
	attribute_debuffs.clear()
	_sync_debuff_display()
	electrified_remaining = 0.0
	hard_controls.clear()
	marks.clear()
	received_damage_sources.clear()
	accuracy_sources.clear()
	disorient_heading = Vector2.ZERO
	clear_gameplay_facing_override()
	queue_redraw()

func advance_statuses(delta: float, simulation_paused: bool = false) -> void:
	if simulation_paused or not is_alive() or delta <= 0.0:
		return
	var was_rooted := is_rooted()
	var was_stunned := is_stunned()
	var was_feared := is_feared()
	marks.advance(delta)
	if _facing_override_remaining > 0.0:
		_facing_override_remaining = maxf(0.0, _facing_override_remaining - delta)
		if _facing_override_remaining <= 0.0: clear_gameplay_facing_override()
	hard_controls.advance(delta)
	_advance_modifier_sources(received_damage_sources, delta)
	_advance_modifier_sources(accuracy_sources, delta)
	if was_rooted != is_rooted() or was_stunned != is_stunned() or was_feared != is_feared():
		queue_redraw()
	var previous_slow := slow_fraction
	var previous_weaken := weaken_fraction
	attribute_debuffs.advance(delta)
	_sync_debuff_display()
	if previous_slow != slow_fraction or previous_weaken != weaken_fraction:
		queue_redraw()
	if electrified_remaining > 0.0:
		electrified_remaining = maxf(0.0, electrified_remaining - delta)
		queue_redraw()
	var burn_keys: Array = burn_streams.keys()
	burn_keys.sort()
	for key: String in burn_keys:
		if not burn_streams.has(key) or not is_alive():
			break
		var stream: Dictionary = burn_streams[key]
		var remaining_delta := delta
		while float(stream["remaining"]) > 0.0 and remaining_delta > 0.0:
			var step := minf(remaining_delta, minf(float(stream["remaining"]), float(stream["tick_remaining"])))
			stream["remaining"] = maxf(0.0, float(stream["remaining"]) - step)
			stream["tick_remaining"] = maxf(0.0, float(stream["tick_remaining"]) - step)
			remaining_delta = maxf(0.0, remaining_delta - step)
			if float(stream["tick_remaining"]) <= 0.0001:
				# Commit the clock before callbacks; a listener may renew/remove the stream.
				stream["tick_remaining"] = 1.0
				var tick: DamageRequest = (stream["request"] as DamageRequest).scheduled_tick()
				status_damage_requested.emit(tick, self)
				if not is_alive() or not burn_streams.has(key) or burn_streams[key] != stream:
					break
		if burn_streams.has(key) and burn_streams[key] == stream and float(stream["remaining"]) <= 0.0:
			burn_streams.erase(key)
	_sync_burn_display()
	for key: String in bleed_streams.keys():
		if not bleed_streams.has(key) or not is_alive():
			break
		var stream: Dictionary = bleed_streams[key]
		var bleed_delta := delta
		while float(stream["remaining"]) > 0.0 and bleed_delta > 0.0:
			var step := minf(bleed_delta, minf(float(stream["remaining"]), float(stream["tick_remaining"])))
			stream["remaining"] = maxf(0.0, float(stream["remaining"]) - step)
			stream["tick_remaining"] = maxf(0.0, float(stream["tick_remaining"]) - step)
			bleed_delta = maxf(0.0, bleed_delta - step)
			if float(stream["tick_remaining"]) <= 0.0001:
				var tick: DamageRequest = (stream["request"] as DamageRequest).scheduled_tick()
				stream["tick_remaining"] = 1.0
				status_damage_requested.emit(tick, self)
				if not is_alive() or not bleed_streams.has(key) or bleed_streams[key] != stream:
					break
		if not is_alive():
			break
		if bleed_streams.has(key) and bleed_streams[key] == stream and float(stream["remaining"]) <= 0.0:
			bleed_streams.erase(key)
			queue_redraw()

## E10a C1.7: the modifier clocks run with the other statuses (pause-frozen).
static func _advance_modifier_sources(sources: Dictionary, delta: float) -> void:
	for key: Variant in sources.keys():
		var entry: Dictionary = sources[key]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if float(entry["remaining"]) <= 0.0: sources.erase(key)

## Screen-space body the player sees (local canvas units); picking only, never collision or reach.
func pick_body_rect() -> Rect2:
	var height := maxf(40.0, (_sprite_visible_height if _sprite_visible_height > 0.0 else 52.0) * sprite_visual_scale)
	var half_width := maxf(collision_radius + 4.0, height * 0.4)
	return Rect2(Vector2(-half_width, -height), Vector2(half_width * 2.0, height + 8.0))

func set_hovered(value: bool) -> void:
	if is_hovered == value:
		return
	is_hovered = value
	queue_redraw()

func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	queue_redraw()

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	var visual_position := global_position
	if character_animation != null:
		character_animation.observe(visual_position, delta)
	_update_presentation(visual_position)
	advance_statuses(delta)
	# The drawn facing follows an active gameplay override (A3: visual and rule agree).
	if _facing_override_remaining > 0.0 and character_animation != null: character_animation.state.face(_facing_override)
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		queue_redraw()
	if _berserker_wound_visual_pulse > 0.0:
		_berserker_wound_visual_pulse = maxf(0.0, _berserker_wound_visual_pulse - delta)
		queue_redraw()
	_advance_cast_bar(delta)

## E12 H4: samples the read-only cast clock and asks for a redraw only while a cast or its
## flash is on screen (plus one final redraw that erases the bar).
func _advance_cast_bar(delta: float) -> void:
	var progress := cast_progress()
	if bool(progress.get("active", false)):
		_cast_last = progress
		_cast_flash_time = 0.0
		_cast_flash_kind = &""
		queue_redraw()
		return
	if _cast_flash_time > 0.0:
		_cast_flash_time = maxf(0.0, _cast_flash_time - delta)
		queue_redraw()
		if _cast_flash_time > 0.0: return
		_cast_flash_kind = &""
	_cast_last = {}
	if _cast_bar_drawn:
		_cast_bar_drawn = false
		queue_redraw()

func _update_presentation(visual_position: Vector2) -> void:
	var previous_animation: Array = _presentation_key[0] if not _presentation_key.is_empty() else []
	var animation := previous_animation
	if character_animation != null:
		animation = character_animation._draw_key_after(previous_animation)
	elif not previous_animation.is_empty():
		animation = []
	# Inspect the bound point here without making a detached gameplay DTO on
	# each frame. Only its value fields enter the presentation snapshot.
	var anchor := world_motion._point if world_motion != null else null
	var position_key: Variant = anchor.position if anchor != null else visual_position
	var surface_id := anchor.surface_id if anchor != null else ""
	var configuration_revision := world_motion.geometry.configuration_revision if world_motion != null else -1
	var geometry_revision := world_motion.geometry.geometry_revision if world_motion != null else -1
	var hp := health.current_hp if health != null else 0.0
	var max_hp := health.max_hp if health != null else 0.0
	if _presentation_key.is_empty() or not is_same(animation, previous_animation) \
			or position_key != _presentation_key[1] or surface_id != _presentation_key[2] \
			or configuration_revision != _presentation_key[3] or geometry_revision != _presentation_key[4] \
			or hp != _presentation_key[5] or max_hp != _presentation_key[6] \
			or sprite_visual_scale != _presentation_key[7] or contact_shadows_enabled != _presentation_key[8]:
		_presentation_key = [animation, position_key, surface_id, configuration_revision, geometry_revision,
			hp, max_hp, sprite_visual_scale, contact_shadows_enabled]
		queue_redraw()
	elif body_drawer.is_valid():
		queue_redraw()

func _draw() -> void:
	if contact_shadows_enabled:
		if world_motion == null: GroundShadow.draw_flat(self)
		elif world_motion.is_current_world() and world_point() != null:
			var world := world_motion.geometry; world._ensure_support_index()
			var point := world_point()
			var radius := clampf(collision_radius*0.72*sqrt(maxf(0.25,sprite_visual_scale)),5.0,128.0)
			var epoch: Array = [world.get_instance_id(),world.configuration_revision,world.geometry_revision]
			GroundShadow.draw_on(self,point.position,Vector2.ONE*radius,world._support_index,point.surface_id,ProjectionMath.project,_ground_shadow_cache,epoch)
	var color := Color.WHITE if _flash_time > 0.0 else actor_color
	if is_selected:
		_draw_target_ring(collision_radius + 14.0, Color("f5cc77"), 3.0)
	elif is_hovered:
		_draw_target_ring(collision_radius + 11.0, Color("81dfd0"), 2.0)
	if body_drawer.is_valid():
		body_drawer.call(self)
	elif character_animation != null:
		character_animation.draw_on(self, Color(2.0, 2.0, 2.0) if _flash_time > 0.0 else PilotVisual.forest_tint(self), sprite_visual_scale)
	elif sprite_texture != null:
		var tint := Color(2.0, 2.0, 2.0) if _flash_time > 0.0 else Color.WHITE
		draw_texture_rect(sprite_texture, sprite_rect, false, tint)
	else:
		draw_circle(Vector2(0, -18), collision_radius, color)
		draw_circle(Vector2(0, -22), collision_radius * 0.55, color.lightened(0.14))
	if health != null:
		var bar_width := 104.0 if sprite_visual_scale > 1.0 else 52.0
		var ratio := health.current_hp / health.max_hp
		var bar_y := overhead_bar_y()
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 6), Color(0.08, 0.09, 0.12, 0.9))
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, 6), Color("dc5757"))
		_draw_cast_bar(bar_y + 7.0, bar_width)
	if berserker_wound_visual_stacks > 0:
		var wound_y := -_sprite_visible_height - 15.0
		for index: int in range(3):
			var center := Vector2((float(index) - 1.0) * 11.0, wound_y)
			var diamond := PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)])
			draw_colored_polygon(diamond, Color("f6dfc0") if index < berserker_wound_visual_stacks else Color("3e3440"))
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("4b2434"), 1.0, true)
		var expiry_ratio := clampf(berserker_wound_visual_remaining / 8.0, 0.0, 1.0)
		draw_arc(Vector2(0, wound_y), 21.0, -PI * 0.5, -PI * 0.5 + TAU * expiry_ratio, 32, Color("f6dfc0"), 1.5, true)
		if _berserker_wound_visual_pulse > 0.0:
			var alpha := _berserker_wound_visual_pulse / 0.25
			draw_line(Vector2(-12, -32), Vector2(5, -17), Color(0.98, 0.93, 0.79, alpha), 2.5, true)
			draw_line(Vector2(1, -32), Vector2(16, -21), Color(0.88, 0.30, 0.37, alpha), 2.5, true)
	if is_burning():
		draw_arc(Vector2(0, 3), collision_radius + 6.0, 0.0, TAU, 24, Color("ff7a3d"), 2.0, true)
	if not bleed_streams.is_empty():
		draw_arc(Vector2(0, 4), collision_radius + 7.0, -PI * 0.75, PI * 0.25, 20, Color("d65572"), 2.0, true)
	if slow_remaining > 0.0:
		if compact_control_visuals:
			for side: float in [-1.0, 1.0]:
				var point := Vector2(side * 12, 4)
				draw_polyline(PackedVector2Array([point + Vector2(-side * 3, -2), point, point + Vector2(-side * 3, 2)]), Color("72c9ff"), 1.5, true)
		else:
			draw_arc(Vector2(0, 6), collision_radius + 9.0, 0.0, TAU, 24, Color("72c9ff"), 2.0, true)
	if is_electrified():
		for side: float in [-1.0, 1.0]:
			var x := side * (collision_radius + 8.0)
			draw_polyline(PackedVector2Array([Vector2(x, -34), Vector2(x - side * 5.0, -24), Vector2(x + side * 2.0, -24), Vector2(x - side * 4.0, -13)]), Color("e9d76a"), 2.5, true)
	if is_rooted():
		if compact_control_visuals:
			for side: float in [-1.0, 1.0]:
				var point := Vector2(side * 8, 7)
				draw_polyline(PackedVector2Array([point + Vector2(0, -4), point, point + Vector2(-side * 5, 0)]), Color("d9bd72"), 2.0, true)
		else:
			draw_arc(Vector2(0, 7), collision_radius + 12.0, 0.0, TAU, 24, Color("d9bd72"), 3.0, true)
	if is_stunned():
		draw_arc(Vector2(0, -18), collision_radius + 13.0, -PI * 0.9, -PI * 0.1, 20, Color("f9e585"), 3.0, true)
	if is_feared():
		draw_arc(Vector2(0, -18), collision_radius + 16.0, -PI * 0.8, PI * 0.8, 28, Color("ba8de9"), 3.0, true)
	if weaken_remaining > 0.0:
		draw_arc(Vector2(0, 8), collision_radius + 17.0, 0.0, TAU, 28, Color("a889c4", 0.8), 1.5, true)

## E12 H4: the thin cast bar right below the HP bar. The player has the HUD bar above the
## action bar, so a `player` category never draws here. Name only for elite, rare elite and
## boss (D5); it sits under the bar and may cross the top of the body (see the H4 receipt).
func _draw_cast_bar(top_y: float, width: float) -> void:
	if _cast_last.is_empty(): return
	var category: Variant = _cast_last.get("category", &"")
	if category == &"player": return
	var flash := _cast_flash_kind if _cast_flash_time > 0.0 else &""
	ActorCastBar.draw_overhead(self, _cast_last, top_y, width, flash, category in CAST_LABEL_CATEGORIES)
	_cast_bar_drawn = true

## Local y of the top of the overhead HP bar (E12 C2), the same value _draw uses. The cast
## bar and the overhead kit markers take it as their reference. Presentation only.
func overhead_bar_y() -> float:
	return -_sprite_visible_height * sprite_visual_scale - 8.0 if sprite_texture != null else -54.0 * sprite_visual_scale

## Read-only view of the cast clock (E12 C2). Default: no cast. PlayerActor and
## EnemyActor override it; no rule, signal or field changes. With a cast:
## {"active": true, "skill_id", "label" (pt-BR), "total", "remaining", "kind", "category"}.
func cast_progress() -> Dictionary:
	return {"active": false}

func _draw_target_ring(radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in range(49):
		var angle := TAU * index / 48.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 + 4.0))
	draw_polyline(points, Color(0.03, 0.07, 0.09, 0.85), width + 3.0, true)
	draw_polyline(points, color, width, true)
	for sign_value: float in [-1.0, 1.0]:
		var edge := Vector2(sign_value * (radius + 5.0), 4.0)
		draw_line(edge - Vector2(0, 5), edge + Vector2(0, 5), color, 2.0, true)

func _on_damage_applied(result: Dictionary) -> void:
	if not bool(result["landed"]):
		attack_missed.emit(self)
		return
	if float(result["actual_damage"]) <= 0.0:
		return
	_flash_time = 0.10
	if character_animation != null:
		character_animation.play(&"hurt")
	damage_number.emit(self, ceili(float(result["actual_damage"])), bool(result["critical"]))
	queue_redraw()

func _on_health_died(_actor_id: int) -> void:
	if character_animation != null:
		character_animation.play(&"death")
	clear_statuses()
	actor_died.emit(self)
	queue_redraw()

func _sync_burn_display() -> void:
	var was_burning := is_burning()
	burn_remaining = 0.0
	burn_tick_remaining = 0.0
	for stream: Dictionary in burn_streams.values():
		burn_remaining = maxf(burn_remaining, float(stream["remaining"]))
		burn_tick_remaining = float(stream["tick_remaining"])
	if burn_streams.is_empty():
		burn_request = null
	if was_burning != is_burning() or berserker_wound_visual_stacks > 0:
		queue_redraw()
func _exit_tree() -> void:
	if world_motion != null: world_motion.release()
