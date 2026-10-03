extends SceneTree
## Temporary, non-persisted G1 fixture. Does not unlock production Geometer.

var arena: RunController
var valid := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g1-renderer"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5}
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena.player.global_position = Vector2(850, 450)
	arena.training_boss.set_process(false)
	arena.training_boss.global_position = Vector2(1000, 450)
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			child.position_smoothing_enabled = false
	var casting := arena.geometer_casting
	arena._update_hud()
	arena.cast_intent.active_skill = &"geometer_trace"
	arena._update_aim(Vector2(720, 540))
	await _shot("01_ground_preview")
	casting.begin(casting.capture(&"geometer_trace", Vector2(720, 540), true))
	arena.player._advance_active_cast(1.0)
	var first := casting.get_child(0) as GeometerTraceProjectile
	first.set_process(false)
	first._process(0.5)
	await process_frame
	arena.player.mage_cooldowns.clear()
	arena._select_geometer_element(&"ice")
	casting.begin(casting.capture(&"geometer_trace", arena.training_boss.global_position + BattleTargeting.BODY_OFFSET))
	arena.player._advance_active_cast(1.0)
	var second := casting.get_child(0) as GeometerTraceProjectile
	second.set_process(false)
	second._process(0.05)
	arena._cancel_aim()
	arena._update_hud()
	await _shot("02_ice_flight")
	second._process(0.5)
	await process_frame
	casting.advance(0.1)
	arena._select_geometer_element(&"lightning")
	arena.cast_intent.active_skill = &"geometer_triangulation"
	arena._update_aim(Vector2(940, 650))
	arena._update_hud()
	valid = casting.construction.vertices.size() == 2 and casting.preview_valid
	await _shot("03_wall_and_triangle_preview")
	arena.training_boss.global_position += Vector2(0, 80)
	casting.advance(0.1)
	arena._update_aim(Vector2(940, 650))
	await _shot("04_moving_anchor")
	print("Geometer G1 renderer: ", "PASS" if valid else "FAIL")
	arena.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _shot(stage: String) -> void:
	await process_frame
	await process_frame
	var screenshot := root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("geometer_g1_" + stage + ".png")
	valid = screenshot != null and screenshot.save_png(path) == OK and valid
	print(stage, " ", path)
