class_name SanctuaryAuthority
extends RefCounted
## E09 T5 (C2) — family authority of Santuário and Graça (Sacerdote family: Paladino,
## Taumaturgo, later Sacerdote, Inquisidor, Exorcista, Hierofante, Asceta).
## A kit keeps ONE instance in a field and forwards the T1 seam hooks to it
## (docs/epics/e09/t5_delivery.md lists the forwarding). Only T1 hooks and PlayerActor
## kit helpers reach the actors. State is run state: no Node, Callable or actor
## reference is stored; entities are kept as IDs (owner_id, marked_target_id).

var owner_id := 0
## Causal family of Grace event keys (the kit's family, e.g. paladin_grace).
var grace_family: StringName = &"grace"
## role -> SanctuaryZone. One zone per owner and role.
var zones: Dictionary = {}
var grace := SanctuaryGrace.new()
var presence_remaining := SanctuaryRules.PRESENCE_INTERVAL
var tick_serial := 0
var aegis_remaining := 0.0
var aegis_capacity := 0.0
var aegis_radius := SanctuaryRules.AEGIS_PULSE_RADIUS
var aegis_prototype: DamageRequest
var aegis_pulses := 0
var marked_target_id := 0
var seal_key: StringName = &""
## Temporary stat source of the ice rule (T1.1 hook), with the kit prefix.
var stat_source_id: StringName = &"sanctuary_ice_defense"
## Ice defense currently published to the owner's breakdown (0 when none).
var ice_defense_applied := 0.0
## Per-tick memo "rule:target" so no rule applies twice in one tick. Cleared at the
## start of every tick (omitted from the snapshot: it is empty between ticks).
var _applied: Dictionary = {}

## Called once from the kit's on_attach. `family` is the kit's Grace family and
## `source_id` the kit-prefixed ID of the ice defense stat source.
func configure(player: PlayerActor, family: StringName = &"grace", source_id: StringName = &"") -> void:
	owner_id = player.get_instance_id() if is_instance_valid(player) else 0
	if not family.is_empty(): grace_family = family
	if not source_id.is_empty(): stat_source_id = source_id

# --- Zones ---------------------------------------------------------------------

## Opens (or replaces) the zone of `config.role`. Config keys: role (required),
## skill_id (required), shape, anchor, point (ExpeditionWorldPoint or Vector2; default
## the owner), radius, half_angle, wide_scale, duration, pulse_interval, element,
## rules (SanctuaryRules.RULES overrides), family_id. Call it while resolving the cast:
## the burn prototype is captured with the cast's causal root.
func open_zone(player: PlayerActor, config: Dictionary) -> Dictionary:
	if not is_instance_valid(player) or not player.is_alive(): return SanctuaryRules.failure(&"invalid_owner")
	_bind_owner(player)
	var role := StringName(config.get("role", &""))
	var skill := StringName(config.get("skill_id", &""))
	if role.is_empty() or skill.is_empty(): return SanctuaryRules.failure(&"invalid_zone", "role and skill_id are required")
	var shape := StringName(config.get("shape", SanctuaryRules.SHAPE_CIRCLE))
	if shape not in SanctuaryRules.SHAPES: return SanctuaryRules.failure(&"invalid_shape", String(shape))
	var anchor := StringName(config.get("anchor", SanctuaryRules.ANCHOR_OWNER if shape == SanctuaryRules.SHAPE_CONE else SanctuaryRules.ANCHOR_WORLD))
	if anchor not in SanctuaryRules.ANCHORS or (shape == SanctuaryRules.SHAPE_CONE and anchor != SanctuaryRules.ANCHOR_OWNER): return SanctuaryRules.failure(&"invalid_anchor", String(anchor))
	var base := float(config.get("radius", SanctuaryRules.default_radius(shape)))
	var radius_range := SanctuaryRules.CONE_RADIUS_RANGE if shape == SanctuaryRules.SHAPE_CONE else SanctuaryRules.CIRCLE_RADIUS_RANGE
	if not SanctuaryRules.in_range(base, radius_range): return SanctuaryRules.failure(&"invalid_radius", str(base))
	var scale := float(config.get("wide_scale", SanctuaryRules.WIDE_SCALE))
	if shape == SanctuaryRules.SHAPE_WIDE_CIRCLE and not SanctuaryRules.in_range(scale, SanctuaryRules.WIDE_SCALE_RANGE): return SanctuaryRules.failure(&"invalid_radius", "wide_scale")
	var half := float(config.get("half_angle", SanctuaryRules.CONE_HALF_ANGLE))
	if not SanctuaryRules.in_range(half, SanctuaryRules.CONE_HALF_ANGLE_RANGE): return SanctuaryRules.failure(&"invalid_angle", str(half))
	var duration := float(config.get("duration", SanctuaryRules.DURATION))
	if not SanctuaryRules.in_range(duration, SanctuaryRules.DURATION_RANGE): return SanctuaryRules.failure(&"invalid_duration", str(duration))
	var interval := float(config.get("pulse_interval", SanctuaryRules.PULSE_INTERVAL))
	if not SanctuaryRules.in_range(interval, SanctuaryRules.PULSE_INTERVAL_RANGE): return SanctuaryRules.failure(&"invalid_pulse", str(interval))
	var element := StringName(config.get("element", SanctuaryRules.ELEMENT_NONE))
	if element not in SanctuaryRules.ELEMENTS: return SanctuaryRules.failure(&"invalid_element", String(element))
	var checked := SanctuaryRules.validate_rules(config.get("rules", {}))
	if not checked["ok"]: return checked
	var zone := SanctuaryZone.new()
	zone.role = role
	zone.owner_id = player.get_instance_id()
	zone.shape = shape
	zone.base_radius = base
	zone.radius = base * (scale if shape == SanctuaryRules.SHAPE_WIDE_CIRCLE else 1.0)
	zone.half_angle = half
	zone.anchor_mode = anchor
	zone.duration = duration
	zone.remaining = duration
	zone.pulse_interval = interval
	zone.pulse_remaining = interval
	zone.element = element
	zone.rules = checked["rules"]
	zone.skill_id = skill
	zone.family_id = StringName(config.get("family_id", skill))
	if anchor == SanctuaryRules.ANCHOR_WORLD:
		var point: Variant = config.get("point")
		if player.world_motion != null:
			var world_point := point as ExpeditionWorldPoint if point is ExpeditionWorldPoint else player.world_point()
			if not player.world_motion.is_current_world() or world_point == null: return SanctuaryRules.failure(&"invalid_anchor", "world point")
			var area := WorldEffectArea.new()
			var geometry: WorldGeometry = player.world_motion.geometry
			var placed := area.configure(geometry, world_point, player.world_motion.profile(), &"ground_connected", geometry.geometry_revision)
			if not placed["ok"]: return SanctuaryRules.failure(&"invalid_anchor", str(placed.get("error_code", "")))
			zone.area = area
		else:
			zone.center = point if point is Vector2 else player.global_position
	var amount := player.stat_breakdown.value(StringName(zone.rules["burn_stat"])) * float(zone.rules["burn_ratio"])
	if amount > 0.0:
		var prototype := player.kit_make_request(null, skill, 0.0, amount, DamageRequest.AccuracyMode.GEOMETRY, false)
		prototype.is_secondary = true
		zone.prototype = prototype
	zones[role] = zone
	zone.owner_inside = zone.contains(player, player)
	sync_stats(player)
	return {"ok": true, "error_code": &"", "zone": zone}

## Convenience: point of a T1 cast descriptor (world anchor or flat point).
static func cast_point(cast: Dictionary) -> Variant:
	if bool(cast.get("world", false)) and cast.get("anchor") is ExpeditionWorldPoint: return cast["anchor"]
	return cast.get("point", Vector2.ZERO)

func zone(role: StringName) -> SanctuaryZone:
	var found: SanctuaryZone = zones.get(role)
	return found if found != null and found.is_active() else null

func has_active_zone() -> bool:
	for role: StringName in zones:
		if (zones[role] as SanctuaryZone).is_active(): return true
	return false

## Ends a zone. With the owner, the ice defense leaves the breakdown at once;
## otherwise at the next tick.
func end_zone(role: StringName, player: PlayerActor = null) -> bool:
	if not zones.has(role): return false
	(zones[role] as SanctuaryZone)._inside.clear()
	zones.erase(role)
	if player != null: sync_stats(player)
	return true

func set_zone_shape(role: StringName, shape: StringName, radius: float = 0.0) -> Dictionary:
	var found := zone(role)
	return found.set_shape(shape, radius) if found != null else SanctuaryRules.failure(&"no_zone", String(role))

func set_zone_element(role: StringName, element: StringName, player: PlayerActor = null) -> bool:
	var found := zone(role)
	if found == null or not found.set_element(element): return false
	if player != null: sync_stats(player)
	return true

## True when the owner stands inside some active zone (presence of the last check).
func owner_inside_any() -> bool:
	for role: StringName in zones:
		var found: SanctuaryZone = zones[role]
		if found.is_active() and found.owner_inside: return true
	return false

## Immediate pulse of one zone (optionally with another element, as the Mudança de
## Altar pulse of the old element). Same-tick rules still apply once per target.
func pulse_now(player: PlayerActor, role: StringName, element: StringName = &"", actors: Array = []) -> int:
	var found := zone(role)
	if found == null or not is_instance_valid(player) or not player.is_alive(): return 0
	if not element.is_empty() and element not in SanctuaryRules.ELEMENTS: return 0
	return _pulse(player, found, SanctuaryHelpers.enemies_of(player, actors), found.element if element.is_empty() else element)

# --- Gameplay clock (forward from ClassKit.on_tick: never in pause, never dead) --------

func tick(player: PlayerActor, delta: float, actors: Array = []) -> void:
	if not is_instance_valid(player) or not player.is_alive() or delta <= 0.0 or not is_finite(delta): return
	_bind_owner(player)
	tick_serial += 1
	_applied.clear()
	var enemies := SanctuaryHelpers.enemies_of(player, actors)
	presence_remaining -= delta
	var refresh := presence_remaining <= 0.0
	if refresh: presence_remaining = SanctuaryRules.PRESENCE_INTERVAL
	var expired: Array[StringName] = []
	var roles: Array = zones.keys()
	roles.sort()
	var sp_bonus := 0.0
	for role: StringName in roles:
		var found: SanctuaryZone = zones[role]
		var old_pulse := found.pulse_remaining
		var old_remaining := found.remaining
		found.pulse_remaining -= delta
		if refresh: found.owner_inside = found.contains(player, player)
		if found.pulse_remaining <= 0.0:
			if old_pulse <= old_remaining:
				found.owner_inside = found.contains(player, player)
				_pulse(player, found, enemies, found.element)
			found.pulse_remaining = found.pulse_remaining + found.pulse_interval if found.pulse_remaining + found.pulse_interval > 0.0 else found.pulse_interval
		if found.owner_inside and SanctuaryRules.has_lightning(found.element): sp_bonus = maxf(sp_bonus, float(found.rules["lightning_sp_regen"]))
		found.remaining = maxf(0.0, old_remaining - delta)
		if found.remaining <= 0.0: expired.append(role)
	if sp_bonus > 0.0 and not _applied.has("lightning_sp"):
		_applied["lightning_sp"] = true
		if player.recover_sp(player.stat_breakdown.value(&"sp_regen") * sp_bonus * delta) > 0.0: player.resources_changed.emit()
	for role: StringName in expired: end_zone(role)
	sync_stats(player)
	_tick_aegis(player, delta, enemies)
	_tick_seal()
	grace.tick(delta, has_active_zone())

func _pulse(player: PlayerActor, found: SanctuaryZone, enemies: Array, element: StringName) -> int:
	found.pulses += 1
	found._inside.clear()
	var tick_request: DamageRequest
	if found.prototype != null:
		var amount := found.prototype.magic_damage * (float(found.rules["fire_burn_multiplier"]) if SanctuaryRules.has_fire(element) else 1.0)
		tick_request = found.prototype.scheduled_tick()
		if tick_request.cancelled or amount <= 0.0: tick_request = null
		else:
			tick_request.magic_damage = amount
			if tick_request.context != null: tick_request.context.family_id = found.family_id
	var affected := 0
	# One ground area at the owner per pulse (owner-anchored zones in the world).
	var query_area := SanctuaryZone.owner_area(player) if player.world_motion != null and found.anchor_mode == SanctuaryRules.ANCHOR_OWNER else null
	for candidate: Variant in enemies:
		var enemy := candidate as CombatActor
		if not is_instance_valid(enemy) or enemy == player or not found.contains(player, enemy, query_area): continue
		var id := enemy.get_instance_id()
		found._inside[id] = true
		affected += 1
		if tick_request != null and not _applied.has("burn:%d" % id):
			_applied["burn:%d" % id] = true
			var hit := tick_request.copy()
			hit.target_id = id
			player.kit_emit_hit(hit, enemy)
		if SanctuaryRules.has_ice(element) and float(found.rules["ice_slow"]) > 0.0 and is_instance_valid(enemy) and enemy.is_alive() and not _applied.has("slow:%d" % id):
			_applied["slow:%d" % id] = true
			enemy.apply_slow(float(found.rules["ice_slow"]), float(found.rules["ice_slow_duration"]), SanctuaryRules.SLOW_SOURCE)
	return affected

# --- Owner rules (forward from before_hit_mitigation and on_heal) -----------------------

## Damage multiplier on a direct hit on the owner: the smallest owner_damage_taken of
## the zones the owner is in (cone zones only for hits inside their half-angle).
## 1.0 outside every zone. The ice rule is real DEF (temporary_stat_sources).
func owner_damage_multiplier(hit: Dictionary) -> float:
	var taken := 1.0
	for role: StringName in zones:
		var found: SanctuaryZone = zones[role]
		if found.is_active() and found.owner_inside and found.covers_hit(float(hit.get("facing_dot", -2.0))): taken = minf(taken, float(found.rules["owner_damage_taken"]))
	return taken

## Step 1 of the incoming-hit pipeline (forward of before_hit_mitigation). Never
## cancels; returns the T1.1 "damage_multiplier", which the player applies on a copy
## of the request. A kit that cancels (parry) returns its own decision first.
func before_hit(_player: PlayerActor, hit: Dictionary) -> Dictionary:
	var request := hit.get("request") as DamageRequest
	if request == null or request.is_secondary: return {}
	var multiplier := owner_damage_multiplier(hit)
	return {"damage_multiplier": multiplier} if multiplier < 1.0 else {}

## Strongest ice defense of the zones the owner is in (0 outside).
func ice_defense() -> float:
	var best := 0.0
	for role: StringName in zones:
		var found: SanctuaryZone = zones[role]
		if found.is_active() and found.owner_inside and SanctuaryRules.has_ice(found.element): best = maxf(best, float(found.rules["ice_defense"]))
	return best

## Forward of ClassKit.temporary_stat_sources: pure read of the published ice defense,
## in the format of the Marco de Guarda source.
func temporary_stat_sources(_player: PlayerActor = null) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if ice_defense_applied > 0.0: sources.append({"source_id": stat_source_id, "label": "Santuário de gelo", "increased": {&"physical_defense": ice_defense_applied, &"magic_defense": ice_defense_applied}})
	return sources

## Publishes the ice defense when it changes and asks the player to recompose its
## breakdown (refresh_kit_stats: no heal, no reset).
func sync_stats(player: PlayerActor) -> void:
	var wanted := ice_defense() if is_instance_valid(player) and player.is_alive() else 0.0
	if is_equal_approx(wanted, ice_defense_applied): return
	ice_defense_applied = wanted
	if is_instance_valid(player): player.refresh_kit_stats()

## Largest heal multiplier of the zones the owner is in (1.0 outside).
func heal_multiplier() -> float:
	var best := 1.0
	for role: StringName in zones:
		var found: SanctuaryZone = zones[role]
		if found.is_active() and found.owner_inside: best = maxf(best, float(found.rules["heal_multiplier"]))
	return best

## Forward of ClassKit.on_heal. Measures the excess after the heal (requested -
## applied), converts it into Grace, then applies the zone heal bonus as a separate
## reported heal (source HEAL_BONUS_SOURCE, never multiplied again). Returns the
## Grace charges gained by this heal (bonus excluded).
func on_heal(player: PlayerActor, requested: float, applied: float, source: StringName) -> int:
	if not is_instance_valid(player) or not player.is_alive(): return 0
	var gained := grace.record_excess(requested, applied, player.health.max_hp)
	if source != SanctuaryRules.HEAL_BONUS_SOURCE:
		var multiplier := heal_multiplier()
		if multiplier > 1.0 and requested > 0.0 and is_finite(requested): player.heal_player(requested * (multiplier - 1.0), SanctuaryRules.HEAL_BONUS_SOURCE)
	return gained

# --- Grace -------------------------------------------------------------------------

## Kit sources (frontal mitigated hit, element alternation, light on the sealed...).
## Deduplicated per event; returns the charges added.
func gain(event: Dictionary, amount: int = 1) -> int:
	return grace.gain(event, amount, grace_family)

## Atomic with the cast commit: call from on_cast_confirmed only.
func spend_for_cast(player: PlayerActor, cast: Dictionary, minimum: int = 1, maximum: int = -1) -> int:
	return grace.spend_for_cast(cast, player.kit_time if is_instance_valid(player) else 0.0, minimum, maximum)

func begin_unlimited(seconds: float) -> bool:
	return grace.begin_unlimited(seconds)

# --- Égide -------------------------------------------------------------------------

## Halo shield through HealthState.grant_shield. One pulse (optional light damage and
## a push) when it breaks or expires. Call while resolving the cast (prototype root).
func grant_aegis(player: PlayerActor, capacity: float, duration: float = SanctuaryRules.AEGIS_DURATION, pulse_magic: float = 0.0, skill_id: StringName = &"", radius: float = SanctuaryRules.AEGIS_PULSE_RADIUS) -> bool:
	if not is_instance_valid(player) or not is_finite(duration) or duration <= 0.0 or not is_finite(radius) or radius <= 0.0: return false
	if not player.health.grant_shield(capacity): return false
	_bind_owner(player)
	aegis_capacity = capacity
	aegis_remaining = duration
	aegis_radius = radius
	aegis_prototype = null
	if pulse_magic > 0.0 and not skill_id.is_empty():
		aegis_prototype = player.kit_make_request(null, skill_id, 0.0, pulse_magic, DamageRequest.AccuracyMode.GEOMETRY, false)
		aegis_prototype.is_secondary = true
	player.resources_changed.emit()
	return true

func aegis_active() -> bool:
	return aegis_remaining > 0.0

## Forward of ClassKit.on_shield_broken.
func on_shield_broken(player: PlayerActor, _hit: Dictionary = {}, _result: Dictionary = {}, actors: Array = []) -> void:
	if aegis_active(): _release_aegis(player, SanctuaryHelpers.enemies_of(player, actors))

func _tick_aegis(player: PlayerActor, delta: float, enemies: Array) -> void:
	if not aegis_active(): return
	aegis_remaining = maxf(0.0, aegis_remaining - delta)
	if aegis_remaining > 0.0: return
	if player.health.shield_hp > 0.0 and player.health.shield_hp <= aegis_capacity + 0.001:
		player.health.clear_shield()
		player.resources_changed.emit()
	_release_aegis(player, enemies)

func _release_aegis(player: PlayerActor, enemies: Array) -> void:
	aegis_remaining = 0.0
	aegis_capacity = 0.0
	aegis_pulses += 1
	var prototype := aegis_prototype
	aegis_prototype = null
	if not is_instance_valid(player) or not player.is_alive(): return
	var tick_request := prototype.scheduled_tick() if prototype != null else null
	if tick_request != null and tick_request.cancelled: tick_request = null
	var owner_area := SanctuaryZone.owner_area(player) if player.world_motion != null else null
	for candidate: Variant in enemies:
		var enemy := candidate as CombatActor
		if not is_instance_valid(enemy) or not enemy.is_alive() or enemy == player: continue
		var direction := Vector2.ZERO
		var heading := Vector3.ZERO
		if player.world_motion != null:
			if owner_area == null or not owner_area.contains_actor(enemy, aegis_radius): continue
			heading = enemy.world_point().position - player.world_point().position
			heading.y = 0.0
		else:
			if enemy.global_position.distance_to(player.global_position) > aegis_radius + enemy.collision_radius: continue
			direction = enemy.global_position - player.global_position
		if tick_request != null:
			var hit := tick_request.copy()
			hit.target_id = enemy.get_instance_id()
			hit.context = tick_request.context.copy_context() if tick_request.context != null else null
			player.kit_emit_hit(hit, enemy)
		if not is_instance_valid(enemy) or not enemy.is_alive(): continue
		if not heading.is_zero_approx() and enemy.has_method(&"apply_world_defender_push_direction"):
			enemy.call(&"apply_world_defender_push_direction", heading.normalized(), PlayerActor.DEFENDER_PUSH_DISTANCE, player.world_motion.geometry.geometry_revision)
		elif not direction.is_zero_approx() and enemy.has_method(&"apply_defender_push"):
			enemy.call(&"apply_defender_push", direction.normalized(), PlayerActor.DEFENDER_PUSH_DISTANCE)

# --- Selo --------------------------------------------------------------------------

## Mark in ActorMarks (owner = the player) plus force_target. One seal per owner:
## sealing another enemy removes the previous mark. The force is best effort (a
## non-enemy actor is marked without it) and reported in "forced".
func seal(player: PlayerActor, enemy: CombatActor, key: StringName, duration: float = SanctuaryRules.SEAL_DURATION, value: int = 1) -> Dictionary:
	if not is_instance_valid(player) or not is_instance_valid(enemy) or not enemy.is_alive() or enemy == player: return SanctuaryRules.failure(&"invalid_target")
	if key.is_empty() or not is_finite(duration) or duration <= 0.0: return SanctuaryRules.failure(&"invalid_payload")
	_bind_owner(player)
	if marked_target_id != 0 and marked_target_id != enemy.get_instance_id(): _remove_seal_mark()
	if not enemy.marks.set_mark(key, player.get_instance_id(), value, duration): return SanctuaryRules.failure(&"mark_refused")
	marked_target_id = enemy.get_instance_id()
	seal_key = key
	var forced := player.kit_force_target(enemy, duration)
	return {"ok": true, "error_code": &"", "forced": bool(forced.get("ok", false)), "force_error": forced.get("error_code", &"")}

func is_sealed(enemy: CombatActor) -> bool:
	return is_instance_valid(enemy) and not seal_key.is_empty() and enemy.marks.has_mark(seal_key) and enemy.marks.owner_of(seal_key) == owner_id

func sealed_target() -> CombatActor:
	if marked_target_id == 0: return null
	var enemy := instance_from_id(marked_target_id) as CombatActor
	return enemy if is_sealed(enemy) else null

func add_to_seal(delta: int) -> bool:
	var enemy := sealed_target()
	return enemy != null and enemy.marks.update_value(seal_key, int(enemy.marks.value(seal_key, 0)) + delta)

func _tick_seal() -> void:
	if marked_target_id != 0 and sealed_target() == null: marked_target_id = 0

func _remove_seal_mark() -> void:
	var previous := instance_from_id(marked_target_id) as CombatActor if marked_target_id != 0 else null
	if is_instance_valid(previous) and not seal_key.is_empty() and previous.marks.owner_of(seal_key) == owner_id: previous.marks.remove(seal_key)
	marked_target_id = 0

# --- Lifecycle and snapshot ----------------------------------------------------------

## Forward of ClassKit.on_death: zones, Égide, Selo and the unlimited mode end; Grace empties.
func on_death(player: PlayerActor) -> void:
	for role: StringName in zones.keys(): end_zone(role)
	if ice_defense_applied > 0.0:
		ice_defense_applied = 0.0
		if is_instance_valid(player): player.refresh_kit_stats()
	aegis_remaining = 0.0
	aegis_capacity = 0.0
	aegis_prototype = null
	_remove_seal_mark()
	grace.reset_on_death()

## Forward of ClassKit.on_build_changed: no recharge, no reset, no heal.
func on_build_changed(_player: PlayerActor) -> void:
	grace.charges = mini(grace.charges, grace.ceiling())

## Forward of ClassKit.snapshot_compact_blocker (A5: an active zone forces the exact format).
func compact_blocker() -> String:
	var roles: Array = zones.keys()
	roles.sort()
	for role: StringName in roles:
		if (zones[role] as SanctuaryZone).is_active(): return "sanctuary_zone:%s" % role
	if aegis_active(): return "sanctuary_aegis"
	if sealed_target() != null: return "sanctuary_seal"
	return ""

func describe() -> Dictionary:
	var listed: Array[Dictionary] = []
	var roles: Array = zones.keys()
	roles.sort()
	for role: StringName in roles: listed.append((zones[role] as SanctuaryZone).describe())
	return {"grace": grace.charges, "cap": grace.cap, "unlimited": grace.is_unlimited(), "zones": listed, "aegis_remaining": aegis_remaining, "sealed_id": marked_target_id}

func _bind_owner(player: PlayerActor) -> void:
	if owner_id == 0 and is_instance_valid(player): owner_id = player.get_instance_id()
