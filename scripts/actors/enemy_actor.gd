class_name EnemyActor
extends CombatActor

const Patrol = preload("res://scripts/core/expedition/patrol/enemy_patrol.gd")
var patrol: Dictionary = {}

func bind_patrol(definition: Dictionary) -> Dictionary:
	if world_motion == null or world_motion.geometry == null or not world_motion.is_current_world() or _world_home == null or _mob_definition == null or not is_alive() or not _uses_engagement(): return {"ok":false,"code":"patrol_binding_invalid"}
	var checked := Patrol.validate_route(definition,Patrol.authored_world(world_motion.geometry),_world_home,world_motion.profile(),_mob_definition.leash_radius)
	if not checked.ok: return checked
	patrol = Patrol.create(definition)
	world_motion.cancel()
	return {"ok":true}

func patrol_valid() -> bool:
	if not Patrol.valid(patrol): return false
	if patrol.is_empty(): return true
	if world_motion == null or _world_home == null or _mob_definition == null: return false
	if world_motion.geometry == null and is_alive(): return false
	for waypoint: Dictionary in patrol.definition.waypoints:
		var p := ExpeditionPopulationPlanner.point(waypoint.point)
		if p.stage_id != _world_home.stage_id or p.position.distance_to(_world_home.position) > _mob_definition.leash_radius: return false
		if world_motion.geometry != null:
			var support := world_motion.geometry.support_at(p.surface_id,Vector2(p.position.x,p.position.z),world_motion.geometry.geometry_revision)
			if not support.ok or support.data.point.position.distance_to(p.position) > WorldGeometry.EPS: return false
	return true

var threat := ThreatService.new()
var threat_actors: Dictionary[String, PlayerActor] = {}
var threat_taunt_sequence := 0

var effect_ledger := EffectProcLedger.new("enemy")
## E10a C1.6: temporary combat-target override {"target_id", "owner_id", "remaining",
## "reason"}; empty while the combat target is the player (the default).
var target_override: Dictionary = {}
## E10a C1.6: registered commit deflections, source -> {"owner_id", "chance", "radius",
## "remaining"}. At the commit of an attack one may move the hit to a minion in reach.
var commit_deflections: Dictionary = {}
## E10a C1.6: state of this enemy's own deterministic RNG (deflection and disorientation).
var combat_rng_state := 0
## E10a C1.6: key of DamageRequest.effect_snapshot on enemy-to-enemy damage authored by a
## player: {"actor_id" (the enemy that attacked), "owner_id" (the author)}.
const RELAY_KEY := "enemy_relay"
## Reach of the movement disorientation step (canvas/world units).
const DISORIENT_STEP := 140.0

signal attack_requested(request: DamageRequest, target: CombatActor, ranged: bool)
## Actual navigation-applied walking only. Direct placement/push is not walking.
signal ground_walked(from: Vector2, to: Vector2)
signal mob_skill_requested(request: DamageRequest, target: CombatActor, projectile_speed: float, maximum_range: float)
signal companion_requested(master: EnemyActor)
## E08 P6 presentation-only facts (skill_committed | charge_start), emitted after the
## canonical change; observed only by PresentationEvents. Gameplay never connects to it.
signal presentation_fact(kind: StringName, skill_id: StringName, direction: Vector2, duration: float)
var is_summoned := false
var summoner_id := 0
var summon_used := false
var spawn_home := Vector2.ZERO
var engagement_mode: StringName = &"idle"
var _last_seen_position := Vector2.INF
var _sight_lost_time := 0.0
var occurrence: MobOccurrence
var _mob_definition: MobDefinition
var _mob_cast: Dictionary = {}
var _mob_cooldowns: Dictionary = {}
var _mob_sp := 0.0

const MOVEMENT_EPSILON := 0.01

var archetype: StringName
var navigation: ArenaNavigation
var player: PlayerActor
var attack_cooldown := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0
var _navigation_revision := 0
var player_target_acquired := false
var hunter_last_seen_position := Vector2.INF
var taunt_remaining: float:
	get: return threat.forced_remaining
var scenario_damage_multiplier := 1.0
var _world_home: ExpeditionWorldPoint
var _world_last_seen: ExpeditionWorldPoint
var _world_geometry_revision := 0
var _world_cast_revision := 0
var world_ai_failure: StringName = &""

func bind_world_geometry(world: WorldGeometry, point: ExpeditionWorldPoint, traversal: Dictionary, occupant_id: String) -> Dictionary:
	var result := super.bind_world_geometry(world,point,traversal,occupant_id)
	if result["ok"]:
		_world_home = world_point()
		_world_last_seen = null
		_world_geometry_revision = world.geometry_revision
		set_process(true)
	return result

func _player_acquirable() -> bool:
	if not is_instance_valid(player) or not player.is_alive(): return false
	if world_motion != null: return player.can_be_acquired_by_world(self)
	return player.can_be_acquired_by(global_position)

func _combat_target_reachable(maximum_range: float) -> bool:
	if not is_instance_valid(player) or not player.is_alive(): return false
	if world_motion != null: return world_can_reach(player,maximum_range)
	return global_position.distance_to(player.global_position) <= maximum_range and navigation != null and navigation.is_segment_clear(global_position,player.global_position,0.0)

# Background search when the gameplay host enables it (checkpoint36): the mob
# keeps its current route and asks again only after the answer arrives.
func _world_plan(destination: ExpeditionWorldPoint) -> void:
	if world_motion.plan_pending(): return
	if not patrol.is_empty() and engagement_mode == &"returning":
		if _repath_time > 0.0: return
		_repath_time = 1.0
		var planned := world_motion.plan_async(destination,world_motion.geometry.geometry_revision,0,_patrol_return_planned)
		if not planned.get("pending",false): _patrol_return_planned(planned)
		return
	if _repath_time > 0.0 and world_motion.has_route(): return
	_repath_time = 0.45
	if destination == null: world_motion.cancel(); return
	var chased := world_motion.plan_async(destination,world_motion.geometry.geometry_revision,0,_world_chase_planned)
	if not chased.get("pending",false): _world_chase_planned(chased)

func _world_chase_planned(planned: Dictionary) -> void:
	if not planned.get("ok",false): world_motion.cancel()

func _patrol_return_planned(planned: Dictionary) -> void:
	if not planned.ok:
		world_motion.cancel(); world_ai_failure = planned.get("error_code",&"patrol_blocked")
		patrol.state = "blocked"; patrol.error = String(world_ai_failure)
	else: patrol.state = "interrupted"; patrol.error = ""; world_ai_failure = &""

func _world_walk(delta: float) -> void:
	if is_rooted() or is_stunned() or not world_motion.has_route(): return
	var before := world_point()
	var movement := world_motion.advance(stat_breakdown.value(&"move_speed")*movement_speed_multiplier()*_charge_factor()*delta)
	if not movement["ok"]: world_motion.cancel(); _repath_time = 0.0; return
	var after := world_point()
	if before.position != after.position:
		# World consumers subscribe to this signal, never the projected legacy walk signal.
		world_ground_walked.emit(before,after)

signal world_ground_walked(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint)

func _advance_world_ai(delta: float) -> void:
	if not world_motion.is_current_world() or player.world_motion == null or not player.world_motion.is_current_world() or player.world_motion.geometry != world_motion.geometry:
		player_target_acquired = false
		world_motion.cancel()
		_cancel_mob_cast_presentation()
		return
	if _world_geometry_revision != world_motion.geometry.geometry_revision:
		_world_geometry_revision = world_motion.geometry.geometry_revision
		world_motion.cancel()
		_repath_time = 0.0
	_repath_time -= delta
	if is_stunned(): _cancel_mob_cast_presentation(); world_motion.cancel(); return
	if is_feared():
		Patrol.interrupt(self)
		_cancel_mob_cast_presentation()
		if is_rooted(): world_motion.cancel(); return
		_world_fear_path()
		_world_walk(delta)
		return
	# E10a C1.6/C1.7: disorientation, then a combat-target override, replace the player AI.
	if is_disoriented():
		Patrol.interrupt(self)
		_cancel_mob_cast_presentation()
		_advance_disorient_world(delta)
		return
	if _override_target() != null:
		Patrol.interrupt(self)
		_advance_override_world(delta)
		return
	if _uses_engagement():
		_refresh_engagement(delta)
		if engagement_mode != &"idle": Patrol.interrupt(self)
		if engagement_mode == &"returning":
			_world_plan(_world_home)
			_world_walk(delta)
			if world_point().position.distance_to(_world_home.position) <= WorldGeometry.EPS and world_point().surface_id == _world_home.surface_id:
				_arrive_home()
				_world_last_seen = null
				_sight_lost_time = 0.0
				world_motion.cancel()
			return
		_request_companion_once()
		if engagement_mode == &"idle" and not patrol.is_empty():
			Patrol.tick(self,delta)
			return
	if not _mob_cast.is_empty(): _advance_mob_cast(delta); return
	if not _refresh_player_acquisition():
		if _world_last_seen != null and (not _uses_engagement() or engagement_mode == &"engaged"):
			_world_plan(_world_last_seen)
			_world_walk(delta)
		else: world_motion.cancel()
		return
	var attack_range := _declared_attack_range() if archetype == &"archer" else 55.0
	var distance := world_distance_to(player)
	if _combat_target_reachable(attack_range) and (taunt_remaining > 0.0 or archetype != &"archer" or distance >= minf(150.0,attack_range*0.5)):
		world_motion.cancel()
		_try_attack(archetype == &"archer")
		return
	if archetype == &"archer" and taunt_remaining <= 0.0:
		var standoff := minf(280.0,attack_range*0.75) if _mob_definition != null and not _mob_definition.skill_ids.is_empty() else 280.0
		_world_plan(_world_standoff_goal(standoff))
	elif archetype == &"flanker" and taunt_remaining <= 0.0 and distance > FLANK_CLOSE:
		var flank := _world_flank_goal()
		_world_plan(flank if flank != null else player.world_point())
	else:
		if archetype == &"charger": _try_charge(distance)
		_world_plan(player.world_point())
	_world_walk(delta)
	if _uses_engagement() and engagement_mode == &"engaged" and not _inside_leash(): _begin_return()

## F10 Q2 (contracts/f10_phase_rules.md): against kiting. A charger closes the
## distance with a short burst of speed; a flanker comes in from one side of the
## target (a stable side per occurrence) and only then goes straight at it.
const CHARGE_MIN := 160.0
const CHARGE_MAX := 480.0
const CHARGE_SECONDS := 0.6
const CHARGE_COOLDOWN := 4.0
const CHARGE_SPEED := 2.6
const FLANK_DISTANCE := 120.0
const FLANK_CLOSE := 150.0
var _charge_remaining := 0.0
var _charge_cooldown := 0.0

func _try_charge(distance: float) -> void:
	if _charge_remaining > 0.0 or _charge_cooldown > 0.0 or distance < CHARGE_MIN or distance > CHARGE_MAX or is_rooted() or is_stunned(): return
	_charge_remaining = CHARGE_SECONDS; _charge_cooldown = CHARGE_COOLDOWN
	presentation_fact.emit(&"charge_start", &"enemy_charge", Vector2.ZERO, CHARGE_SECONDS)

func _charge_factor() -> float:
	return CHARGE_SPEED if _charge_remaining > 0.0 else 1.0

func _world_flank_goal() -> ExpeditionWorldPoint:
	var target_point := player.world_point()
	var offset := world_point().position-target_point.position
	var toward := -Vector2(offset.x,offset.z).normalized()
	if toward.is_zero_approx(): return null
	var side := 1.0 if String(threat.enemy_id).hash() % 2 == 0 else -1.0
	var horizontal := Vector2(target_point.position.x,target_point.position.z)+toward.orthogonal()*side*FLANK_DISTANCE
	var support := world_motion.geometry.support_at(target_point.surface_id,horizontal,world_motion.geometry.geometry_revision)
	if not support["ok"]: return null
	var data: Dictionary = support["data"]["point"]
	return ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])

func _world_standoff_goal(distance: float) -> ExpeditionWorldPoint:
	var target_point := player.world_point()
	var offset := world_point().position-target_point.position
	var away := Vector2(offset.x,offset.z).normalized()
	if away.is_zero_approx(): away = Vector2.RIGHT
	var horizontal := Vector2(target_point.position.x,target_point.position.z)+away*distance
	var support := world_motion.geometry.support_at(target_point.surface_id,horizontal,world_motion.geometry.geometry_revision)
	if not support["ok"]: return null
	var data: Dictionary = support["data"]["point"]
	return ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])

func _world_fear_path() -> void:
	if _repath_time > 0.0 and world_motion.has_route(): return
	world_motion.cancel()
	_repath_time = 0.18
	var origin := world_point()
	var offset := origin.position-player.world_point().position
	var away := Vector2(offset.x,offset.z).normalized()
	if away.is_zero_approx(): away = Vector2.RIGHT
	var best_gain := 8.0
	var destination: ExpeditionWorldPoint
	for angle: float in [0.0,-PI*0.25,PI*0.25,-PI*0.5,PI*0.5]:
		for distance: float in [180.0,100.0]:
			var horizontal := Vector2(origin.position.x,origin.position.z)+away.rotated(angle)*distance
			var support := world_motion.geometry.support_at(origin.surface_id,horizontal,world_motion.geometry.geometry_revision)
			if not support["ok"]: continue
			var data: Dictionary = support["data"]["point"]
			var candidate := ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
			var route := world_motion.geometry.path(origin,candidate,world_motion.profile(),world_motion.geometry.geometry_revision)
			var gain := candidate.position.distance_to(player.world_point().position)-origin.position.distance_to(player.world_point().position)
			if route["ok"] and gain > best_gain: best_gain = gain; destination = candidate
	if destination != null: world_motion.plan(destination,world_motion.geometry.geometry_revision)


func apply_world_defender_push_direction(heading: Vector3, distance: float, revision: int) -> Dictionary:
	if world_motion == null or not is_alive() or hard_controls.boss: return {"ok":false,"error_code":&"push_immune"}
	var plan := world_motion.plan_ground_line(heading,distance,revision)
	if not plan["ok"]: return plan
	var result := world_motion.advance(float(plan["data"]["cost"]))
	world_motion.cancel()
	if result["ok"]: _repath_time = 0.0
	return result

func apply_world_defender_push(destination: ExpeditionWorldPoint, distance: float, revision: int) -> Dictionary:
	if world_motion == null or not is_alive() or hard_controls.boss: return {"ok":false,"error_code":&"push_immune"}
	var result := world_motion.displace(destination,distance,revision)
	if result["ok"]: _repath_time = 0.0
	return result

func apply_defender_push(direction: Vector2, distance: float) -> float:
	if world_motion != null: return 0.0
	if not is_alive() or hard_controls.boss or navigation == null or direction.is_zero_approx() or distance <= 0.0:
		return 0.0
	var before := global_position
	global_position = navigation.move_until_blocked(before, before + direction.normalized() * distance)
	_path.clear()
	_path_index = 0
	_repath_time = 0.0
	return before.distance_to(global_position)

func configure(enemy_type: StringName, nav: ArenaNavigation, target_player: PlayerActor) -> void:
	var catalog := BuildContentLoader.pilot().mob_catalog()
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "demo_%d" % get_instance_id()
	spawn.mob_base_id = &"demo_archer" if enemy_type == &"archer" else &"demo_chaser"
	spawn.category_id = &"normal"
	spawn.origin_id = &"demo_arena"
	var result := configure_occurrence(spawn, catalog, nav, target_player)
	assert(result["ok"], str(result))

func configure_occurrence(spawn: MobOccurrence, catalog: MobCatalog, nav: ArenaNavigation, target_player: PlayerActor) -> Dictionary:
	if spawn == null or nav == null or target_player == null:
		return BuildEffectCatalog.failure(&"invalid_occurrence")
	var checked := spawn.validate(catalog)
	if not checked["ok"]:
		return checked
	var derived := catalog.stats_for_occurrence(spawn)
	if not derived["ok"]:
		return derived
	var definition: MobDefinition = checked["definition"]
	occurrence = spawn.copy_occurrence()
	_mob_definition = definition.duplicate(true) as MobDefinition
	archetype = definition.archetype
	navigation = nav
	_navigation_revision = nav.revision
	player = target_player
	threat = ThreatService.new()
	threat_actors.clear()
	threat_taunt_sequence = 0
	threat.enemy_id = spawn.occurrence_id
	target_override = {}
	commit_deflections = {}
	combat_rng_state = hash(spawn.occurrence_id)
	register_threat_actor("player", "player", "local_party", target_player)
	hunter_last_seen_position = Vector2.INF
	spawn_home = global_position
	engagement_mode = &"idle"
	_last_seen_position = Vector2.INF
	_sight_lost_time = 0.0
	player_target_acquired = false
	_cancel_mob_cast_presentation()
	_mob_cooldowns.clear()
	_mob_sp = derived["breakdown"].value(&"max_sp")
	setup(definition.display_name, definition.tint, derived["breakdown"], definition.collision_radius)
	set_animation_kind(definition.animation_kind)
	# Cosmetic projection is derived anew, never inherited by a reconfigured NPC.
	sync_npc_equipment_visual()
	# Species presentation comes from the immutable catalog by mob_base_id; the
	# fresh CharacterAnimation above already discarded the previous species.
	if PilotVisual.has_species_presentation(occurrence.mob_base_id):
		if not PilotVisual.install_forest_atlas(self):
			push_warning("Forest presentation fallback could not be installed: "+String(occurrence.mob_base_id))
	hard_controls.boss = occurrence.category_id == &"boss"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_refresh_player_acquisition()
	return {"ok": true}

func sync_npc_equipment_visual() -> void:
	if character_animation==null:return
	character_animation.set_equipment_visual({})
	# A catalog species body that already contains its weapon gets no projection.
	if PilotVisual.has_embedded_weapon_body(self):return
	if character_animation.actor_kind==&"archer" and character_animation.render_descriptor().version==2:
		# The verified static NPC body already contains its bow. Other valid V2
		# Archer units retain the dynamic projection; invalid V2 stays fully V1.
		if character_animation.atlas.resource_path in ["res://assets/art/e08_characters/directional/archer/npc_body.png","res://assets/art/animations/directional/archer/npc_body.png"]:return
		character_animation.set_equipment_visual({"main_hand":&"bow"})

func _process(delta: float) -> void:
	if world_motion != null and (not is_finite(delta) or delta <= 0.0): return
	if is_inside_tree() and get_tree().paused:
		return
	_advance_threat(delta)
	_advance_target_override(delta)
	var was_feared := is_feared()
	super._process(delta)
	if not is_alive() or player == null or not player.is_alive():
		return
	if navigation != null and _navigation_revision != navigation.revision:
		_navigation_revision = navigation.revision
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_charge_remaining = maxf(0.0, _charge_remaining - delta); _charge_cooldown = maxf(0.0, _charge_cooldown - delta)
	for skill: StringName in _mob_cooldowns:
		_mob_cooldowns[skill] = maxf(0.0, float(_mob_cooldowns[skill]) - delta)
	if taunt_remaining > 0.0: queue_redraw()
	_recover_out_of_combat(delta)
	# E10a A8 (T4): a combat hold keeps the enemy still, without attacks or casts, on both paths.
	if has_combat_hold():
		_cancel_mob_cast_presentation()
		_path.clear()
		_path_index = 0
		if world_motion != null: world_motion.cancel()
		return
	if world_motion != null:
		_advance_world_ai(delta)
		return
	if was_feared and not is_feared():
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	if _uses_engagement():
		_refresh_engagement(delta)
	if is_stunned():
		_cancel_mob_cast_presentation()
		_path.clear()
		_path_index = 0
		return
	if is_feared():
		_cancel_mob_cast_presentation()
		if is_rooted():
			_path.clear()
			_path_index = 0
			return
		_repath_time -= delta
		_update_fear_path()
		_move_along_path(delta)
		return
	# E10a C1.6/C1.7: disorientation, then a combat-target override, replace the player AI.
	if is_disoriented():
		_cancel_mob_cast_presentation()
		_advance_disorient_flat(delta)
		return
	if _override_target() != null:
		_advance_override_flat(delta)
		return
	if _uses_engagement():
		if engagement_mode == &"returning":
			_process_return(delta)
			return
		_request_companion_once()
	if not _mob_cast.is_empty():
		_advance_mob_cast(delta)
		return
	if not _refresh_player_acquisition():
		if _uses_engagement() and engagement_mode == &"engaged" and _last_seen_position.is_finite():
			_repath_time -= delta
			_update_path(_last_seen_position)
			_move_along_path(delta)
			return
		if not _uses_engagement() and player.is_hunter() and hunter_last_seen_position.is_finite():
			_repath_time -= delta
			_update_path(hunter_last_seen_position)
			_move_along_path(delta)
			return
		_path.clear()
		_path_index = 0
		return
	_repath_time -= delta
	var distance := global_position.distance_to(player.global_position)
	if taunt_remaining > 0.0:
		var attack_range := _declared_attack_range() if archetype == &"archer" else 55.0
		if distance <= attack_range:
			_path.clear()
			_try_attack(archetype == &"archer")
		else:
			_update_path(player.global_position)
		_move_along_path(delta)
		return
	if archetype == &"archer":
		if distance <= _declared_attack_range() and distance >= minf(150.0, _declared_attack_range() * 0.5):
			_path.clear()
			_try_attack(true)
		else:
			var standoff := 280.0
			if _mob_definition != null and not _mob_definition.skill_ids.is_empty():
				standoff = minf(standoff, _declared_attack_range() * 0.75)
			var desired := player.global_position + player.global_position.direction_to(global_position) * standoff
			_update_path(desired)
	else:
		if distance <= 55.0:
			_path.clear()
			_try_attack(false)
		else:
			_update_path(player.global_position)
	_move_along_path(delta)

func _try_attack(ranged: bool) -> void:
	if world_motion != null and not _combat_target_reachable(_declared_attack_range() if ranged else 55.0): return
	if _uses_engagement() and (not _refresh_engagement(0.0) or engagement_mode != &"engaged"):
		return
	if is_stunned() or is_feared() or is_disoriented() or attack_cooldown > 0.0 or not player_target_acquired or (taunt_remaining <= 0.0 and not _player_acquirable()):
		return
	if _mob_definition != null and not _mob_definition.skill_ids.is_empty():
		_try_declared_skill()
		return
	if not effect_ledger.can_create_root() or (ranged and is_inside_tree() and not EffectProcLedger.projectile_slots_available(get_tree(), 1)):
		return
	_request_companion_once()
	if not is_alive(): return
	attack_cooldown = (1.70 if ranged else 1.30) * stat_breakdown.value(&"attacks_per_second") / attacks_per_second()
	var request := _basic_attack_request(player, ranged)
	# E10a C1.6: a registered deflection may move this committed hit to a minion in reach.
	var victim: CombatActor = player
	var deflected := _deflect_commit(request)
	if deflected != null: victim = deflected
	presentation_fact.emit(&"skill_committed", request.skill_id, Vector2.ZERO, 0.0) # Identifies the basic below.
	presentation_action.emit(&"basic_attack", global_position.direction_to(victim.global_position), 0.18)
	attack_requested.emit(request, victim, ranged)

## Basic claw/arrow request of this enemy against `target` (accuracy sources applied, C1.7).
func _basic_attack_request(target: CombatActor, ranged: bool) -> DamageRequest:
	var request := DamageRequest.new()
	request.context = effect_ledger.new_root(get_instance_id(), false, "", false, _causal_plan())
	request.source_id = get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = &"enemy_arrow" if ranged else &"enemy_claw"
	var attack_id := &"precision_attack" if ranged else &"melee_attack"
	request.physical_damage = stat_breakdown.value(attack_id) * 0.45
	request.damage_dealt_multiplier = outgoing_damage_multiplier() * scenario_damage_multiplier
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	request.hit_rating = outgoing_hit_rating(stat_breakdown.value(&"hit_rating"))
	request.crit_chance = 0.0
	request.can_crit = false
	return request

func apply_fear(base_duration: float) -> float:
	var applied_duration := super.apply_fear(base_duration)
	if applied_duration > 0.0:
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	return applied_duration

func apply_taunt(duration: float, source_actor: PlayerActor = null) -> bool:
	if not is_alive() or not is_finite(duration) or duration <= 0.0:
		return false
	var actor := source_actor if source_actor != null else player
	var source := threat_id_for(actor)
	if source.is_empty() or not is_instance_valid(actor) or not actor.is_alive(): return false
	# Existing taunt bypasses concealment, while the same geometry still vetoes
	# solid occlusion. Refresh eligibility before the ledger chooses its target.
	threat.eligibility(source, true, _threat_actor_visible(actor, true))
	threat_taunt_sequence += 1
	var applied := threat.observe("taunt_%d" % threat_taunt_sequence, &"taunt", source, 0.0, 1, duration)
	if not applied["ok"]: return false
	_select_threat_target()
	_path.clear()
	_path_index = 0
	_repath_time = 0.0
	queue_redraw()
	return true

func clear_statuses() -> void:
	_cancel_mob_cast_presentation()
	target_override = {}
	commit_deflections = {}
	threat.forced_id = ""
	threat.forced_remaining = 0.0
	threat._choose()
	super.clear_statuses()

func _draw() -> void:
	super._draw()
	if taunt_remaining > 0.0:
		draw_arc(Vector2(0, -18), collision_radius + 21.0, 0.0, TAU, 32, Color("efb453"), 2.5, true)

func _update_fear_path() -> void:
	if _repath_time > 0.0:
		return
	_path.clear()
	_path_index = 0
	_repath_time = 0.18
	var away := player.global_position.direction_to(global_position)
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var initial_distance := global_position.distance_to(player.global_position)
	var best_gain := 8.0
	for angle: float in [0.0, -PI * 0.25, PI * 0.25, -PI * 0.5, PI * 0.5]:
		var direction := away.rotated(angle)
		for distance: float in [180.0, 100.0]:
			var candidate_path := navigation.get_path(global_position, global_position + direction * distance)
			if candidate_path.is_empty() or candidate_path[0].distance_to(player.global_position) < initial_distance - 1.0:
				continue
			var gain := candidate_path[-1].distance_to(player.global_position) - initial_distance
			if gain > best_gain:
				best_gain = gain
				_path = candidate_path

func _refresh_player_acquisition() -> bool:
	if _uses_engagement():
		return _refresh_engagement(0.0)
	if world_motion != null:
		player_target_acquired = (taunt_remaining > 0.0 or _player_acquirable()) and _combat_target_reachable(1.0e20)
		if player_target_acquired: _world_last_seen = player.world_point()
		return player_target_acquired
	var was_acquired := player_target_acquired
	player_target_acquired = player != null and is_instance_valid(player) and player.is_alive() and (taunt_remaining > 0.0 or _player_acquirable())
	if player != null and is_instance_valid(player) and player.is_hunter():
		if player_target_acquired:
			hunter_last_seen_position = player.global_position
		elif was_acquired:
			_path.clear()
			_path_index = 0
			_repath_time = 0.0
	return player_target_acquired

func _update_path(destination: Vector2) -> void:
	if _repath_time > 0.0:
		return
	_path = navigation.get_path(global_position, destination)
	_path_index = 0
	_repath_time = 0.45

func _move_along_path(delta: float) -> void:
	if is_rooted() or is_stunned():
		return
	var remaining_distance := stat_breakdown.value(&"move_speed") * movement_speed_multiplier() * delta
	while remaining_distance > 0.0 and _path_index < _path.size():
		var point := _path[_path_index]
		var distance := global_position.distance_to(point)
		if distance < MOVEMENT_EPSILON:
			_path_index += 1
			continue
		var direction := global_position.direction_to(point)
		var travel := minf(distance, remaining_distance)
		var desired := global_position + direction * travel
		var before := global_position
		var moved_to := navigation.move_until_blocked(before, desired)
		var actual_travel := before.distance_to(moved_to)
		global_position = moved_to
		if _uses_engagement() and engagement_mode == &"engaged" and not _inside_leash():
			_begin_return()
		if actual_travel <= 0.0:
			break
		ground_walked.emit(before, moved_to)
		if not is_alive():
			return
		if actual_travel + MOVEMENT_EPSILON < travel:
			_path.clear()
			break
		# Consume the planned budget after a successful segment. Vector2 rounding can
		# otherwise leave a positive subpixel remainder that never makes progress.
		remaining_distance = maxf(0.0, remaining_distance - travel)
		if travel >= distance - MOVEMENT_EPSILON:
			_path_index += 1

func _causal_plan() -> Dictionary:
	var controller := get_parent() as RunController
	if controller == null:
		return {} # Legacy isolated fixtures only.
	var targets: Array[int] = [get_instance_id(), player.get_instance_id()]
	for actor: CombatActor in controller.enemies:
		if is_instance_valid(actor) and actor.is_alive() and actor.get_instance_id() not in targets:
			targets.append(actor.get_instance_id())
	var families := BuildEffectCatalog.INTRINSIC_FAMILIES.duplicate()
	families.append_array(BuildEffectCatalog.INTRINSIC_COMPONENTS)
	for skill: StringName in _mob_definition.skill_ids:
		if skill not in families: families.append(skill)
	return {"families": families, "targets": targets, "carriers": []}

func _try_declared_skill() -> bool:
	if _mob_definition == null or not _mob_cast.is_empty() or not effect_ledger.can_create_root():
		return false
	for skill: StringName in _mob_definition.skill_ids:
		if float(_mob_cooldowns.get(skill, 0.0)) > 0.0:
			continue
		var captured := MobSkillAdapters.capture(skill, int(_mob_definition.skill_ranks[skill]), stat_breakdown, get_instance_id(), player.get_instance_id())
		var rank: SkillRankDefinition = captured["rank_definition"]
		if _mob_sp < rank.sp_cost or not _combat_target_reachable(rank.range):
			continue
		captured["remaining"] = captured["cast_time"]
		_mob_cast = captured
		if float(captured["cast_time"]) > 0.0: presentation_action.emit(&"cast", global_position.direction_to(player.global_position), float(captured["cast_time"]))
		_world_cast_revision = world_motion.geometry.geometry_revision if world_motion != null else 0
		_path.clear()
		if float(captured["remaining"]) <= 0.0:
			_advance_mob_cast(0.0)
		return true
	return false

## E12 C2: read-only view of the mob cast clock (_mob_cast), only with cast_time > 0.
## The category follows the same source as the flank rules' category_of without
## importing that system: occurrence.category_id when known, boss controls, else normal.
func cast_progress() -> Dictionary:
	if _mob_cast.is_empty(): return {"active": false}
	var total := float(_mob_cast.get("cast_time", 0.0))
	if not is_finite(total) or total <= 0.0: return {"active": false}
	var request := _mob_cast.get("request") as DamageRequest
	var skill: StringName = request.skill_id if request != null else &""
	var definition := ClassCatalog.skill_definition(skill) if not skill.is_empty() else null
	var label := definition.display_name if definition != null and not definition.display_name.is_empty() else "Conjuração"
	var remaining := float(_mob_cast.get("remaining", total))
	return {"active": true, "skill_id": skill, "label": label, "total": total, "remaining": clampf(remaining if is_finite(remaining) else total, 0.0, total), "kind": &"cast", "category": _cast_category()}

func _cast_category() -> StringName:
	if occurrence != null and occurrence.category_id in MobCatalog.CATEGORIES: return occurrence.category_id
	if hard_controls != null and hard_controls.boss: return &"boss"
	return &"normal"

func _advance_mob_cast(delta: float) -> void:
	if _mob_cast.is_empty(): return
	_mob_cast["remaining"] = maxf(0.0, float(_mob_cast["remaining"]) - delta)
	if float(_mob_cast["remaining"]) > 0.0: return
	if _uses_engagement() and (not _refresh_engagement(0.0) or engagement_mode != &"engaged"):
		_cancel_mob_cast_presentation()
		return
	var captured := _mob_cast
	_mob_cast = {}
	if world_motion != null and _world_cast_revision != world_motion.geometry.geometry_revision:
		presentation_action.emit(&"cast_cancel", Vector2.ZERO, 0.0)
		return
	var rank: SkillRankDefinition = captured["rank_definition"]
	if not is_alive() or player == null or not player.is_alive() or is_stunned() or is_feared() or is_disoriented() or not _combat_target_reachable(rank.range) or _mob_sp < rank.sp_cost or not effect_ledger.can_create_root():
		presentation_action.emit(&"cast_cancel", Vector2.ZERO, 0.0)
		return
	if is_inside_tree() and not EffectProcLedger.projectile_slots_available(get_tree(), 1):
		presentation_action.emit(&"cast_cancel", Vector2.ZERO, 0.0)
		return
	var request: DamageRequest = captured["request"]
	request.context = effect_ledger.new_root(get_instance_id(), false, "", false, _causal_plan())
	request.damage_dealt_multiplier = outgoing_damage_multiplier() * scenario_damage_multiplier
	request.hit_rating = outgoing_hit_rating(request.hit_rating)
	_mob_sp -= rank.sp_cost
	_mob_cooldowns[request.skill_id] = captured["cooldown"]
	var victim: CombatActor = player
	var deflected := _deflect_commit(request)
	if deflected != null: victim = deflected
	presentation_action.emit(&"cast_release", global_position.direction_to(victim.global_position), 0.18)
	mob_skill_requested.emit(request, victim, rank.projectile_speed, rank.range)

func _declared_attack_range() -> float:
	if _mob_definition == null or _mob_definition.skill_ids.is_empty(): return 390.0
	var result := 0.0
	for skill: StringName in _mob_definition.skill_ids:
		var rank := ClassCatalog.skill_definition(skill).rank_definition(int(_mob_definition.skill_ranks[skill]))
		result = maxf(result, rank.range)
	return result

func _uses_engagement() -> bool:
	return _mob_definition != null and _mob_definition.aggro_radius > 0.0

func _inside_leash() -> bool:
	if world_motion != null:
		return _world_home != null and world_point().position.distance_to(_world_home.position) <= _mob_definition.leash_radius and is_instance_valid(player) and player.world_motion != null and player.world_point().position.distance_to(_world_home.position) <= _mob_definition.leash_radius
	return global_position.distance_to(spawn_home) <= _mob_definition.leash_radius and player != null and is_instance_valid(player) and player.global_position.distance_to(spawn_home) <= _mob_definition.leash_radius

func _can_see_player() -> bool:
	if world_motion != null: return (taunt_remaining > 0.0 or _player_acquirable()) and _combat_target_reachable(1.0e20)
	return player != null and is_instance_valid(player) and player.is_alive() and (taunt_remaining > 0.0 or _player_acquirable()) and navigation.is_segment_clear(global_position, player.global_position, 0.0)

func _refresh_engagement(delta: float) -> bool:
	if world_motion != null: return _refresh_world_engagement(delta)
	if not is_alive() or player == null or not is_instance_valid(player) or not player.is_alive():
		player_target_acquired = false
		return false
	if engagement_mode == &"returning":
		player_target_acquired = false
		return false
	if not _inside_leash():
		if engagement_mode == &"engaged" or threat.engaged or global_position.distance_to(spawn_home) > _mob_definition.leash_radius:
			_begin_return()
		player_target_acquired = false
		return false
	var visible := _can_see_player()
	if engagement_mode == &"idle":
		if not visible or (taunt_remaining <= 0.0 and global_position.distance_to(player.global_position) > _mob_definition.aggro_radius):
			player_target_acquired = false
			return false
		engagement_mode = &"engaged"
		_clear_engagement_path()
	player_target_acquired = visible
	if visible: threat.engage(threat_id_for(player))
	if visible:
		_last_seen_position = player.global_position
		hunter_last_seen_position = _last_seen_position
		_sight_lost_time = 0.0
		_request_companion_once()
	else:
		if _sight_lost_time == 0.0:
			_clear_engagement_path()
		_sight_lost_time += maxf(0.0, delta)
		if _sight_lost_time >= _mob_definition.sight_timeout:
			_begin_return()
	return player_target_acquired

func _refresh_world_engagement(delta: float) -> bool:
	if not is_alive() or not is_instance_valid(player) or not player.is_alive() or player.world_motion == null or player.world_motion.geometry != world_motion.geometry or engagement_mode == &"returning": player_target_acquired = false; return false
	if not _inside_leash():
		if engagement_mode == &"engaged" or threat.engaged or world_point().position.distance_to(_world_home.position) > _mob_definition.leash_radius: _begin_return()
		player_target_acquired = false
		return false
	# F10 Q4: an idle mob engages only within its aggro radius (or when taunted);
	# that cheap check comes before the line of sight, which crosses the world.
	if engagement_mode == &"idle" and taunt_remaining <= 0.0 and world_distance_to(player) > _mob_definition.aggro_radius: player_target_acquired = false; return false
	var visible := _can_see_player()
	if engagement_mode == &"idle":
		if not visible: player_target_acquired = false; return false
		engagement_mode = &"engaged"
		world_motion.cancel()
		_repath_time = 0.0
	player_target_acquired = visible
	if visible: threat.engage(threat_id_for(player))
	if visible:
		_world_last_seen = player.world_point()
		_sight_lost_time = 0.0
	else:
		if _sight_lost_time == 0.0: world_motion.cancel(); _repath_time = 0.0
		_sight_lost_time += maxf(0.0,delta)
		if _sight_lost_time >= _mob_definition.sight_timeout: _begin_return()
	return player_target_acquired

## Checkpoint38: a mob standing idle while hurt recovers to full HP over this
## many seconds; F10 Q2: a returning one is immune and heals on arrival.
## Chip damage from beyond the leash therefore cannot accumulate.
const LEASH_RECOVERY_SECONDS := 4.0
func _recover_out_of_combat(delta: float) -> void:
	if not _uses_engagement() or not is_alive() or engagement_mode != &"idle" or health.hp_deficit() <= 0.0 or not is_finite(delta) or delta <= 0.0: return
	health.heal(health.max_hp * delta / LEASH_RECOVERY_SECONDS)

## F10 Q2 (decisão humana de 2/11): a mob returning to its post takes no damage
## and recovers all of its HP on arrival. A return that has no route is not
## immune, so a stuck mob can still be defeated.
func returning_immune() -> bool:
	return _uses_engagement() and is_alive() and engagement_mode == &"returning" and (world_motion == null or world_ai_failure == &"")

func apply_damage(request: DamageRequest, rng: RandomNumberGenerator) -> Dictionary:
	if request != null and returning_immune():
		var ignored := request.copy(); ignored.damage_dealt_multiplier = 0.0
		return super.apply_damage(ignored,rng)
	return super.apply_damage(request,rng)

func _arrive_home() -> void:
	engagement_mode = &"idle"
	if is_alive() and health.hp_deficit() > 0.0: health.heal(health.max_hp)

func _begin_return() -> void:
	if engagement_mode == &"returning": return
	engagement_mode = &"returning"
	threat.disengage()
	player_target_acquired = false
	_cancel_mob_cast_presentation()
	_clear_engagement_path()

func _clear_engagement_path() -> void:
	if world_motion != null: world_motion.cancel()
	_path.clear()
	_path_index = 0
	_repath_time = 0.0

func _process_return(delta: float) -> void:
	_repath_time -= delta
	_update_path(spawn_home)
	_move_along_path(delta)
	if global_position.distance_to(spawn_home) <= MOVEMENT_EPSILON:
		_arrive_home()
		_last_seen_position = Vector2.INF
		hunter_last_seen_position = Vector2.INF
		_sight_lost_time = 0.0
		_clear_engagement_path()

func _request_companion_once() -> void:
	if _mob_definition == null or not _mob_definition.summons_companion or is_summoned or summon_used or not is_alive() or is_stunned() or is_feared() or (is_inside_tree() and get_tree().paused) or (_uses_engagement() and engagement_mode != &"engaged"):
		return
	if world_motion != null and (not world_motion.is_current_world() or not is_instance_valid(player) or player.world_motion == null or not player.world_motion.is_current_world() or player.world_motion.geometry != world_motion.geometry):
		world_ai_failure = &"world_reconfigured"
		return
	if world_motion != null and (not get_parent() is RunController or not has_meta("world_companion_traversal")):
		world_ai_failure = &"spatial_spawn_required"
		return
	# Claim before callbacks: creation cannot recursively request another child.
	summon_used = true
	companion_requested.emit(self)

func _on_damage_applied(result: Dictionary) -> void:
	# E10a C1.6: damage between enemies (authored by a player) never changes threat or engagement.
	if is_relay_result(result):
		super._on_damage_applied(result)
		return
	observe_threat_damage(result)
	super._on_damage_applied(result)
	if not _uses_engagement() or not is_alive() or engagement_mode == &"returning" or float(result.get("actual_damage", 0.0)) <= 0.0 or player == null or not is_instance_valid(player) or not player.is_alive() or int(result.get("source_id", 0)) != player.get_instance_id():
		return
	if engagement_mode == &"engaged":
		# Further hits do not reveal a hidden target or renew its sight clock.
		_refresh_engagement(0.0)
		return
	if not _inside_leash(): return
	engagement_mode = &"engaged"
	if world_motion != null: _world_last_seen = player.world_point()
	_last_seen_position = player.global_position
	hunter_last_seen_position = _last_seen_position
	_sight_lost_time = 0.0
	_clear_engagement_path()
	player_target_acquired = _can_see_player()
	_request_companion_once()

func register_threat_actor(id: String, owner: String, group: String, actor: PlayerActor) -> Dictionary:
	if not is_instance_valid(actor): return {"ok": false, "error_code": &"invalid_participant"}
	if threat_actors.has(id) and threat_actors[id] != actor: return {"ok": false, "error_code": &"request_conflict"}
	for existing: String in threat_actors:
		if existing != id and threat_actors[existing] == actor: return {"ok": false, "error_code": &"request_conflict"}
	var result := threat.register(id, owner, group)
	if result["ok"]: threat_actors[id] = actor
	return result

func threat_id_for(actor: Object) -> String:
	for id: String in threat_actors:
		if is_instance_valid(threat_actors[id]) and threat_actors[id] == actor: return id
	return ""

func observe_threat_damage(result: Dictionary) -> Dictionary:
	# Damage may contain a stale/foreign numeric identity. Match registered live
	# references without asking the engine to resolve an arbitrary instance slot.
	var source := ""
	var source_id := int(result.get("source_id", 0))
	for id: String in threat_actors:
		var actor: PlayerActor = threat_actors[id]
		if is_instance_valid(actor) and actor.get_instance_id() == source_id:
			source = id
			threat.eligibility(id, actor.is_alive(), _threat_actor_visible(actor, threat.forced_id == id and threat.forced_remaining > 0.0))
			break
	if source.is_empty(): return {"ok": false, "error_code": &"invalid_participant"}
	var sequence := int(result.get("application_sequence", 0))
	if sequence <= 0: return {"ok": false, "error_code": &"invalid_payload"}
	var observed := threat.observe("damage_%d" % sequence, &"damage", source, float(result.get("actual_damage", 0.0)))
	if observed.get("already_applied", false): return observed
	if not is_alive() or engagement_mode == &"returning": threat.disengage()
	elif observed["ok"] and float(result.get("actual_damage", 0.0)) > 0.0:
		_select_threat_target()
		if not threat.current_id.is_empty() and is_instance_valid(player) and player.is_alive() and _uses_engagement() and _inside_leash() and engagement_mode == &"idle":
			engagement_mode = &"engaged"
			if world_motion != null: _world_last_seen = player.world_point()
			else: _last_seen_position = player.global_position
	return observed

func observe_threat_heal(source: String, amount: float, sequence: int, divisor: int) -> Dictionary:
	if sequence <= 0: return {"ok": false, "error_code": &"invalid_payload"}
	var observed := threat.observe("heal_%s_%d" % [source, sequence], &"heal", source, amount, divisor)
	if observed["ok"]: _select_threat_target()
	return observed

func _threat_actor_visible(actor: PlayerActor, bypass_concealment: bool = false) -> bool:
	if not is_instance_valid(actor) or not actor.is_alive(): return false
	if world_motion != null:
		return actor.world_motion != null and actor.world_motion.is_current_world() and actor.world_motion.geometry == world_motion.geometry and (bypass_concealment or actor.can_be_acquired_by_world(self)) and world_can_reach(actor, 1.0e20)
	return (bypass_concealment or actor.can_be_acquired_by(global_position)) and navigation != null and navigation.is_segment_clear(global_position, actor.global_position, 0.0)

func _advance_threat(delta: float) -> void:
	threat.advance(delta)
	for id: String in threat_actors.keys():
		var actor: PlayerActor = threat_actors[id]
		var alive := is_instance_valid(actor) and actor.is_alive()
		var forced: bool = threat.forced_id == id and threat.forced_remaining > 0.0
		# F10 Q4: in the world, sight is traced only when it can matter: engaged,
		# taunted or within the aggro radius. 62 idle mobs on a 10 km field spent
		# ~139 ms a frame tracing sight to a player kilometres away.
		var visible := false
		if world_motion == null or threat.engaged or forced or _mob_definition == null or _mob_definition.aggro_radius <= 0.0 or world_distance_to(actor) <= _mob_definition.aggro_radius:
			visible = _threat_actor_visible(actor, forced)
		threat.eligibility(id, alive, visible)
		if not is_instance_valid(actor): threat_actors.erase(id)
	if not is_alive(): threat.disengage()
	_select_threat_target()

func _select_threat_target() -> void:
	if threat_actors.has(threat.current_id):
		var target: PlayerActor = threat_actors[threat.current_id]
		if player != target:
			player = target
			_cancel_mob_cast_presentation() # Never redirect an already captured cast to another actor.
			_clear_engagement_path()

func _cancel_mob_cast_presentation() -> void:
	if not _mob_cast.is_empty(): presentation_action.emit(&"cast_cancel", Vector2.ZERO, 0.0)
	_mob_cast.clear()

# --- E10a C1.6: combat target, commit deflection, enemy-to-enemy damage ---------------

static func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code}

## Points this enemy's chase, reach and attacks at another live CombatActor (an enemy or
## a decoy) for `duration` seconds of the gameplay clock (pause-frozen). It ends earlier
## when the target dies or leaves the world, and with the statuses (death). A new
## override replaces the previous one. Errors: boss_refuses_target, invalid_target,
## incompatible_target, invalid_payload.
func set_target_override(target: CombatActor, owner_id: int, duration: float, reason: StringName) -> Dictionary:
	if hard_controls.boss: return _failure(&"boss_refuses_target")
	if not is_alive() or not is_instance_valid(target) or target == self or target == player or target.has_method(&"enemy_relay_context") or not target.is_alive() or target.is_queued_for_deletion() or not target.is_inside_tree(): return _failure(&"invalid_target")
	if (world_motion == null) != (target.world_motion == null) or (world_motion != null and target.world_motion.geometry != world_motion.geometry): return _failure(&"incompatible_target")
	if not is_finite(duration) or duration <= 0.0 or reason.is_empty() or owner_id < 0: return _failure(&"invalid_payload")
	target_override = {"target_id": target.get_instance_id(), "owner_id": owner_id, "remaining": duration, "reason": reason}
	_cancel_mob_cast_presentation() # Never redirect an already captured cast.
	_clear_engagement_path()
	return {"ok": true, "error_code": &""}

## E10a A8 (T4): combat hold. The enemy neither moves, attacks nor casts for `duration`
## seconds of the gameplay clock (the Delirium without a target). It is not a control: no
## HardControlState, no stun drawing, no "controlled" bonus. Stored as an ActorMarks mark
## (pause-frozen, in the snapshot with the enemy, cleared with death and the statuses). A
## boss refuses. Errors: boss_refuses_hold, invalid_target, invalid_payload.
const COMBAT_HOLD_MARK := &"combat_hold"

func set_combat_hold(owner_id: int, duration: float, reason: StringName) -> Dictionary:
	if hard_controls.boss: return _failure(&"boss_refuses_hold")
	if not is_alive(): return _failure(&"invalid_target")
	if owner_id < 0 or reason.is_empty() or not is_finite(duration) or duration <= 0.0: return _failure(&"invalid_payload")
	if not marks.set_mark(COMBAT_HOLD_MARK, owner_id, reason, duration): return _failure(&"invalid_payload")
	_cancel_mob_cast_presentation()
	_path.clear()
	_path_index = 0
	if world_motion != null: world_motion.cancel()
	return {"ok": true, "error_code": &""}

func clear_combat_hold() -> void:
	marks.remove(COMBAT_HOLD_MARK)

func has_combat_hold() -> bool:
	return marks.has_mark(COMBAT_HOLD_MARK)

func combat_hold_remaining() -> float:
	return marks.remaining(COMBAT_HOLD_MARK)

func clear_target_override() -> void:
	if target_override.is_empty(): return
	target_override = {}
	_clear_engagement_path()

func has_target_override() -> bool:
	return _override_target() != null

func target_override_remaining() -> float:
	return float(target_override.get("remaining", 0.0)) if _override_target() != null else 0.0

func target_override_reason() -> StringName:
	return StringName(target_override.get("reason", &"")) if _override_target() != null else &""

func target_override_owner_id() -> int:
	return int(target_override.get("owner_id", 0)) if _override_target() != null else 0

## The actor this enemy chases and attacks: the override target, else the player.
func combat_target() -> CombatActor:
	var target := _override_target()
	return target if target != null else player

func _override_target() -> CombatActor:
	if target_override.is_empty(): return null
	var target := instance_from_id(int(target_override.get("target_id", 0))) as CombatActor
	if target == null or not is_instance_valid(target) or not target.is_alive() or target.is_queued_for_deletion() or not target.is_inside_tree(): return null
	if world_motion != null and (target.world_motion == null or not target.world_motion.is_current_world() or target.world_motion.geometry != world_motion.geometry): return null
	return target

## Registers a deflection: at each commit of this enemy's attack, with `chance`, the hit
## goes to a random live non-boss enemy within `radius` (this enemy's RNG), authored by
## `owner_id`. Nothing in reach: the hit stays on its target. No new hit is created.
## A new registration under the same source replaces it. Errors: invalid_target, invalid_payload.
func register_commit_deflection(source: StringName, owner_id: int, chance: float, radius: float, duration: float) -> Dictionary:
	if not is_alive(): return _failure(&"invalid_target")
	if source.is_empty() or owner_id < 0 or not is_finite(chance) or chance < 0.0 or chance > 1.0 or not is_finite(radius) or radius <= 0.0 or not is_finite(duration) or duration <= 0.0: return _failure(&"invalid_payload")
	commit_deflections[source] = {"owner_id": owner_id, "chance": chance, "radius": radius, "remaining": duration}
	return {"ok": true, "error_code": &""}

func remove_commit_deflection(source: StringName) -> bool:
	return commit_deflections.erase(source)

func _advance_target_override(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	if not target_override.is_empty():
		target_override["remaining"] = float(target_override.get("remaining", 0.0)) - delta
		if float(target_override["remaining"]) <= 0.0 or _override_target() == null: clear_target_override()
	for key: Variant in commit_deflections.keys():
		var entry: Dictionary = commit_deflections[key]
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if float(entry["remaining"]) <= 0.0: commit_deflections.erase(key)

## Uniform roll in [0, 1) from this enemy's own RNG state (deterministic, snapshot-safe).
func _roll() -> float:
	var generator := RandomNumberGenerator.new()
	generator.state = combat_rng_state
	var value := generator.randf()
	combat_rng_state = generator.state
	return value

func _deflect_commit(request: DamageRequest) -> CombatActor:
	if commit_deflections.is_empty() or request == null: return null
	var keys: Array = commit_deflections.keys()
	keys.sort()
	for key: Variant in keys:
		var entry: Dictionary = commit_deflections[key]
		var candidates := _deflection_candidates(float(entry.get("radius", 0.0)))
		if candidates.is_empty(): continue
		if _roll() >= float(entry.get("chance", 0.0)): continue
		var chosen: CombatActor = candidates[mini(candidates.size() - 1, floori(_roll() * float(candidates.size())))]
		relay_authorship(request, chosen, int(entry.get("owner_id", 0)))
		return chosen
	return null

## Another enemy, by method. This script never names its own class (`is EnemyActor`): in
## Godot 4.7.2 that self-reference kept the catalog scripts alive at exit ("resources
## still in use", crash in the E04 Mage tests). The same rule holds for PlayerActor below.
static func _is_enemy(actor: Object) -> bool:
	return actor != null and actor.has_method(&"set_target_override")

## Live, non-boss enemies of the same host within `radius`, by instance ID.
func _deflection_candidates(radius: float) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	var controller := get_parent() as RunController
	if controller == null: return result
	for actor: CombatActor in controller.enemies:
		if not is_instance_valid(actor) or actor == self or not _is_enemy(actor) or not actor.is_alive() or actor.is_queued_for_deletion() or actor.hard_controls.boss: continue
		if world_motion != null:
			if world_distance_to(actor) > radius: continue
		elif actor.world_motion != null or global_position.distance_to(actor.global_position) > radius: continue
		result.append(actor)
	result.sort_custom(func(a: CombatActor, b: CombatActor) -> bool: return a.get_instance_id() < b.get_instance_id())
	return result

## Retargets `request` at `victim`. Against another enemy with a live player author the
## damage becomes the author's (claims, EffectProcLedger root, death callbacks, XP and
## loot) and carries RELAY_KEY so the victim's threat and engagement do not change.
func relay_authorship(request: DamageRequest, victim: CombatActor, owner_id: int) -> void:
	request.target_id = victim.get_instance_id()
	if not _is_enemy(victim) or owner_id <= 0: return
	# Duck-typed on purpose (as in the E09 seam): naming the player class here, beside the
	# typed `player` field, closes a script cycle Godot 4.7.2 does not release at exit.
	var author := instance_from_id(owner_id) as CombatActor
	if author == null or not is_instance_valid(author) or not author.is_alive() or not author.has_method(&"enemy_relay_context"): return
	var context := author.call(&"enemy_relay_context") as CombatEventContext
	if context == null: return
	request.source_id = owner_id
	request.context = context
	request.effect_snapshot[RELAY_KEY] = {"actor_id": get_instance_id(), "owner_id": owner_id}

## The enemy that physically delivers a request (relayed damage), else its source.
static func attacker_id(request: DamageRequest) -> int:
	if request == null: return 0
	var relay: Variant = request.effect_snapshot.get(RELAY_KEY)
	return int((relay as Dictionary).get("actor_id", request.source_id)) if relay is Dictionary else request.source_id

static func is_relay_result(result: Dictionary) -> bool:
	var snapshot: Variant = result.get("effect_snapshot", {})
	return snapshot is Dictionary and (snapshot as Dictionary).has(RELAY_KEY)

func _override_reach(ranged: bool) -> float:
	return _declared_attack_range() if ranged else 55.0

func _advance_override_flat(delta: float) -> void:
	var target := _override_target()
	var ranged := archetype == &"archer"
	_repath_time -= delta
	if global_position.distance_to(target.global_position) <= _override_reach(ranged) and (navigation == null or navigation.is_segment_clear(global_position, target.global_position, 0.0)):
		_path.clear()
		_path_index = 0
		_try_attack_target(target, ranged)
		return
	_update_path(target.global_position)
	_move_along_path(delta)

func _advance_override_world(delta: float) -> void:
	var target := _override_target()
	var ranged := archetype == &"archer"
	if world_can_reach(target, _override_reach(ranged)):
		world_motion.cancel()
		_try_attack_target(target, ranged)
		return
	_world_plan(target.world_point())
	_world_walk(delta)

## The archetype's own basic attack against the override target. Declared mob skills
## stay for the player (limitation registered in the API).
func _try_attack_target(target: CombatActor, ranged: bool) -> void:
	if not is_alive() or is_stunned() or is_feared() or is_disoriented() or attack_cooldown > 0.0 or not is_instance_valid(target) or not target.is_alive(): return
	if not effect_ledger.can_create_root() or (ranged and is_inside_tree() and not EffectProcLedger.projectile_slots_available(get_tree(), 1)): return
	attack_cooldown = (1.70 if ranged else 1.30) * stat_breakdown.value(&"attacks_per_second") / attacks_per_second()
	var request := _basic_attack_request(target, ranged)
	relay_authorship(request, target, int(target_override.get("owner_id", 0)))
	presentation_fact.emit(&"skill_committed", request.skill_id, Vector2.ZERO, 0.0)
	presentation_action.emit(&"basic_attack", global_position.direction_to(target.global_position), 0.18)
	attack_requested.emit(request, target, ranged)

## Wrong heading of the disorientation: rolled once (90 to 270 degrees away from the
## combat target) unless the source gave one.
func _disorient_direction(toward: Vector2) -> Vector2:
	if disorient_heading.is_zero_approx():
		var base := toward.normalized() if not toward.is_zero_approx() else Vector2.RIGHT
		disorient_heading = base.rotated(PI * (0.5 + _roll()))
	return disorient_heading

func _advance_disorient_flat(delta: float) -> void:
	_repath_time -= delta
	if is_rooted() or navigation == null:
		_path.clear()
		_path_index = 0
		return
	if _repath_time <= 0.0 or _path_index >= _path.size():
		_repath_time = 0.3
		var target := combat_target()
		var heading := _disorient_direction(global_position.direction_to(target.global_position) if is_instance_valid(target) else Vector2.ZERO)
		_path = navigation.get_path(global_position, global_position + heading * DISORIENT_STEP)
		_path_index = 0
	_move_along_path(delta)

func _advance_disorient_world(delta: float) -> void:
	if is_rooted(): world_motion.cancel(); return
	if _repath_time <= 0.0 or not world_motion.has_route():
		_repath_time = 0.3
		world_motion.cancel()
		var origin := world_point()
		var target := combat_target()
		var toward := Vector2.ZERO
		if is_instance_valid(target) and target.world_motion != null:
			var offset := target.world_point().position - origin.position
			toward = Vector2(offset.x, offset.z)
		var heading := _disorient_direction(toward)
		# Shorter steps when the full one leaves the ground (as the fear path does).
		for scale: float in [1.0, 0.5, 0.25]:
			var support := world_motion.geometry.support_at(origin.surface_id, Vector2(origin.position.x, origin.position.z) + heading * DISORIENT_STEP * scale, world_motion.geometry.geometry_revision)
			if not support["ok"]: continue
			var data: Dictionary = support["data"]["point"]
			if world_motion.plan(ExpeditionWorldPoint.create(data["stage_id"], data["surface_id"], data["position"]), world_motion.geometry.geometry_revision).get("ok", false): break
	_world_walk(delta)
