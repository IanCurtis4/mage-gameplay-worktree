extends SceneTree
## E08 P6-A2 visual evidence (windowed, real renderer; never --headless). Boots the published forest
## map with the preview launcher (same path as the P5 world preview probe), freezes actors, then
## drives ONLY presentation: confirmed bridge events, projectile flights stepped by hand, Elementalist
## world pulses. Captures at zoom 50/100/160 with UI scale 1.2, then measures frame cost with and
## without the feedback layer.
## P7-C1 adds the `polish` mode (item scenes on flat ground swatches: sand, earth, grass) used for before/after captures.
## Usage: --script res://tools/e08_p6_vfx_probe.gd -- {output} [package_id] [captures|cost|all|polish|legacy] [scene_prefix]
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
const PreviewApp = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const ZOOMS: Array[float] = [0.5, 1.0, 1.6]
const STEP := 1.0 / 60.0

var folder := ""
var host: RunController
var view: ExpeditionGeometryView
var bridge: PresentationEventBridge
var layer: Control
var app: Node
var serial := 0
var flying: Array[Node] = []
var cleanup_nodes: Array[Node] = []
var report := {"captures": [], "notes": []}
var origin := Vector3.ZERO
var scene_filter := ""
var backdrop: Node2D
## Flat ground swatches (P7-C1): stand-ins for light earth/sand and grass so the polish scenes compare on a known colour.
const GROUNDS := {"sand": Color(0.86, 0.76, 0.52), "earth": Color(0.74, 0.60, 0.42), "grass": Color(0.36, 0.52, 0.22)}

func _initialize() -> void: _run.call_deferred()

func note(text: String) -> void:
	print("P6VFX_NOTE ", text); report["notes"].append(text)

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(folder.path_join(label + ".png"))
	print("P6VFX_CAPTURE ", label, " error=", error, " pulses=", layer.pulses.size(), " first=", layer.pulses[0] if not layer.pulses.is_empty() else {}, " vis=", layer.visible, " z=", layer.z_index, " gp=", layer.global_position)
	report["captures"].append(label)

func boot(id: String) -> bool:
	var loaded: Dictionary = MapRelease.load_package(id)
	if not loaded.get("ok", false): print("P6VFX_FAIL load ", loaded); return false
	var candidate: Dictionary = Candidate.create("patrol", loaded.package, loaded.package.source_hash)
	var created: Dictionary = Launcher.create_session(candidate.candidate, "mage")
	var window: Dictionary = Launcher.create_window(created.path)
	var preview := PreviewApp.new()
	preview.quit_on_close = false
	root.add_child(preview)
	current_scene = preview
	app = preview
	var opened: Dictionary = preview.open_window(window.path)
	var started: Dictionary = preview.start() if opened.ok else opened
	if not started.get("ok", false): print("P6VFX_FAIL start ", started); return false
	host = preview.host
	host.route_camera.position_smoothing_enabled = false
	host.control_preferences.ui_scale = 1.2
	host._apply_interface_preferences()
	host._update_hud()
	view = host.expedition_view
	bridge = host.presentation_events()
	layer = bridge.get_node("E08PilotFeedback")
	return view != null and layer != null

func freeze() -> void:
	bridge.set_process(false) # Ages are driven by hand below.
	host.player.set_process(false); host.player.set_physics_process(false)
	for enemy: CombatActor in host.enemies:
		enemy.set_process(false); enemy.set_physics_process(false)
	origin = host.player.world_point().position

## Ground point whose projection is `screen_offset` away from the player (same height).
func spot(screen_offset: Vector2) -> Vector3:
	var sum := screen_offset.y / 0.425
	var diff := screen_offset.x / 0.85
	return origin + Vector3((sum + diff) * 0.5, 0.0, (sum - diff) * 0.5)

func ev(kind: StringName, skill: StringName, at: Vector3, extra: Dictionary = {}) -> Dictionary:
	serial += 1
	var payload := {"presentation_epoch": bridge.current_epoch(), "target_id": str(serial)}
	payload.merge(extra, true)
	return {"event_id": "p6vfx_%d" % serial, "kind": kind, "stage_id": bridge.stage_id, "actor_id": "probe", "skill_id": skill, "position": at,
		"surface_id": host.player.world_point().surface_id, "duration": float(extra.get("duration", 0.4)), "essential": false, "payload": payload}

func emit(kind: StringName, skill: StringName, at: Vector3, extra: Dictionary = {}) -> void:
	if not view.point_visible(at): note("hidden anchor for %s/%s" % [kind, skill]); return
	if not bridge.emit_confirmed(ev(kind, skill, at, extra)): note("event rejected %s/%s" % [kind, skill])

func step(seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(STEP, left)
		bridge.world_advanced.emit(dt)
		for node: Node in flying:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.get("world_flight") != null and node.has_method("_advance_world_flight"): node.call("_advance_world_flight", dt)
		left -= dt
	view.sync()
	layer.queue_redraw()

func fly(script: GDScript, skill: StringName, from: Vector3, heading: Vector3, tint: Color = Color("f6dfad"), speed: float = 180.0, trace_element: StringName = &"") -> Node:
	var projectile: Node = script.new()
	var request := DamageRequest.new(); request.skill_id = skill; request.source_id = host.player.get_instance_id()
	var no_targets: Array[CombatActor] = []
	projectile.configure_directional(request, Vector2.ZERO, Vector2.RIGHT, no_targets, host.navigation, speed, 700.0, 1, tint)
	if trace_element != &"": projectile.element = trace_element
	var player_point := host.player.world_point()
	var support := ExpeditionWorldPoint.create(player_point.stage_id, player_point.surface_id, player_point.position)
	var bound: Dictionary = projectile.bind_world_flight(view.geometry, support, from - player_point.position + Vector3.UP * 18.0, heading.normalized(), {"radius": 5.0, "height": 10.0}, view.geometry.geometry_revision)
	if not bound.get("ok", false):
		note("flight bind failed for %s: %s" % [skill, bound.get("error_code", "?")]); projectile.free(); return null
	host.add_child(projectile)
	projectile.set_process(false)
	flying.append(projectile)
	return projectile

func clear_scene() -> void:
	for node: Node in flying:
		if is_instance_valid(node): node.queue_free()
	flying.clear()
	for node: Node in cleanup_nodes:
		if is_instance_valid(node): node.queue_free()
	cleanup_nodes.clear()
	layer.pulses.clear(); layer._on_stage_cleared(); layer.queue_redraw()
	view.clear_world_pulses()

func camera(zoom: float) -> void:
	host.control_preferences.camera_zoom = zoom
	host.route_camera.zoom = Vector2.ONE * zoom
	host.route_camera.force_update_scroll()
	view.sync()

## One scene: `setup` spawns presentation, then captures at each time (seconds after setup).
func scene(label: String, setup: Callable, times: Array, zooms: Array[float] = ZOOMS) -> void:
	if not scene_filter.is_empty() and not label.begins_with(scene_filter): return
	for zoom: float in zooms:
		camera(zoom)
		clear_scene()
		await process_frame
		if label.begins_with("pol_"): note("%s zoom=%s canvas_scale=%s" % [label, zoom, layer._canvas.get_global_transform_with_canvas().get_scale()])
		setup.call()
		var elapsed := 0.0
		for at: float in times:
			step(maxf(0.0, at - elapsed)); elapsed = at
			await shot("%s_z%d_t%03d" % [label, int(zoom * 100), int(at * 1000)])
		clear_scene()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	var package_id: String = args[1] if args.size() > 1 else "forest_terraces"
	var mode: String = args[2] if args.size() > 2 else "all"
	scene_filter = args[3] if args.size() > 3 else ""
	if mode == "legacy":
		await legacy_arena()
		return
	if not boot(package_id):
		print("P6VFX_FAIL boot"); quit(1); return
	await process_frame
	freeze()
	report["package"] = package_id; report["viewport"] = [root.size.x, root.size.y]; report["ui_scale"] = 1.2
	report["renderer"] = RenderingServer.get_current_rendering_method()
	var draws := {"n": 0}
	layer._canvas.draw.connect(func() -> void: draws.n += 1)
	note("layer visible_in_tree=%s parent=%s parent_visible=%s canvas_layer=%s modulate=%s self_modulate=%s clip=%s size=%s host_parent=%s" % [layer.is_visible_in_tree(), layer.get_parent(), (layer.get_parent() as CanvasItem).visible, layer.get_canvas_layer_node(), layer.modulate, layer.self_modulate, layer.clip_contents, layer.size, host.get_parent()])
	report["draws"] = draws
	note("player_global=%s host_global=%s host_xform=%s view_global=%s view_parent=%s bridge_pos=%s layer_xform=%s camera=%s cam_global=%s" % [host.player.global_position, host.global_position, host.get_global_transform(), view.global_position, view.get_parent(), bridge.position, layer.get_global_transform(), host.route_camera.position, host.route_camera.get_screen_center_position()])
	report["layer_z"] = layer.z_index; report["view_effects_z"] = view._effects.z_index
	report["enemies"] = host.enemies.size()
	if mode in ["captures", "all"]: await captures()
	if mode in ["cost", "all"]: await cost()
	if mode == "polish": await polish()
	var file := FileAccess.open(folder.path_join("p6_vfx_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true)); file.close()
	print("P6VFX_DONE")
	await app.suspend()
	quit()

func captures() -> void:
	var mage: GDScript = MageProjectile
	# Free screen area (HUD panels sit left/bottom/right): x -100..360, y -150..150 around the player.
	# Mage fireball: flight (muzzle + orb) then signature impact (fire_burst flipbook).
	await scene("fireball", func() -> void:
		emit(&"projectile_launch", &"fireball", spot(Vector2(-40, -10)), {"direction": Vector3(1, 0, 0.1)})
		fly(mage, &"fireball", spot(Vector2(-40, -10)), Vector3(1, 0, 0.1), Color("ffac68"), 200.0)
		fly(mage, &"fireball", spot(Vector2(-40, 30)), Vector3(1, 0, 0.1), Color("ffac68"), 160.0)
		emit(&"impact", &"fireball", spot(Vector2(230, 40)), {"direction_2d": Vector2.RIGHT}),
		[0.1, 0.22, 0.4, 0.7])
	# Ice and lightning projectiles with other spear/bolt shapes, then their impacts.
	await scene("elements_projectiles", func() -> void:
		fly(mage, &"ice_spear", spot(Vector2(-40, -90)), Vector3(1, 0, 0), Color("a9e9ff"), 240.0)
		fly(mage, &"fire_spear", spot(Vector2(-40, -55)), Vector3(1, 0, 0), Color("ffac68"), 240.0)
		fly(mage, &"lightning", spot(Vector2(-40, -20)), Vector3(1, 0, 0), Color("ebe29b"), 240.0)
		fly(mage, &"electric_discharge", spot(Vector2(-40, 15)), Vector3(1, 0, 0), Color("ebe29b"), 240.0)
		fly(PlayerProjectile, &"double_shot", spot(Vector2(-40, 50)), Vector3(1, 0, 0), Color("f6dfad"), 240.0)
		fly(SentinelProjectile, &"sentinel_piercing_shot", spot(Vector2(-40, 85)), Vector3(1, 0, 0), Color("f6dfad"), 240.0)
		fly(SentinelProjectile, &"sentinel_explosive_shot", spot(Vector2(-40, 120)), Vector3(1, 0, 0), Color("f6dfad"), 240.0)
		emit(&"impact", &"ice_spear", spot(Vector2(300, -90))); emit(&"impact", &"lightning", spot(Vector2(300, -20))); emit(&"impact", &"double_shot", spot(Vector2(300, 50))); emit(&"impact", &"sentinel_explosive_shot", spot(Vector2(300, 120))),
		[0.15, 0.3, 0.45])
	# Geometer traces (static), archer arrow and the enemy arrow.
	await scene("traces_arrows", func() -> void:
		fly(GeometerTraceProjectile, &"geometer_trace", spot(Vector2(0, -40)), Vector3(1, 0, 0), Color.WHITE, 0.01, &"fire")
		fly(GeometerTraceProjectile, &"geometer_trace", spot(Vector2(0, 0)), Vector3(1, 0, 0), Color.WHITE, 0.01, &"ice")
		fly(GeometerTraceProjectile, &"geometer_trace", spot(Vector2(0, 40)), Vector3(1, 0, 0), Color.WHITE, 0.01, &"lightning")
		var arrow := ArrowProjectile.new()
		var request := DamageRequest.new(); request.skill_id = &"enemy_arrow"
		var target: CombatActor = host.enemies[0] if not host.enemies.is_empty() else host.player
		arrow.configure(request, target, Vector2.ZERO, host.navigation)
		var player_point := host.player.world_point()
		var support := ExpeditionWorldPoint.create(player_point.stage_id, player_point.surface_id, player_point.position)
		var bound: Dictionary = arrow.bind_world_flight(view.geometry, support, spot(Vector2(150, 40)) - player_point.position + Vector3.UP * 18.0, Vector3(1, 0, 0), {"radius": 4.0, "height": 8.0}, view.geometry.geometry_revision)
		if bound.get("ok", false): host.add_child(arrow); arrow.set_process(false); flying.append(arrow)
		else: note("arrow bind failed " + str(bound.get("error_code", "?"))); arrow.free()
		fly(PlayerProjectile, &"double_shot", spot(Vector2(150, -20)), Vector3(1, 0, 0), Color("f6dfad"), 0.01),
		[0.1], [1.0, 1.6])
	# Elementalist pulses and the lightning arc in the spatial world.
	await scene("elementalist_world", func() -> void:
		view.show_elementalist_pulse(&"elementalist_flame_burst", spot(Vector2(-40, 70)), 70.0, &"fire")
		view.show_elementalist_pulse(&"elementalist_glacial_ring", spot(Vector2(150, 70)), 70.0, &"ice")
		view.show_elementalist_pulse(&"elementalist_lightning_arc", spot(Vector2(330, 70)), 30.0, &"lightning")
		view.show_elementalist_arc_link(spot(Vector2(0, -60)), spot(Vector2(190, -20)))
		view.show_elementalist_arc_link(spot(Vector2(190, -20)), spot(Vector2(330, 40))),
		[0.12, 0.3])
	# Tri-nova: three staggered element pulses at the same anchor + effect_start signature.
	await scene("tri_nova", func() -> void:
		emit(&"effect_start", &"elementalist_tri_nova", spot(Vector2(120, 40)), {"actor_variant": "elementalist"})
		view.show_elementalist_pulse(&"elementalist_tri_nova", spot(Vector2(120, 40)), 90.0, &"fire"),
		[0.2, 0.45], [1.0])
	# Swordsman slash (flipbook), counterstroke and blood rift.
	await scene("melee", func() -> void:
		emit(&"melee_swing", &"slash", spot(Vector2(-30, 40)), {"direction": Vector3(1, 0, 0), "actor_variant": "swordsman"})
		emit(&"melee_swing", &"defender_counterstroke", spot(Vector2(100, 40)), {"direction": Vector3(0, 0, 1), "actor_variant": "defender"})
		emit(&"melee_swing", &"berserker_blood_rift", spot(Vector2(230, 40)), {"direction": Vector3(1, 0, -1).normalized(), "actor_variant": "berserker"})
		emit(&"melee_swing", &"brutal_strike", spot(Vector2(350, 40)), {"direction": Vector3(-1, 0, 0), "actor_variant": "swordsman"}),
		[0.12, 0.25, 0.45])
	# Areas: real ArrowRain warning (danger indicator) beneath the arrow-rain feedback, plus area_start rings.
	await scene("areas_arrow_rain", func() -> void:
		var request := DamageRequest.new(); request.skill_id = &"arrow_rain"; request.source_id = host.player.get_instance_id()
		var rain := ArrowRain.new(); rain.configure(Vector2.ZERO, request, host.enemies)
		var player_point := host.player.world_point()
		var anchor := ExpeditionWorldPoint.create(player_point.stage_id, player_point.surface_id, player_point.position)
		var bound: Dictionary = rain.bind_world_area(view.geometry, anchor, host.player.world_motion.profile(), view.geometry.geometry_revision)
		if bound.get("ok", false): host.add_child(rain); rain.set_process(false); cleanup_nodes.append(rain)
		else: note("arrow rain bind failed " + str(bound.get("error_code", "?"))); rain.free()
		emit(&"area_start", &"fire_wall", spot(Vector2(-10, -60)), {"radius": 40.0})
		emit(&"area_start", &"ice_wall", spot(Vector2(-10, 120)), {"radius": 40.0})
		emit(&"area_start", &"foliage_shelter", spot(Vector2(350, -40)), {"radius": 50.0})
		emit(&"area_start", &"berserker_blood_rift", spot(Vector2(350, 120)), {"radius": 45.0}),
		[0.15, 0.3, 0.5])
	# Traps.
	await scene("traps", func() -> void:
		emit(&"trap_trigger", &"explosive_trap", spot(Vector2(-20, 40)), {"radius": 40.0, "effect_radius": 60.0, "reason": "trigger", "actor_variant": "archer"})
		emit(&"trap_trigger", &"hunter_freezing_trap", spot(Vector2(150, 40)), {"radius": 40.0, "effect_radius": 60.0, "reason": "trigger"})
		emit(&"trap_trigger", &"hunter_thorn_trap", spot(Vector2(320, 40)), {"radius": 40.0, "effect_radius": 55.0, "reason": "trigger"}),
		[0.1, 0.25, 0.5])
	# Charge / summon / shout / buff / heal / movement / teleport.
	await scene("support", func() -> void:
		emit(&"charge_start", &"enemy_charge", spot(Vector2(-60, -60)), {"direction": Vector3(1, 0, 0), "actor_variant": "forest_ancient_warden", "duration": 0.9})
		emit(&"summon", &"enemy_summon", spot(Vector2(130, -70)), {"actor_variant": "forest_ancient_warden"})
		emit(&"effect_start", &"swordsman_terrifying_shout", spot(Vector2(300, -50)), {"actor_variant": "swordsman"})
		emit(&"effect_start", &"shield_wall", spot(Vector2(-10, 70)))
		emit(&"heal", &"blood_thirst", spot(Vector2(110, 80)), {"amount": 12.0})
		emit(&"movement", &"berserker_wound_leap", spot(Vector2(230, 90)), {"direction": Vector3(1, 0, 0), "phase": "start"})
		emit(&"teleport", &"teleport", spot(Vector2(330, 120))),
		[0.15, 0.35, 0.6])
	# Impact flood: many targets of the same skills at once, then a second wave.
	await scene("impact_flood", func() -> void:
		for i: int in 28:
			var skill: StringName = [&"fireball", &"ice_spear", &"burn_tick", &"slash"][i % 4]
			var offset := Vector2(-90.0 + 34.0 * float(i % 14), -40.0 + 80.0 * float(i / 14))
			emit(&"impact", skill, spot(offset), {"target_id": "t%d" % i}),
		[0.1, 0.25])
	report["flood_pulses_after_wave"] = layer.pulses.size()

func set_backdrop(ground: String) -> void:
	if is_instance_valid(backdrop): backdrop.queue_free(); backdrop = null
	if not GROUNDS.has(ground): return
	var color: Color = GROUNDS[ground]
	var node := Node2D.new()
	node.z_as_relative = false; node.z_index = 4060 # Above actors and the ambient layer, below the feedback layer (4080).
	node.draw.connect(func() -> void:
		var center: Vector2 = host.to_local(host.route_camera.get_screen_center_position())
		node.draw_rect(Rect2(center - Vector2(2000, 2000), Vector2(4000, 4000)), color))
	host.add_child(node)
	backdrop = node

## One polish scene on each ground swatch ("real" keeps the map ground).
func pscene(label: String, setup: Callable, times: Array, grounds: Array = ["sand", "earth", "grass"], zooms: Array[float] = ZOOMS) -> void:
	for ground: String in grounds:
		set_backdrop(ground)
		await scene("%s_%s" % [label, ground], setup, times, zooms)
	set_backdrop("")

## P7-C1: the five P6 weak points (shockwave, thorns, physical sparks, charge chevrons, flipbook speed).
func polish() -> void:
	await pscene("pol_shockwave", func() -> void:
		emit(&"effect_start", &"terrifying_shout", spot(Vector2(-60, 0)), {"actor_variant": "swordsman"})
		emit(&"effect_start", &"defender_reprisal_wave", spot(Vector2(90, 0)), {"actor_variant": "defender"})
		emit(&"effect_start", &"geometer_collapse", spot(Vector2(240, 0)), {"actor_variant": "geometer"}),
		[0.3, 0.6, 0.9])
	await pscene("pol_thorns", func() -> void:
		emit(&"trap_trigger", &"hunter_thorn_trap", spot(Vector2(10, 0)), {"radius": 40.0, "effect_radius": 55.0, "reason": "trigger"})
		emit(&"trap_trigger", &"hunter_thorn_trap", spot(Vector2(190, 0)), {"radius": 40.0, "effect_radius": 55.0, "reason": "trigger"}),
		[0.2, 0.5, 0.9])
	await pscene("pol_sparks", func() -> void:
		emit(&"impact", &"double_shot", spot(Vector2(-60, 0)))
		emit(&"impact", &"slash", spot(Vector2(40, 0)))
		emit(&"impact", &"enemy_claw", spot(Vector2(140, 0)))
		emit(&"impact", &"hunter_exploit", spot(Vector2(240, 0))),
		[0.06, 0.15, 0.28])
	await pscene("pol_charge", func() -> void:
		emit(&"charge_start", &"enemy_charge", spot(Vector2(-90, -20)), {"direction": Vector3(1, 0, 0), "actor_variant": "forest_ancient_warden", "duration": 0.9})
		emit(&"charge_start", &"enemy_charge", spot(Vector2(60, 20)), {"direction": Vector3(0, 0, 1), "duration": 0.9})
		emit(&"charge_start", &"enemy_charge", spot(Vector2(210, -20)), {"direction": Vector3(1, 0, 1).normalized(), "actor_variant": "forest_ancient_warden", "duration": 0.9}),
		[0.15, 0.4, 0.7])
	await pscene("pol_fps", func() -> void:
		emit(&"melee_swing", &"slash", spot(Vector2(-40, 0)), {"direction": Vector3(1, 0, 0), "actor_variant": "swordsman"})
		emit(&"impact", &"fireball", spot(Vector2(100, 0)), {"direction_2d": Vector2.RIGHT})
		emit(&"effect_start", &"terrifying_shout", spot(Vector2(240, 0)), {"actor_variant": "swordsman"}),
		[0.15, 0.4, 0.7, 1.0, 1.3], ["real"], [1.0])

func cost() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	camera(1.0)
	clear_scene()
	var templates: Array = [
		[&"impact", &"fireball", {}], [&"melee_swing", &"slash", {"direction": Vector3(1, 0, 0)}], [&"impact", &"ice_spear", {}], [&"area_start", &"fire_wall", {"radius": 50.0}],
		[&"effect_start", &"shield_wall", {}], [&"impact", &"lightning", {}], [&"melee_swing", &"berserker_blood_rift", {"direction": Vector3(0, 0, 1)}], [&"trap_trigger", &"explosive_trap", {"radius": 50.0, "effect_radius": 70.0}],
		[&"heal", &"blood_thirst", {}], [&"projectile_launch", &"lightning", {"direction": Vector3(1, 0, 0)}], [&"movement", &"dash", {"direction": Vector3(1, 0, 0)}], [&"impact", &"burn_tick", {}]]
	# Two load levels: "typical" ~1 event every 10 frames (about 8 per second); "flood" 3 events every 6 frames (about 40 per second).
	for load_name: String in ["typical", "flood"]:
		var period := 10 if load_name == "typical" else 6
		var burst := 1 if load_name == "typical" else 3
		for window: int in 3:
			for condition: String in ["with_layer", "without_layer"]:
				if condition == "without_layer": layer.dispose()
				else: layer.configure(bridge, host)
				var values: Array[float] = []
				var last := Time.get_ticks_usec(); var started := last
				var frame := 0
				var emitted := 0
				while Time.get_ticks_usec() - started < 4_000_000:
					if frame % period == 0:
						for k: int in burst:
							var index := (frame / period * burst + k) % templates.size()
							var template: Array = templates[index]
							var at := spot(Vector2(-60.0 + 40.0 * float((frame / period * burst + k) % 10), -40.0 + 50.0 * float(k)))
							if view.point_visible(at): bridge.emit_confirmed(ev(template[0], template[1], at, template[2])); emitted += 1
					bridge.world_advanced.emit(STEP)
					view.sync()
					await process_frame
					var now := Time.get_ticks_usec(); values.append((now - last) / 1000.0); last = now
					frame += 1
				values.sort()
				var total := 0.0
				for v: float in values: total += v
				var row := {"frames": values.size(), "events": emitted, "median_ms": values[values.size() / 2], "mean_ms": total / values.size(), "p95_ms": values[int((values.size() - 1) * 0.95)], "p99_ms": values[int((values.size() - 1) * 0.99)], "max_ms": values[-1], "live_pulses_end": layer.pulses.size()}
				report["cost_%s_%s_%d" % [load_name, condition, window]] = row
				print("P6VFX_COST ", load_name, " ", condition, " ", window, " ", JSON.stringify(row))
	layer.configure(bridge, host)

## Flat (legacy 2D) arena: the same layer must draw there too. Captures at the same zoom levels.
func legacy_arena() -> void:
	RunController.selected_class_id = &"mage"
	RunController.pending_training_mode = true
	var main := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(main)
	host = main
	await process_frame
	await process_frame
	bridge = host.presentation_events()
	if bridge == null or bridge.stage_id.is_empty(): print("P6VFX_FAIL legacy stage"); quit(1); return
	layer = bridge.get_node("E08PilotFeedback")
	bridge.set_process(false)
	host.player.set_process(false); host.player.set_physics_process(false)
	for enemy: CombatActor in host.enemies: enemy.set_process(false); enemy.set_physics_process(false)
	var center: Vector2 = host.player.global_position
	report["legacy_layer_z"] = layer._canvas.z_index
	for zoom: float in ZOOMS:
		host.route_camera.zoom = Vector2.ONE * zoom
		layer.pulses.clear(); layer._on_stage_cleared()
		var base := center + Vector2(60, -40)
		var legacy_events := [
			[&"impact", &"fireball", Vector2(0, 0), {"direction_2d": Vector2.RIGHT}], [&"impact", &"ice_spear", Vector2(70, 0), {}], [&"melee_swing", &"slash", Vector2(0, 70), {"direction_2d": Vector2.RIGHT, "actor_variant": "swordsman"}],
			[&"melee_swing", &"berserker_blood_rift", Vector2(90, 70), {"direction_2d": Vector2.DOWN, "actor_variant": "berserker"}], [&"area_start", &"fire_wall", Vector2(180, 20), {"radius": 40.0}],
			[&"trap_trigger", &"explosive_trap", Vector2(0, 140), {"radius": 40.0, "effect_radius": 60.0, "actor_variant": "archer"}], [&"effect_start", &"shield_wall", Vector2(110, 140), {}], [&"heal", &"blood_thirst", Vector2(190, 120), {}]]
		for entry: Array in legacy_events:
			serial += 1
			var payload := {"presentation_epoch": bridge.current_epoch(), "position_unavailable": true, "legacy_position_2d": base + entry[2], "target_id": str(serial)}
			payload.merge(entry[3], true)
			bridge.emit_confirmed({"event_id": "p6leg_%d" % serial, "kind": entry[0], "stage_id": bridge.stage_id, "actor_id": "probe", "skill_id": entry[1], "position": Vector3.ZERO, "surface_id": "", "duration": 0.4, "essential": false, "payload": payload})
		for at: float in [0.12, 0.3]:
			bridge.world_advanced.emit(at - (0.0 if at < 0.2 else 0.12))
			await shot("legacy_z%d_t%03d" % [int(zoom * 100), int(at * 1000)])
	var file := FileAccess.open(folder.path_join("p6_vfx_legacy_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true)); file.close()
	print("P6VFX_DONE legacy")
	quit()
