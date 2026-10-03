extends SceneTree
## G6 actual command preview/edits and one consumed-area resolution, no profile.

const POINTS := [Vector2(720, 540), Vector2(1000, 450), Vector2(940, 650)]
var arena: RunController
var casting: GeometerCasting
var valid := true
var hits := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g6-renderer"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation", &"geometer_translation", &"geometer_rewrite", &"geometer_collapse", &"geometer_vector_memory"]
	snapshot.skill_ranks = {&"geometer_trace": 5, &"geometer_triangulation": 5, &"geometer_translation": 5, &"geometer_rewrite": 5, &"geometer_collapse": 5, &"geometer_vector_memory": 3}
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", &"geometer_translation", &"geometer_collapse", &"geometer_rewrite"]
	snapshot.passive_slots = [&"geometer_vector_memory", null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena.player.global_position = Vector2(850, 450)
	arena.training_boss.set_process(false)
	arena.training_boss.global_position = Vector2(920, 560)
	arena.training_boss.health.max_hp = 10000
	arena.training_boss.health.current_hp = 10000
	for child: Node in arena.player.get_children():
		if child is Camera2D: child.position_smoothing_enabled = false
	casting = arena.geometer_casting
	casting.hit.connect(func(_request: DamageRequest, _actor: CombatActor) -> void: hits += 1)
	_shape([&"fire", &"ice", &"lightning"])
	casting.advance(0.5)
	var identity := casting.construction.construction_id
	var remaining := casting.construction.figure_remaining
	arena._select_skill_from_bar(&"geometer_translation")
	arena._update_aim(Vector2(900, 640))
	valid = casting.preview_valid and valid
	await _shot("01_translation_preview")
	arena._commit_skill(arena.cast_intent.confirm(), Vector2(900, 640))
	arena._cancel_aim()
	valid = casting.construction.positions()[2] == Vector2(900, 640) and casting.construction.vertices[2].remaining == 12 and valid
	await _shot("02_translated_ground")
	casting.select(&"fire")
	arena._select_skill_from_bar(&"geometer_rewrite")
	arena._update_aim(Vector2(720, 580))
	valid = casting.preview_valid and valid
	await _shot("03_rewrite_preview")
	arena._commit_skill(arena.cast_intent.confirm(), Vector2(720, 580))
	arena._cancel_aim()
	valid = casting.construction.elements() == [&"ice", &"lightning", &"fire"] and casting.construction.construction_id == identity and casting.construction.figure_remaining == remaining and valid
	await _shot("04_rewritten_bcd")
	var before := hits
	arena._select_skill_from_bar(&"geometer_collapse")
	valid = casting.construction.vertices.is_empty() and hits == before + 1 and valid
	await _shot("05_triangle_collapse")
	casting.advance(0.5)
	await _shot("06_triangle_clean")
	_shape([&"fire", &"ice"])
	arena.training_boss.global_position = POINTS[0].lerp(POINTS[1], 0.5)
	arena.player.mage_cooldowns[&"geometer_collapse"] = 0
	before = hits
	arena._select_skill_from_bar(&"geometer_collapse")
	valid = casting.construction.vertices.is_empty() and hits == before + 1 and valid
	await _shot("07_wall_collapse_strip")
	casting.advance(0.5)
	valid = casting._wall_reactions.is_empty() and valid
	await _shot("08_wall_clean")
	print("Geometer G6 renderer: ", "PASS" if valid else "FAIL")
	arena.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _shape(elements: Array[StringName]) -> void:
	casting.clear_construction()
	for index: int in elements.size():
		valid = bool(casting.construction.add_vertex(elements[index], POINTS[index], 0, 5, arena.navigation)["ok"]) and valid
	casting.wall_field.capture_construction()
	if elements.size() == 3: casting.triangle_field.form()

func _shot(stage: String) -> void:
	arena._update_hud()
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	for button: Button in arena.battle_controls.skill_buttons.values():
		valid = viewport_rect.encloses(button.get_global_rect()) and valid
	var screenshot := root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("geometer_g6_" + stage + ".png")
	valid = screenshot != null and screenshot.save_png(path) == OK and valid
	print(stage, " ", path)
