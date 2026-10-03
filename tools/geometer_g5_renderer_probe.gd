extends SceneTree
## G5 current-area underlay, one dominant closure and finite projectile arc.

const POINTS := [Vector2(720, 540), Vector2(1000, 450), Vector2(940, 650)]
var arena: RunController
var casting: GeometerCasting
var valid := true
var hits := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g5-renderer"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
	snapshot.skill_ranks = {&"geometer_trace": 5, &"geometer_triangulation": 5}
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
	arena.training_boss.global_position = Vector2(920, 560)
	arena.training_boss.health.max_hp = 10000.0
	arena.training_boss.health.current_hp = 10000.0
	for child: Node in arena.player.get_children():
		if child is Camera2D: child.position_smoothing_enabled = false
	casting = arena.geometer_casting
	casting.hit.connect(func(_request: DamageRequest, _actor: CombatActor) -> void: hits += 1)
	_triangle([&"fire", &"fire", &"fire"])
	valid = hits == 1 and valid
	await _shot("01_fff_closure")
	casting.advance(0.5)
	await _shot("02_fff_maintenance_floor")
	_triangle([&"ice", &"ice", &"ice"])
	casting.advance(0.01)
	valid = arena.training_boss.is_rooted() and is_equal_approx(arena.training_boss.slow_fraction, 0.20) and valid
	await _shot("03_ggg_containment")
	for point: Vector2 in [Vector2(880, 560), Vector2(960, 530)]:
		var actor := arena._spawn_enemy(&"chaser", point)
		actor.set_process(false)
		actor.health.max_hp = 10000.0
		actor.health.current_hp = 10000.0
	_triangle([&"lightning", &"lightning", &"lightning"])
	valid = hits == 3 and valid
	await _shot("04_rrr_closure_chain")
	casting.advance(0.5)
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.skill_id = &"basic_attack"
	request.magic_damage = 100.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var own := PlayerProjectile.new()
	arena.add_child(own)
	own.configure_directional(request, Vector2(920, 440) + PlayerProjectile.BODY_OFFSET, Vector2.DOWN, arena.enemies, arena.navigation, 600, 700)
	own.geometer_field = casting.wall_field
	own.hit.connect(arena._on_attack_requested)
	own.set_process(false)
	own._process(0.3)
	valid = own.is_queued_for_deletion() and hits == 5 and valid
	await _shot("05_rrr_projectile_arc")
	_triangle([&"fire", &"ice", &"lightning"])
	await _shot("06_fgr_composed_area")
	casting.construction.vertices[2].actor_id = arena.training_boss.get_instance_id()
	arena.training_boss.global_position = POINTS[0].lerp(POINTS[1], 0.5)
	casting.advance(0.5)
	valid = casting.construction.suspended and casting._wall_reactions.is_empty() and valid
	await _shot("07_mobile_suspended")
	arena.training_boss.global_position = POINTS[2]
	var before := hits
	casting.advance(0.01)
	valid = casting.construction.has_active_figure() and hits == before and valid
	await _shot("08_mobile_resumed_no_closure")
	casting.advance(casting.construction.figure_remaining + 0.01)
	valid = casting.construction.vertices.is_empty() and casting._wall_reactions.is_empty() and valid
	await _shot("09_expired_clean")
	print("Geometer G5 renderer: ", "PASS" if valid else "FAIL")
	arena.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _triangle(elements: Array[StringName]) -> void:
	casting.clear_construction()
	hits = 0
	for index: int in range(3):
		valid = bool(casting.construction.add_vertex(elements[index], POINTS[index], 0, 5, arena.navigation)["ok"]) and valid
	casting.triangle_field.form()

func _shot(stage: String) -> void:
	arena._update_hud()
	await process_frame
	await process_frame
	var screenshot := root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("geometer_g5_" + stage + ".png")
	valid = screenshot != null and screenshot.save_png(path) == OK and valid
	print(stage, " ", path)
