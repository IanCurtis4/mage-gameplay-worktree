extends SceneTree
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const Bridge = preload("res://scripts/presentation/presentation_event_bridge.gd")
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
var events: Array[Dictionary] = []
class Host extends Node2D:
	var player: CombatActor
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _record(event: Dictionary) -> void: events.append(event)
func _event(bridge: PresentationEventBridge, id: String = "manual", kind: StringName = &"impact") -> Dictionary:
	return {"event_id":id, "kind":kind, "stage_id":bridge.stage_id, "actor_id":"actor", "skill_id":&"fireball", "position":Vector3(2,3,4), "surface_id":"surface", "duration":0.5, "essential":false, "payload":{"presentation_epoch":bridge.current_epoch(), "nested":{"radius":17.0}}}
func _count(kind: StringName) -> int:
	return events.filter(func(event: Dictionary) -> bool: return event.kind == kind).size()
func _actor() -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit":10}))
	actor.set_animation_kind(&"mage")
	actor.set_process(false)
	return actor
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var host := Host.new(); root.add_child(host)
	var actor := _actor(); host.player = actor; host.add_child(actor)
	var bridge := Bridge.new(); host.add_child(bridge); bridge.set_process(false)
	bridge.event_confirmed.connect(_record)
	bridge.bind_controller(host); bridge.begin_stage("one")
	check(_count(&"stage_enter") == 1, "one stage context on entry")
	var baseline := events.size()
	bridge.bind_controller(host); bridge.bind_controller(host)
	actor.presentation_action.emit(&"basic_attack", Vector2.RIGHT, 0.2)
	actor.presentation_action.emit(&"cast_release", Vector2.RIGHT, 0.2)
	check(events.size() == baseline, "attack/release request never fabricates impact and binding is idempotent")
	actor.presentation_action.emit(&"cast", Vector2.RIGHT, 0.7)
	check(_count(&"cast_start") == 1 and events.back().duration == 0.7 and events.back().payload.legacy_position_2d == actor.global_position and events.back().payload.position_unavailable, "legacy cast explicitly marked, never invented as 3D")
	actor.presentation_action.emit(&"cast_cancel", Vector2.ZERO, 0.0)
	check(_count(&"cast_cancel") == 1, "cancel observed once")
	var dto := _event(bridge)
	check(bridge.emit_confirmed(dto), "valid copied DTO accepted")
	dto.payload.nested.radius = 999.0
	check(events.back().payload.nested.radius == 17.0, "nested payload isolated from producer")
	check(not bridge.emit_confirmed(dto), "duplicate rejected")
	var invalids: Array[Dictionary] = []
	for field: String in dto.keys():
		var invalid := _event(bridge); invalid.erase(field); invalids.append(invalid)
	for patch: Dictionary in [{"kind":&"attack_requested"}, {"kind":"impact"}, {"position":Vector2.ZERO}, {"position":Vector3(INF,0,0)}, {"duration":NAN}, {"duration":-0.1}, {"payload":{"presentation_epoch":bridge.current_epoch(), "owner":actor}}, {"payload":{"presentation_epoch":bridge.current_epoch(), "bad":[NAN]}}, {"stage_id":"old"}, {"event_id":""}, {"essential":1}, {"skill_id":"fireball"}]:
		var invalid := _event(bridge); invalid.merge(patch, true); invalids.append(invalid)
	baseline = events.size()
	for invalid: Dictionary in invalids: check(not bridge.emit_confirmed(invalid), "invalid DTO rejected "+str(invalid))
	check(events.size() == baseline, "invalids emitted no event")
	var request := DamageRequest.new(); request.source_id = 7; request.target_id = actor.get_instance_id(); request.skill_id = &"fixture_hit"; request.physical_damage = 20.0; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var hp := actor.health.current_hp
	var resolved := actor.health.apply(request, 0.5, 1.0)
	check(_count(&"impact") == 2 and events.back().payload.application_sequence == resolved.application_sequence and actor.health.current_hp == hp-resolved.actual_damage, "bridge observes one canonical result without applying extra damage")
	baseline = events.size()
	bridge._damage(resolved, weakref(actor), bridge.current_epoch())
	check(events.size() == baseline, "confirmed application identity cannot replay an impact")
	var health := actor.health
	check(health.damage_applied.get_connections().size() == 2, "only actor and bridge subscribe to damage")
	var stale := _event(bridge, "late")
	var old_epoch := bridge.current_epoch()
	bridge.begin_stage("one", true)
	check(not bridge.emit_confirmed(stale), "same-stage previous epoch cannot replay")
	baseline = events.size()
	bridge._action(&"cast", Vector2.RIGHT, 1.0, weakref(actor), old_epoch)
	bridge._damage(resolved, weakref(actor), old_epoch)
	check(events.size() == baseline, "queued old callbacks rejected even for same stage and same live actor")
	check(health.damage_applied.get_connections().size() == 2, "epoch replacement disconnects old subscriptions")
	bridge._damage(resolved, weakref(actor), bridge.current_epoch())
	check(events.size() == baseline, "new subscriptions baseline current damage sequence and ignore historical results")
	for index: int in Bridge.DEDUP_LIMIT+7:
		check(bridge.emit_confirmed(_event(bridge, "bounded/%d" % index)), "bounded stream event accepted")
	check(bridge._seen.size() == Bridge.DEDUP_LIMIT and not bridge._seen.has("bounded/0"), "FIFO identity retention strictly bounded and deterministic")
	var essential := _event(bridge, "danger", &"area_start"); essential.essential = true
	check(bridge.emit_confirmed(essential) and events.back().essential, "full dedup window never hides essential indicators")
	paused = true
	var before := bridge.world_time
	bridge._process(1.0)
	check(bridge.world_time == before and not bridge.emit_confirmed(_event(bridge, "paused")), "pause freezes visual clock and rejects world effects")
	check(bridge.emit_confirmed(_event(bridge, "ui", &"ui_confirm")), "UI continues while paused")
	request.physical_damage = 999999.0
	actor.health.apply(request, 0.5, 1.0)
	check(_count(&"death") == 1, "death cleanup still observed during pause")
	actor.health.reset(actor.stat_breakdown)
	bridge._process(0.5); bridge._process(0.5)
	check(_count(&"revive") == 1 and bridge.world_time == before, "revive edge once while paused, no simulation clock advance")
	paused = false; bridge._process(0.25)
	check(bridge.world_time == before+0.25, "resume advances only new visual time")
	var subscription_count := bridge._connections.size()
	for index: int in 30:
		var projectile := PlayerProjectile.new()
		projectile.configure_directional(request, Vector2.ZERO, Vector2.RIGHT, [], ArenaNavigation.new(), 10.0, 20.0)
		host.add_child(projectile); projectile.free()
	check(bridge._connections.size() == subscription_count and _count(&"projectile_launch") == 30, "projectile churn releases all auxiliary subscriptions")
	var late_actor := CombatActor.new(); host.add_child(late_actor)
	late_actor.setup("Tardio", Color.WHITE, actor.stat_breakdown)
	late_actor.set_process(false)
	var late_health := late_actor.health
	check(late_health.damage_applied.get_connections().size() == 2, "actor configured after tree entry receives one damage observer")
	late_actor.presentation_health_ready.emit(late_health)
	check(late_health.damage_applied.get_connections().size() == 2, "repeated health readiness is idempotent")
	late_actor.free()
	actor.free()
	check(health.damage_applied.get_connections().is_empty() and bridge._actors.is_empty(), "freed actor releases HealthState subscription and weak references")
	bridge.clear_stage(); bridge.clear_stage(); bridge.dispose(); bridge.dispose()
	check(bridge._connections.is_empty() and not bridge.emit_confirmed(_event(bridge)), "clear and dispose idempotent")
	host.free()
	events.clear()
	_atlas_invariants()
	await _atlas_snapshot()
	await _native_integration()
	await _p6_player_kinds()
	await _p6_traps()
	await _p6_enemy_kinds()
	print("E08 presentation %s: %d checks, failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)
func _native_integration() -> void:
	var sample: Node2D = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample); sample.set_process(false)
	var controller: RunController = sample.controller
	controller.set_process(false); controller.player.set_process(false)
	var bridge := controller.presentation_events(); bridge.set_process(false); bridge.event_confirmed.connect(_record)
	check(bridge.stage_id == "sample", "real controller binds presentation to canonical stage")
	var rng_state := controller.rng.state; var hp := controller.player.health.current_hp; var sp := controller.player.current_sp
	var snapshots := bridge.current_state(); snapshots.actors.clear()
	check(bridge.current_state().actors.size() == 3 and controller.rng.state == rng_state and controller.player.health.current_hp == hp and controller.player.current_sp == sp, "current visual state is copied and cannot change RNG/HP/SP")
	check(sample.lower.move_world_to(Fixture.point("root",Vector3(180,0,150)),sample.world.geometry_revision).ok and sample.lower.advance_world(10000).ok, "cast fixture target moves onto nearby canonical support")
	sample.view.sync()
	var cast := controller.spatial_pointer_skill(&"fire_spear", sample.view.project(sample.lower.world_point().position)+Vector2(0,-24), false)
	check(cast.ok and _count(&"cast_start") == 1 and _count(&"impact") == 0, "real prepared skill starts presentation without speculative impact: "+str(cast)+" / "+str(events))
	if controller.player.has_active_cast(): controller.player.cancel_active_cast()
	check(_count(&"cast_cancel") == 1 and events.back().skill_id == &"fire_spear", "real cancellation retains captured skill identity")
	var projectile := MageProjectile.new(); var request := DamageRequest.new(); request.skill_id = &"fireball"; request.source_id = controller.player.get_instance_id()
	projectile.configure_directional(request, Vector2.ZERO, Vector2.RIGHT, [], controller.navigation, 200.0, 300.0)
	check(projectile.bind_world_flight(sample.world, controller.player.world_point(), Vector3(0,18,0), Vector3.RIGHT, {"radius":3.0,"height":4.0}, sample.world.geometry_revision).ok, "confirmed projectile flight fixture")
	controller.add_child(projectile); projectile.set_process(false)
	check(_count(&"projectile_launch") == 1 and events.back().position == projectile.world_flight.position and events.back().payload.collider == {"radius":3.0,"height":4.0}, "launch copies canonical origin and cylinder geometry")
	var rain := ArrowRain.new(); rain.configure(Vector2.ZERO, request, [])
	var point := controller.player.world_point()
	check(rain.bind_world_area(sample.world, point, sample.profile, sample.world.geometry_revision).ok, "confirmed area fixture")
	controller.add_child(rain); rain.set_process(false)
	check(_count(&"area_start") == 1 and events.back().position == point.position and events.back().surface_id == point.surface_id and events.back().payload.radius == ArrowRain.RADIUS, "area copies exact support/radius without a geometry query")
	var field := WorldGroundField.new()
	check(field.configure(sample.world, point, Vector3.RIGHT, 30.0, sample.profile, &"fire_wall", 36.0, sample.world.geometry_revision, {"half_length":30.0,"half_width":4.0,"centers":[0.0]}).ok, "canonical wall fixture")
	var wall := FireWall.new(); wall.configure(controller.player, Vector2.RIGHT, request, [], 30.0)
	check(wall.bind_world_field(field).ok, "wall confirms its field before entering presentation")
	controller.add_child(wall); wall.set_process(false)
	check(_count(&"area_start") == 2 and events.back().payload.height == 36.0 and events.back().payload.half_length == 30.0 and events.back().payload.half_width == 4.0 and events.back().payload.centers == field._centers.map(func(center: ExpeditionWorldPoint) -> Dictionary: return center.to_data()), "wall DTO preserves canonical height, half extents and packed support geometry")
	wall.free()
	var previous_epoch := bridge.current_epoch(); events.clear()
	bridge.begin_stage("sample", true)
	check(_count(&"impact") == 0 and _count(&"projectile_launch") == 0 and _count(&"area_start") == 0 and _count(&"stage_enter") == 1 and events.back().payload.resumed and events.back().payload.current_state.areas.size() == 1 and events.back().payload.current_state.projectiles.size() == 1, "resume publishes current context without replaying flights/areas/impacts")
	check(bridge.current_epoch() != previous_epoch, "same stage resume uses fresh epoch")
	rain.free(); projectile.free()
	check(_count(&"area_end") == 1, "confirmed area removal ends its presentation")
	check(events.filter(func(event: Dictionary) -> bool: return event.kind == &"area_end").back().payload.reason == "cleanup", "P6: area freed before its last volley ends with reason cleanup")
	var destination := Fixture.point("root",Vector3(110,0,150))
	check(controller.player.use_world_teleport(destination,sample.world.geometry_revision) and _count(&"teleport") == 1 and events.back().position == destination.position, "world teleport emitted only after canonical movement succeeds")
	var teleports := _count(&"teleport")
	check(not controller.player.use_world_teleport(destination,sample.world.geometry_revision-1) and _count(&"teleport") == teleports, "refused teleport emits nothing")
	bridge.begin_stage("other")
	var baseline := events.size()
	bridge._damage({"landed":true,"skill_id":&"late_hit"}, weakref(sample.lower), bridge.current_epoch())
	check(events.size() == baseline, "old-world actors cannot emit into new stage")
	sample.free()
	await process_frame

func _atlas_invariants() -> void:
	var original := load("res://assets/art/animations/animal_companion.png") as Texture2D
	var variant := load("res://assets/art/animations/gel.png") as Texture2D
	var animation := D.legacy_animation(&"animal_companion")
	var other := D.legacy_animation(&"animal_companion")
	var clock := animation.state
	animation.observe(Vector2.ZERO, 0.1); animation.observe(Vector2(-20,-20), 0.1)
	animation.play(&"cast", Vector2(-1,-1), 0.9); animation.state.advance(0.2, Vector2.ZERO)
	animation.play(&"hurt")
	var before := [clock.facing,clock.back_view,clock.flip_h,clock.walk_distance,clock.action,clock.action_remaining,clock.action_duration,clock.hurt_remaining,clock.idle_time,clock.death_time]
	check(animation.set_body_atlas(variant), "catalog enemy variant accepted")
	check(animation.state == clock and before == [clock.facing,clock.back_view,clock.flip_h,clock.walk_distance,clock.action,clock.action_remaining,clock.action_duration,clock.hurt_remaining,clock.idle_time,clock.death_time], "body swap preserves same clock, facing, walk, action and hurt")
	check(animation.atlas == variant and other.atlas == original, "variant changes one instance without mutating shared catalog")
	var bitmap := variant.get_image()
	for index: int in 32:
		var bounds := bitmap.get_region(Rect2i(Vector2i(index%4*64,index/4*64),Vector2i(64,64))).get_used_rect()
		check(is_equal_approx(animation.destination_rect(index).position.y+float(bounds.end.y-1),0.0), "variant alpha ground contact frame %d" % index)
	var rects: Array[Rect2] = []
	for index: int in 32: rects.append(animation.destination_rect(index))
	var nonpersistent := ImageTexture.create_from_image(bitmap)
	var wrong := load("res://assets/art/vfx/spiritualist_curse_sigil.png") as Texture2D
	check(wrong.get_size() != Vector2(256,512), "negative dimension uses existing unrelated PNG")
	check(not animation.set_body_atlas(null) and not animation.set_body_atlas(nonpersistent) and not animation.set_body_atlas(wrong), "null, nonpersistent and wrong dimensions rejected")
	check(animation.state == clock and animation.atlas == variant and animation.destination_rect(26) == rects[26] and clock.action_remaining == before[5], "invalid variants leave atlas/offsets/state untouched")
	var dead := animation.death_copy()
	check(dead.atlas == variant and dead.state.dead and dead.state != clock and dead.state.facing == clock.facing, "death copy preserves variant with independent terminal state")
	for index: int in 32: check(dead.destination_rect(index) == rects[index], "death copy preserves variant contact frame %d" % index)
	clock.trigger(&"death"); clock.advance(0.2,Vector2.ZERO)
	var death_time := clock.death_time
	check(animation.set_body_atlas(original) and animation.state == clock and clock.dead and clock.death_time == death_time, "dead body swap preserves terminal clock")
	clock.revive()
	check(not clock.dead and animation.atlas == original, "revive keeps selected body")
	var player_animation := CharacterAnimation.new(); player_animation.configure(&"mage")
	var player_atlas := player_animation.atlas
	check(not player_animation.set_body_atlas(variant) and player_animation.atlas == player_atlas, "player kind explicitly refuses enemy body API even before equipment")
	animation.equipment_visual = {"main_hand":{}}
	check(not animation.set_body_atlas(variant) and animation.atlas == original, "equipped enemy body explicitly refuses override")
	animation.equipment_visual = {}; animation = D.legacy_animation(&"animal_companion")
	check(animation.atlas == original and animation.state != clock, "configure remains explicit default reset")

func _atlas_snapshot() -> void:
	RunController.selected_class_id = &"mage"
	var controller := RunController.new(); root.add_child(controller)
	controller.set_process(false); controller.player.set_process(false)
	var enemy: CombatActor = controller.enemies[0]; enemy.set_process(false)
	enemy.set_animation_kind(&"animal_companion")
	var variant := load("res://assets/art/animations/gel.png") as Texture2D
	check(enemy.character_animation.set_body_atlas(variant), "snapshot source accepts persistent enemy variant")
	enemy.character_animation.play(&"cast", Vector2(-1,-1), 0.8)
	enemy.character_animation.state.advance(0.2,Vector2.ZERO)
	var before := enemy.character_animation.destination_rect(26)
	var barrier := SnapshotTickBarrier.new(); paused = true
	check(barrier.acquire(controller).ok, "atlas snapshot uses real tick barrier")
	var registry := SnapshotRegistry.new(); var captured := registry.capture(controller,barrier)
	check(captured.ok, "variant captured through existing schema: "+str(captured.get("detail","")))
	if captured.ok:
		var restored := SnapshotRegistry.new().restore(captured.snapshot)
		check(restored.ok, "variant restores through existing resource binding: "+str(restored.get("detail","")))
		if restored.ok:
			var copy: RunController = restored.root
			var restored_enemy: CombatActor = copy.enemies[0]
			var animation := restored_enemy.character_animation
			check(animation.atlas.resource_path == variant.resource_path and animation.destination_rect(26) == before and animation.state.action == &"cast" and is_equal_approx(animation.state.action_remaining,0.6) and animation.state.back_view and animation.state.flip_h, "restored variant retains pose, clock, facing and contact without new schema")
			check(animation.death_copy().atlas.resource_path == variant.resource_path, "restored base atlas survives death copy and visual reselection")
			copy.free()
	barrier.release(); paused = false; controller.free()
	await process_frame

# ---------------------------------------------------------------------------
# E08 P6 A1: new confirmed kinds. Every event is published only after the canonical
# fact (checked by reading gameplay state inside the listener) and observation never
# changes HP/SP/cooldowns/position/time: an identical unobserved twin must match.
var _p6_probe: Callable
func _p6_record(event: Dictionary) -> void:
	events.append(event)
	if _p6_probe.is_valid(): _p6_probe.call(event)
func _p6_of(kind: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.kind == kind: found.append(event)
	return found
func _p6_swordsman(id: String) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 900, 600), [], 22.0)
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = id
	snapshot.base_class_id = &"swordsman"
	snapshot.job_level = 20 # Rank requirements of the learned passive (as in the E04 blood thirst test).
	snapshot.skill_ranks = {&"fury": 2, &"slash": 1, &"dash": 1, &"blood_thirst": 1} # Blood thirst depends on Fury R2.
	snapshot.active_slots = [&"fury", &"slash", &"dash", null, null]
	snapshot.base_level = 5
	snapshot.passive_slots = [null, null] # Learned passive operates automatically.
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build(snapshot.character_id, snapshot))
	player.position = Vector2(300, 300)
	return player
func _p6_state(player: PlayerActor) -> Array:
	return [player.current_sp, player.health.current_hp, player.health.heal_sequence, player.health.damage_sequence, player.position, player.fury_remaining, player.slash_cooldown, player.dash_cooldown, player.mage_cooldowns.duplicate(), player._dash_active, player._dash_endpoint, player.velocity, player.attack_cooldown]
func _p6_wound(player: PlayerActor) -> void:
	var request := DamageRequest.new(); request.source_id = 99; request.target_id = player.get_instance_id(); request.skill_id = &"fixture_wound"; request.physical_damage = 40.0; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	player.health.apply(request, 0.5, 1.0)
func _p6_player_kinds() -> void:
	events.clear()
	var host := Host.new(); root.add_child(host)
	var bridge := Bridge.new(); host.add_child(bridge); bridge.set_process(false)
	bridge.event_confirmed.connect(_p6_record)
	bridge.bind_controller(host); bridge.begin_stage("p6_player")
	var player := _p6_swordsman("p6-observed"); host.add_child(player); player.set_process(false)
	var twin_parent := Node2D.new(); root.add_child(twin_parent)
	var twin := _p6_swordsman("p6-observed"); twin_parent.add_child(twin); twin.set_process(false)
	check(_p6_state(player) == _p6_state(twin), "P6 twins start identical")
	var sp_before := player.current_sp
	var seen := {}
	_p6_probe = func(event: Dictionary) -> void:
		seen[event.kind] = {"sp":player.current_sp, "fury":player.fury_remaining, "fury_cooldown":player.skill_cooldown(&"fury"), "slash_cooldown":player.slash_cooldown, "dash_active":player._dash_active, "hp":player.health.current_hp}
	# Instant buff: effect_start at commit, then cast_start now carries the skill id.
	check(player.use_fury() and twin.use_fury(), "fury used by both twins")
	var effect := _p6_of(&"effect_start")
	var cast := _p6_of(&"cast_start")
	check(effect.size() == 1 and effect[0].skill_id == &"fury" and effect[0].actor_id == str(player.get_instance_id()) and not effect[0].essential and effect[0].payload.actor_variant == &"swordsman" and effect[0].payload.position_unavailable, "instant buff publishes one effect_start with identity")
	check(cast.size() == 1 and cast[0].skill_id == &"fury" and cast[0].payload.instant, "instant cast_start now carries skill_id (was empty before P6)")
	check(events.find(effect[0]) < events.find(cast[0]), "effect_start (commit) precedes the instant cast animation event")
	check(seen.has(&"effect_start") and seen[&"effect_start"].sp < sp_before and seen[&"effect_start"].fury_cooldown > 0.0, "effect_start only after SP and cooldown were committed")
	var baseline := events.size()
	check(not player.use_fury() and events.size() == baseline, "refused skill (cooldown) publishes nothing")
	# Melee swing: requested strike with direction, never a hit.
	var no_enemies: Array[CombatActor] = []
	check(player.use_slash(Vector2.RIGHT, no_enemies) and twin.use_slash(Vector2.RIGHT, no_enemies), "slash used by both twins")
	var swing := _p6_of(&"melee_swing")
	check(swing.size() == 1 and swing[0].skill_id == &"slash" and swing[0].payload.direction_2d == Vector2.RIGHT and is_equal_approx(swing[0].duration, 0.2) and _count(&"impact") == 0, "slash publishes one melee_swing and fabricates no impact")
	check(seen[&"melee_swing"].slash_cooldown > 0.0, "melee_swing after the canonical commit")
	# Movement: dash after its endpoint was committed (both twins refilled identically).
	player.recover_sp(1000.0); twin.recover_sp(1000.0)
	check(player.use_dash(Vector2.DOWN) and twin.use_dash(Vector2.DOWN), "dash used by both twins")
	var moves := _p6_of(&"movement")
	check(moves.size() == 1 and moves[0].skill_id == &"dash" and moves[0].payload.phase == "start" and moves[0].payload.direction_2d == Vector2.DOWN and not moves[0].essential, "dash publishes one movement")
	check(seen.has(&"movement") and seen[&"movement"].dash_active, "movement only after the canonical displacement started")
	# Heal: discrete heal with a source; continuous regeneration is not feedback.
	_p6_wound(player); _p6_wound(twin)
	var healed := player.heal_from_kill(); twin.heal_from_kill()
	var heals := _p6_of(&"heal")
	check(healed > 0.0 and heals.size() == 1 and heals[0].skill_id == &"blood_thirst" and is_equal_approx(heals[0].payload.amount, healed) and heals[0].payload.application_sequence == player.health.heal_sequence, "kill heal publishes one heal with amount and sequence: healed=%s passive=%s hp=%s/%s heals=%s" % [healed, player.run_state.build_snapshot.has_passive(&"blood_thirst"), player.health.current_hp, player.health.max_hp, heals])
	check(seen.has(&"heal") and seen[&"heal"].hp == player.health.current_hp, "heal only after HealthState applied it")
	player.regenerate_hp(1.0, false, false); twin.regenerate_hp(1.0, false, false)
	check(_p6_of(&"heal").size() == 1, "per-frame regeneration never publishes heal")
	baseline = events.size()
	bridge._heal(healed, player.health.heal_sequence, weakref(player), bridge.current_epoch())
	check(events.size() == baseline, "heal sequence identity cannot replay")
	_p6_probe = Callable()
	check(_p6_state(player) == _p6_state(twin), "observation never changes HP/SP/cooldowns/position/dash state: " + str(_p6_state(player)) + " vs " + str(_p6_state(twin)))
	# Frame-scoped commit hint: a stale commit never labels a later action.
	player.presentation_fact.emit(&"skill_committed", &"provoke", Vector2.ZERO, 0.0)
	await process_frame
	player.presentation_action.emit(&"cast", Vector2.RIGHT, 0.15)
	check(_p6_of(&"cast_start").back().skill_id == &"", "a commit from an earlier frame is not attached to a later cast")
	# Pause and epoch rules apply to every new kind.
	paused = true
	baseline = events.size()
	player.presentation_fact.emit(&"movement", &"dash", Vector2.RIGHT, 0.2)
	player.presentation_fact.emit(&"skill_committed", &"fury", Vector2.ZERO, 0.0)
	player.presentation_action.emit(&"slash", Vector2.RIGHT, 0.2)
	check(events.size() == baseline, "paused world rejects movement/effect_start/melee_swing")
	paused = false
	var old_epoch := bridge.current_epoch()
	bridge.begin_stage("p6_player", true)
	baseline = events.size()
	bridge._fact(&"movement", &"dash", Vector2.RIGHT, 0.2, weakref(player), old_epoch)
	bridge._fact(&"skill_committed", &"fury", Vector2.ZERO, 0.0, weakref(player), old_epoch)
	bridge._action(&"slash", Vector2.RIGHT, 0.2, weakref(player), old_epoch)
	check(events.size() == baseline, "old-epoch callbacks of new kinds are rejected")
	check(_p6_of(&"heal").size() == 1 and _p6_of(&"movement").size() == 1, "resume replays no heal or movement")
	var fact_connections := player.presentation_fact.get_connections().size()
	check(fact_connections == 1, "exactly one presentation_fact observer (the bridge)")
	host.free(); twin_parent.free()
	events.clear()
	await process_frame

func _p6_trap(owner_id: int, position: Vector2) -> PlayerTrap:
	var trap := PlayerTrap.new()
	trap.configure(owner_id, &"explosive_trap", position, 30.0, 0.0, 5.0)
	trap.set_process(false)
	return trap
func _p6_traps() -> void:
	events.clear()
	var host := Host.new(); root.add_child(host)
	var bridge := Bridge.new(); host.add_child(bridge); bridge.set_process(false)
	bridge.event_confirmed.connect(_p6_record)
	bridge.bind_controller(host); bridge.begin_stage("p6_traps")
	var victim := _actor(); victim.position = Vector2(100, 100); host.add_child(victim)
	var triggered := _p6_trap(7, Vector2(100, 100)); host.add_child(triggered)
	var expiring := _p6_trap(7, Vector2(400, 100)); host.add_child(expiring)
	var cleaned := _p6_trap(7, Vector2(400, 400)); host.add_child(cleaned)
	check(_p6_of(&"area_start").size() == 3, "three traps start their areas")
	var at_trigger := {}
	_p6_probe = func(event: Dictionary) -> void:
		if event.kind == &"trap_trigger": at_trigger["state"] = triggered.state
	check(triggered.try_trigger(victim), "trap triggers on the victim")
	_p6_probe = Callable()
	var trigger := _p6_of(&"trap_trigger")
	check(trigger.size() == 1 and trigger[0].essential and trigger[0].skill_id == &"explosive_trap" and trigger[0].payload.target_id == str(victim.get_instance_id()) and trigger[0].payload.reason == "trigger" and trigger[0].actor_id == "7", "trap_trigger published once with victim and owner")
	check(at_trigger.get("state") == PlayerTrap.State.TRIGGERED, "trap_trigger only after the canonical trigger state")
	check(expiring.expire(), "second trap expires by duration")
	check(_p6_of(&"trap_trigger").size() == 1, "expiry never publishes trap_trigger")
	await process_frame
	var ends := _p6_of(&"area_end")
	check(ends.size() == 2 and ends.any(func(event: Dictionary) -> bool: return event.payload.reason == "trigger") and ends.any(func(event: Dictionary) -> bool: return event.payload.reason == "expire"), "area_end says trigger vs expire: " + str(ends.map(func(event: Dictionary) -> Variant: return event.payload.get("reason"))))
	cleaned.free()
	check(_p6_of(&"area_end").size() == 3 and _p6_of(&"area_end").back().payload.reason == "cleanup", "direct removal ends with reason cleanup")
	check(victim.health.current_hp == victim.health.max_hp, "trap presentation applies no damage")
	host.free()
	events.clear()
	await process_frame

func _p6_enemy_kinds() -> void:
	events.clear()
	RunController.selected_class_id = &"mage"
	var controller := RunController.new(); root.add_child(controller)
	controller.set_process(false); controller.player.set_process(false)
	for unused: int in 3: await process_frame
	var bridge := controller.presentation_events()
	check(bridge != null and not bridge.stage_id.is_empty(), "legacy controller owns a presentation stage")
	if bridge == null: controller.free(); return
	bridge.set_process(false)
	bridge.event_confirmed.connect(_p6_record)
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "p6_warden"; occurrence.mob_base_id = &"forest_ancient_warden"; occurrence.category_id = &"boss"; occurrence.origin_id = &"trial_stage_1"
	var warden := EnemyActor.new()
	var configured := warden.configure_occurrence(occurrence, controller.run_state.effect_catalog().mob_catalog(), controller.navigation, controller.player)
	check(configured.get("ok", false), "warden occurrence configures: " + str(configured))
	if not configured.get("ok", false): warden.free(); controller.free(); return
	warden.global_position = controller.player.global_position + Vector2(160, 0)
	controller.add_child(warden); controller.enemies.append(warden); warden.set_process(false)
	var rng_state := controller.rng.state
	var hp := controller.player.health.current_hp
	var at_charge := {}
	_p6_probe = func(event: Dictionary) -> void:
		if event.kind == &"charge_start": at_charge["remaining"] = warden._charge_remaining
	warden._try_charge(300.0)
	_p6_probe = Callable()
	var charges := _p6_of(&"charge_start")
	check(charges.size() == 1 and charges[0].essential and charges[0].skill_id == &"enemy_charge" and charges[0].payload.actor_variant == &"forest_ancient_warden" and charges[0].payload.target_id == str(controller.player.get_instance_id()) and is_equal_approx(charges[0].duration, EnemyActor.CHARGE_SECONDS), "warden charge publishes one essential charge_start")
	check(at_charge.get("remaining") == EnemyActor.CHARGE_SECONDS and warden._charge_cooldown == EnemyActor.CHARGE_COOLDOWN, "charge_start only after the canonical charge state")
	warden._try_charge(300.0)
	check(_p6_of(&"charge_start").size() == 1, "charge on cooldown publishes nothing")
	# Enemy basic: claw is a swing, arrow is left to projectile_launch.
	warden.presentation_fact.emit(&"skill_committed", &"enemy_claw", Vector2.ZERO, 0.0)
	warden.presentation_action.emit(&"basic_attack", Vector2.LEFT, 0.18)
	warden.presentation_fact.emit(&"skill_committed", &"enemy_arrow", Vector2.ZERO, 0.0)
	warden.presentation_action.emit(&"basic_attack", Vector2.LEFT, 0.18)
	var swings := _p6_of(&"melee_swing")
	check(swings.size() == 1 and swings[0].skill_id == &"enemy_claw" and swings[0].payload.actor_variant == &"forest_ancient_warden", "claw basic is one melee_swing; arrow basic publishes none")
	check(controller.rng.state == rng_state and controller.player.health.current_hp == hp, "enemy presentation never consumes RNG or changes HP")
	# Summon: companion entering after the master's canonical spawn.
	var companion := controller._spawn_route_enemy({"species":&"test_animal_companion", "category":MobTierRules.lower_category(&"boss"), "position":warden.global_position + Vector2(0, 60)}, 1, true, warden.get_instance_id())
	var summons := _p6_of(&"summon")
	check(companion != null and summons.size() == 1 and summons[0].essential and summons[0].actor_id == str(warden.get_instance_id()) and summons[0].payload.companion_id == str(companion.get_instance_id()) and summons[0].payload.actor_variant == &"forest_ancient_warden" and summons[0].skill_id == &"enemy_summon", "summoned companion publishes one essential summon: " + str(summons))
	bridge.begin_stage(bridge.stage_id, true)
	check(_p6_of(&"summon").size() == 1 and _p6_of(&"charge_start").size() == 1, "resume replays no summon or charge")
	controller.free()
	events.clear()
	await process_frame
