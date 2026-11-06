extends SceneTree
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const GeometryFixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const PreviewApp = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
class MixHost extends Node2D:
	var snapshot_passive := false
var folder := ""
func _initialize() -> void: _run.call_deferred()
func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label + ".png")
	var error := root.get_texture().get_image().save_png(path)
	print("E08_CAPTURE ", path, " error=", error)
func _run() -> void:
	root.size = Vector2i(1920,1080) if "wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	folder = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "geometry":
		await geometry_sample()
		return
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "lair":
		await lair_sample()
		return
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "mix":
		await mix_sample()
		return
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "training":
		await training_sample()
		return
	var f := F.make("e08_pilot_baseline")
	var menu := CharacterMenu.new()
	menu.set_profile_facade(f["facade"])
	root.add_child(menu)
	current_scene = menu
	var panel := PhaseSelectionPanel.new()
	menu.add_child(panel)
	panel.configure(menu, f["a"])
	panel.seed_input.text = "42"
	var index := -1
	for k: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(k) == "Floresta do Santuário": index = k
	if index < 0: push_error("forest missing"); quit(1); return
	panel.phase_choice.select(index)
	panel.phase_choice.item_selected.emit(index)
	var entered: Dictionary = await panel.start()
	if not entered.get("ok", false): push_error(str(entered)); quit(1); return
	var host := entered["root"] as RunController
	paused = true
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host.route_camera.position_smoothing_enabled = false
	var manifest := {"seed_input":panel.seed_input.text, "phase":"forest_sanctuary", "stage":host.campaign_runtime.state.current_stage_id, "manifest_sha256":JSON.stringify(host.campaign_runtime.state.manifest_data, "", true).sha256_text(), "player_position":str(host.player.global_position), "enemy_count":host.enemies.size(), "viewport":[root.size.x,root.size.y], "ui_scale":1.2, "zooms":[0.5,1.0,1.6], "tree_paused":true, "host_disabled":true, "renderer":RenderingServer.get_current_rendering_method(), "engine":Engine.get_version_info(), "camera_start":str(host.route_camera.position)}
	host.control_preferences.ui_scale = 1.2
	host._apply_interface_preferences()
	host._update_hud()
	for zoom: float in [0.5, 1.0, 1.6]:
		host.route_camera.zoom = Vector2.ONE * zoom
		host.route_camera.force_update_scroll()
		await shot("forest_entry_%d" % int(zoom * 100))
	var occurrences := {}
	for enemy: EnemyActor in host.enemies:
		if enemy.occurrence == null or enemy._mob_definition == null: continue
		var species := String(enemy._mob_definition.id)
		if occurrences.has(species): continue
		host.route_camera.position = enemy.global_position - host.player.global_position
		host.route_camera.zoom = Vector2.ONE
		host.route_camera.force_update_scroll()
		occurrences[species] = {"position":str(enemy.global_position), "occurrence":enemy.occurrence.occurrence_id, "camera_offset":str(host.route_camera.position)}
		await shot("forest_" + species)
	manifest["occurrences"] = occurrences
	var file := FileAccess.open(folder.path_join("forest_inputs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", true))
	file.close()
	quit()

func training_sample() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "e08-pilot-training"
	snapshot.base_class_id = &"mage"
	snapshot.base_level = 30; snapshot.job_level = 40
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena); current_scene = arena
	paused = true; arena.set_process(false); arena.player.set_process(false)
	arena.player.global_position = Vector2(850,450)
	arena.training_boss.set_process(false); arena.training_boss.global_position = Vector2(1000,450)
	arena.route_camera.position_smoothing_enabled = false
	arena.control_preferences.ui_scale = 1.2; arena._apply_interface_preferences(); arena._update_hud()
	arena.route_camera.force_update_scroll()
	await shot("training_hud_120")
	var file := FileAccess.open(folder.path_join("training_inputs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode":"training", "viewport":[root.size.x,root.size.y], "zoom":str(arena.route_camera.zoom), "ui_scale":1.2, "player_position":str(arena.player.global_position), "boss_position":str(arena.training_boss.global_position), "tree_paused":true}, "  ", true)); file.close()
	quit()

func mix_sample() -> void:
	var host := MixHost.new(); root.add_child(host)
	var bridge := PresentationEventBridge.new(); host.add_child(bridge); bridge.bind_controller(host)
	var service := PresentationAudioService.new(); bridge.add_child(service)
	service.configure(bridge, "user://e08_pilot_mix/audio.cfg")
	for channel: StringName in [&"general", &"effects", &"interface", &"ambience"]:
		service.set_volume(channel, 1.0); service.set_muted(channel, false)
	bridge.begin_stage("mix")
	var bus := AudioServer.get_bus_index(service._buses[&"effects"])
	var capture := AudioEffectCapture.new(); capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	for i: int in 24:
		bridge.emit_confirmed({"event_id":"mix/%d" % i, "kind":&"impact", "stage_id":"mix", "actor_id":"fixture", "skill_id":&"fireball", "position":Vector3.ZERO, "surface_id":"", "duration":0.0, "essential":false, "payload":{"presentation_epoch":bridge.current_epoch(), "position_unavailable":true}})
	await create_timer(0.6).timeout
	var available := capture.get_frames_available()
	var samples := capture.get_buffer(available)
	var peak := 0.0
	var clipped := 0
	for frame: Vector2 in samples:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		if absf(frame.x) > 1.0 or absf(frame.y) > 1.0: clipped += 1
	var record := {"voices":24, "event":"world.impact", "volume":1.0, "captured_frames":samples.size(), "peak":peak, "frames_above_full_scale":clipped, "audio_driver":AudioServer.get_driver_name(), "diagnostics":service.diagnostics()}
	var file := FileAccess.open(folder.path_join("audio_mix.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  ", true)); file.close()
	print("E08_MIX ", JSON.stringify(record))
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus)-1)
	service.dispose(); host.queue_free(); await process_frame
	quit(0 if samples.size() > 0 else 1)

func lair_sample() -> void:
	var loaded := MapRelease.load_package("forest_lair")
	if not loaded.ok: push_error(str(loaded)); quit(1); return
	var candidate := Candidate.create("patrol", loaded.package, loaded.package.source_hash)
	var created := Launcher.create_session(candidate.candidate, "mage")
	var window := Launcher.create_window(created.path)
	var app := PreviewApp.new()
	app.quit_on_close = false
	root.add_child(app)
	current_scene = app
	var opened := app.open_window(window.path)
	var started := app.start() if opened.ok else opened
	if not started.get("ok", false): push_error(str(started)); quit(1); return
	var host := app.host
	paused = true
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host.route_camera.position_smoothing_enabled = false
	host.control_preferences.ui_scale = 1.2
	host._apply_interface_preferences()
	host._update_hud()
	var found := false
	for enemy: EnemyActor in host.enemies:
		if enemy._mob_definition == null or enemy._mob_definition.id != &"forest_ancient_warden": continue
		host.route_camera.position = enemy.global_position - host.player.global_position
		host.route_camera.zoom = Vector2.ONE
		host.route_camera.force_update_scroll()
		var file := FileAccess.open(folder.path_join("lair_inputs.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"package":"forest_lair", "source_hash":loaded.package.source_hash, "occurrence":enemy.occurrence.occurrence_id, "position":str(enemy.global_position), "player_position":str(host.player.global_position), "camera_offset":str(host.route_camera.position), "zoom":1.0, "ui_scale":1.2, "tree_paused":true, "mode":"published map preview"}, "  ", true))
		file.close()
		await shot("lair_guardian")
		found = true
		break
	if not found: push_error("published lair guardian not active")
	paused = false
	await app.suspend()
	quit(0 if found else 1)

func geometry_sample() -> void:
	var sample: Node2D = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample)
	sample.set_process(false)
	paused = true
	var c: RunController = sample.controller
	var view: ExpeditionGeometryView = sample.view
	c.player.set_process(false)
	c.route_camera.position_smoothing_enabled = false
	c.control_preferences.ui_scale = 1.2
	c._apply_interface_preferences()
	c._update_hud()
	for row: Array in [["ground", "root", Vector3(90,0,150)], ["ramp", "slope", Vector3(340,16,150)], ["bridge", "bridge", Vector3(120,120,440)]]:
		var point := GeometryFixture.point(row[1],row[2])
		if c.player.world_point().position != point.position:
			var moved := c.player.move_world_to(point, sample.world.geometry_revision)
			if not moved.get("ok", false): push_error("route failed: " + str(moved)); quit(1); return
			c.player.advance_world(10000.0)
		view.sync()
		c.route_camera.force_update_scroll()
		await shot("geometry_" + row[0])
	var upper_pixel := view.project(sample.upper.world_point().position) + Vector2(0,-24)
	# Commands run synchronously with no frame advance; snapshots stay paused.
	paused = false
	var cast: Dictionary = c.spatial_pointer_skill(&"fire_spear", upper_pixel, false)
	paused = true
	print("E08_ACTION cast=", cast.get("ok", false))
	await shot("geometry_cast")
	paused = false
	c.player.cancel_active_cast()
	paused = true
	await shot("geometry_cancel")
	c.player.mage_cooldowns.clear()
	paused = false
	var second: Dictionary = c.spatial_pointer_skill(&"fire_spear", upper_pixel, false)
	if c.player.has_active_cast(): c.player._advance_world_cast(10.0)
	paused = true
	view.sync()
	print("E08_ACTION release=", second.get("ok", false))
	await shot("geometry_projectile")
	var ramp := GeometryFixture.point("slope", Vector3(340,16,150))
	var route: Dictionary = c.player.move_world_to(ramp, sample.world.geometry_revision)
	if route.get("ok", false): c.player.advance_world(10000.0)
	view.sync()
	paused = false
	var field: Dictionary = c.spatial_pointer_skill(&"fire_wall", view.project(Vector3(380,32,150)), false)
	if c.player.has_active_cast(): c.player._advance_world_cast(10.0)
	paused = true
	view.sync()
	print("E08_ACTION area=", field.get("ok",false))
	await shot("geometry_area")
	paused = false
	var teleported := c.player.use_world_teleport(GeometryFixture.point("slope", Vector3(380,32,150)), sample.world.geometry_revision)
	paused = true
	view.sync()
	print("E08_ACTION teleport=", teleported)
	await shot("geometry_teleport")
	c.player.character_animation.state.advance(0.2, Vector2(20,0))
	c.player.queue_redraw()
	await shot("geometry_walk_pose")
	c.player.character_animation.play(&"death")
	c.player.character_animation.state.advance(0.22, Vector2.ZERO)
	c.player.queue_redraw()
	await shot("geometry_death_pose")
	c.player.character_animation.state.revive()
	c.player.queue_redraw()
	await shot("geometry_revive_pose")
	var file := FileAccess.open(folder.path_join("geometry_inputs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"res://tests/fixtures/e07/f1/presentation_sample.tscn", "seed":"711", "viewport":[1280,720], "zoom":str(c.route_camera.zoom), "camera_offset":str(c.route_camera.position), "ui_scale":1.2, "tree_paused":true, "commands":"synchronous unpause/re-pause without advancing frames", "death_revive":"animation-only sample, not gameplay lifecycle", "points":["root (90,0,150)","slope (340,16,150)","bridge (120,120,440)"]}, "  ", true))
	file.close()
	quit()
