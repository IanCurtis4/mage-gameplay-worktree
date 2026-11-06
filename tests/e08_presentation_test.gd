extends SceneTree
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
	await _native_integration()
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
