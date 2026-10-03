extends SceneTree
## Actual G4 events on the real arena; presentation evidence, not a final art gate.

const A := Vector2(720, 540)
const B := Vector2(1000, 540)
var arena: RunController
var casting: GeometerCasting
var valid := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "geometer-g4-renderer"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"mg_ar"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = [&"geometer_trace", &"geometer_triangulation", &"geometer_incidence"]
	snapshot.skill_ranks = {&"geometer_trace": 5, &"geometer_triangulation": 5, &"geometer_incidence": 3}
	snapshot.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
	snapshot.passive_slots = [&"geometer_incidence", null, null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena.player.global_position = Vector2(850, 450)
	arena.training_boss.set_process(false)
	arena.training_boss.health.max_hp = 10000.0
	arena.training_boss.health.current_hp = 10000.0
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			child.position_smoothing_enabled = false
	casting = arena.geometer_casting
	_wall(&"fire", &"ice")
	var hp := arena.training_boss.health.current_hp
	_walk()
	valid = arena.training_boss.health.current_hp < hp and not casting._wall_reactions.is_empty() and valid
	await _shot("01_fire_traversal")
	_wall(&"ice", &"lightning")
	_walk()
	valid = arena.training_boss.slow_fraction > 0.0 and not casting._wall_reactions.is_empty() and valid
	await _shot("02_ice_traversal")
	_wall(&"lightning", &"fire")
	arena.training_boss.global_position = Vector2(1000, 615)
	var own := _owned()
	own._process(0.14)
	valid = own.geometer_conduction_endpoint.is_finite() and own.geometer_fire_request != null and valid
	await _shot("03_conduction_contact")
	own._process(0.4)
	valid = own.is_queued_for_deletion() and own.geometer_fire_request == null and valid
	await _shot("04_fire_impact")
	_wall(&"ice", &"lightning")
	own = _owned()
	own._process(0.14)
	valid = own.direction.x > 0.5 and not own.homing and valid
	await _shot("05_redirect_contact")
	own.queue_free()
	_wall(&"lightning", &"ice")
	var request := DamageRequest.new()
	request.source_id = arena.training_boss.get_instance_id()
	request.target_id = arena.player.get_instance_id()
	request.physical_damage = 10.0
	var arrow := ArrowProjectile.new()
	arena.add_child(arrow)
	arrow.configure(request, arena.player, Vector2(860, 640) + ArrowProjectile.BODY_OFFSET, arena.navigation)
	arrow.geometer_field = casting.wall_field
	arrow.set_process(false)
	arena.player.current_sp -= 10.0
	var sp := arena.player.current_sp
	arrow._process(0.4)
	valid = arrow.is_queued_for_deletion() and arena.player.current_sp == sp + 4.0 and valid
	await _shot("06_hostile_interception")
	casting.advance(6.0)
	valid = casting.construction.vertices.is_empty() and casting._wall_reactions.is_empty() and valid
	await _shot("07_expired_clean")
	print("Geometer G4 renderer: ", "PASS" if valid else "FAIL")
	arena.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _wall(first: StringName, second: StringName) -> void:
	casting.clear_construction()
	valid = bool(casting.construction.add_vertex(first, A, 0, 5, arena.navigation)["ok"]) and valid
	valid = bool(casting.construction.add_vertex(second, B, 0, 5, arena.navigation)["ok"]) and valid
	casting.advance(0.01)
	arena._update_hud()

func _walk() -> void:
	arena.training_boss.global_position = Vector2(860, 490)
	arena.training_boss._path = PackedVector2Array([Vector2(860, 590)])
	arena.training_boss._path_index = 0
	arena.training_boss._move_along_path(3.0)

func _owned() -> PlayerProjectile:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.magic_damage = 100.0
	request.skill_id = &"basic_attack"
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var own := PlayerProjectile.new()
	arena.add_child(own)
	own.configure_directional(request, Vector2(860, 450) + PlayerProjectile.BODY_OFFSET, Vector2.DOWN, arena.enemies, arena.navigation, 600.0, 1000.0)
	own.geometer_field = casting.wall_field
	own.hit.connect(arena._on_attack_requested)
	own.set_process(false)
	return own

func _shot(stage: String) -> void:
	arena._update_hud()
	await process_frame
	await process_frame
	var screenshot := root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("geometer_g4_" + stage + ".png")
	valid = screenshot != null and screenshot.save_png(path) == OK and valid
	print(stage, " ", path)
