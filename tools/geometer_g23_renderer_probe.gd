extends SceneTree
## Geometry presentation only; no production profile, fields or final class art.

var arena: RunController
var valid := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g23-renderer"
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
	var state := casting.construction
	var first := Vector2(720, 540)
	var third := Vector2(940, 650)
	valid = bool(state.add_vertex(&"fire", first, 0, 5, arena.navigation)["ok"]) and valid
	valid = bool(state.add_vertex(&"ice", arena.training_boss.global_position, arena.training_boss.get_instance_id(), 5, arena.navigation)["ok"]) and valid
	valid = bool(state.add_vertex(&"lightning", third, 0, 5, arena.navigation)["ok"]) and valid
	arena._update_hud()
	await _shot("01_active_triangle")
	arena.training_boss.global_position = first.lerp(third, 0.5)
	casting.advance(0.2)
	valid = state.suspended and casting.outline_segments().size() == 3 and valid
	await _shot("02_degenerate_suspended")
	arena.training_boss.global_position = Vector2(980, 490)
	casting.advance(0.2)
	valid = state.has_active_figure() and valid
	await _shot("03_resumed_mobile")
	var carrier := arena.training_boss.get_instance_id()
	casting.targets.erase(arena.training_boss) # Presentation fixture of carrier removal.
	casting.advance(0.2)
	valid = state.vertices[1].actor_id == 0 and valid
	await _shot("04_deposited_ground")
	casting.targets.append(arena.training_boss)
	state.vertices[1].actor_id = carrier
	arena.training_boss.global_position = Vector2(NAN, 540)
	casting.advance(0.1)
	# Keep invalid geometry for drawing QA; actor itself must not render at NaN.
	arena.training_boss.global_position = Vector2(980, 490)
	valid = state.suspended and casting.outline_segments().size() == 1 and valid
	await _shot("05_invalid_geometry")
	casting.advance(state.figure_remaining + 0.01)
	valid = state.vertices.is_empty() and valid
	await _shot("06_expired_clean")
	print("Geometer G2/G3 renderer: ", "PASS" if valid else "FAIL")
	arena.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _shot(stage: String) -> void:
	await process_frame
	await process_frame
	var screenshot := root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("geometer_g23_" + stage + ".png")
	valid = screenshot != null and screenshot.save_png(path) == OK and valid
	print(stage, " ", path)
