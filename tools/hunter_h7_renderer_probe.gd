extends "res://tools/hunter_h6_renderer_probe.gd"
## Explicit positional scene only. Real automatic AI/projectiles and canonical HP/SP.
## FPS is a requested cap, not a benchmark. No profile or control settings in user://.

const ACTIVE_OUTPUT := "res://docs/art/hunter_h7"
var hostile_attacks := 0
var walked := 0.0
var consumed := 0
var opening_seen := false

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "native renderer required")
		_finish_active()
		return
	var hz := 60
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("hz="):
			hz = int(argument.trim_prefix("hz="))
	_check(hz in [30, 60, 144], "supported frame cap")
	Engine.max_fps = hz
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTIVE_OUTPUT))
	for ambusher: bool in [false, true]:
		for defense: bool in [false, true]:
			await _active_case(ambusher, defense, hz)
	_finish_active()

func _finish_active() -> void:
	print("Hunter H7 native active: %s (%d checks, %d captures, %d failures; automatic AI, no resource refill)" % ["PASS" if failures == 0 else "FAIL", checks, captures, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _active_case(ambusher: bool, defense: bool, hz: int) -> void:
	var prefix := "%s_%s_%dhz" % ["emboscadora" if ambusher else "preparadora", "defesa" if defense else "solo", hz]
	RunController.pending_run_state = RunState.from_build("", _build(ambusher))
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	arena = (load("res://scenes/main.tscn") as PackedScene).instantiate() as RunController
	arena.control_preferences.path = "res://.godot/verification/hunter_h7_probe_controls.cfg"
	add_child(arena)
	# Only human input is disabled. Runtime process callbacks remain automatic.
	arena.set_process_input(false)
	arena.set_process_unhandled_input(false)
	arena.rng.seed = 7181
	arena.player.global_position = Vector2(850, 450)
	arena.training_boss.global_position = Vector2(1110, 450)
	arena._training_add_elapsed = 0.0
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			(child as Camera2D).position_smoothing_enabled = false
	hostile_attacks = 0
	walked = 0.0
	consumed = 0
	opening_seen = false
	_watch_enemy(arena.training_boss)
	if defense:
		_watch_enemy(arena._spawn_enemy(&"archer", Vector2(1160, 470)))
		_watch_enemy(arena._spawn_enemy(&"chaser", Vector2(1110, 510)))
		_watch_enemy(arena._spawn_enemy(&"chaser", Vector2(970, 260)))
	_check(arena.player.is_processing() and arena.training_boss.is_processing(), prefix + " automatic player/AI enabled")
	_check(arena.persistent_facade == null and arena.ui_root.visible and arena.navigation._obstacles.size() == 3, prefix + " actual HUD/obstacles, no persistent facade")
	var initial_hp := arena.player.health.current_hp
	var initial_sp := arena.player.current_sp
	_check(arena.player.use_hunter_mark(arena.training_boss), prefix + " paid Mark")
	_check(arena.player.use_hunter_trap(&"hunter_freezing_trap", Vector2(985, 450)), prefix + " paid freezing mechanism")
	if defense:
		_check(arena.player.use_hunter_trap(&"hunter_tar_trap", Vector2(985, 510)), prefix + " paid Tar mechanism")
		if not ambusher:
			_check(arena.player.use_hunter_trap(&"hunter_thorn_trap", Vector2(965, 500)), prefix + " paid Thorn mechanism")
	await _wait_active(0.2)
	await _active_capture(prefix + "_01_preparing")
	await _wait_active(1.1)
	_check(opening_seen, prefix + " moving AI naturally triggered armed opening")
	await _active_capture(prefix + "_02_opening")
	arena.player.target = arena.training_boss
	_check(arena.player.use_hunter_covering_shot(arena.player.global_position.direction_to(arena.training_boss.global_position + PlayerProjectile.BODY_OFFSET)), prefix + " paid Covering Shot")
	await _wait_active(0.7)
	_check(consumed > 0, prefix + " real moving projectile consumed an opening")
	_check(arena.player.hunter_state.step_remaining > 0.0, prefix + " Hunt Step from real impact")
	_check(arena.player.use_hunter_total_cover(arena.player.global_position), prefix + " paid Total Cover")
	arena.player.target = null
	arena.player.move_to(arena.player.global_position + Vector2(-45, 45))
	await _wait_active(0.3)
	await _active_capture(prefix + "_03_step_cover")
	await _wait_active(1.1)
	_check(walked > 30.0 and hostile_attacks > 0, prefix + " AI navigation and actual hostile emissions")
	_check(arena.player.health.max_hp == initial_hp and arena.player.current_sp < initial_sp and arena.player.is_alive(), prefix + " canonical health and paid resources, no refill")
	_check(arena.player.hunter_presentation.events.size() <= 16 and arena.player.hunter_presentation.trails.size() <= 6, prefix + " bounded presentation")
	print("H7 active case %s: walked=%.1f attacks=%d consumed=%d hp=%.1f sp=%.1f" % [prefix, walked, hostile_attacks, consumed, arena.player.health.current_hp, arena.player.current_sp])
	arena._show_result(false)
	_check(arena.player.hunter_state._openings.is_empty() and arena.player.hunter_presentation.events.is_empty() and arena.player.hunter_cover.zone_id == 0, prefix + " terminal state cleared")
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("player_traps").is_empty() and get_tree().get_nodes_in_group("foliage_shelters").is_empty(), prefix + " no orphan mechanisms/cover")
	arena = null

func _watch_enemy(enemy: EnemyActor) -> void:
	enemy.ground_walked.connect(func(from: Vector2, to: Vector2) -> void: walked += from.distance_to(to))
	enemy.attack_requested.connect(func(_request: DamageRequest, _target: CombatActor, _ranged: bool) -> void: hostile_attacks += 1)
	enemy.health.damage_applied.connect(func(result: Dictionary) -> void:
		if StringName(result.get("skill_id", &"")) == &"hunter_exploit":
			consumed += 1)

func _wait_active(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if is_instance_valid(arena.training_boss) and not arena.player.hunter_state.opening(arena.training_boss.get_instance_id()).is_empty():
			opening_seen = true

func _active_capture(filename: String) -> void:
	arena.status_label.text = "PROVA H7 · IA ativa · " + filename + " · sem medida de FPS/DPS"
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(ACTIVE_OUTPUT.path_join(filename + ".png"))
	_check(error == OK, "native capture " + filename)
	captures += 1
