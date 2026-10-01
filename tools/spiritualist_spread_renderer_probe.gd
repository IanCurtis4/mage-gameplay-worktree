extends SceneTree
## Real OpenGL sequence for collective binding and finite propagation, text-free.

var arena: RunController
var captured := true
var valid := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "renderer-spread"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_dissipation": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", &"spiritualist_dissipation", null, null, null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.set_process(false)
	arena.battle_indicators.set_process(false)
	arena.combat_numbers_visible = false
	arena.help_panel.visible = false
	arena.hud_panel.visible = false
	arena.bottom_controls.visible = false
	arena.bottom_controls.modulate.a = 0.0
	arena.battle_controls.skill_bar.visible = false
	arena.battle_controls.settings_button.visible = false
	var boss := arena.training_boss
	boss.set_process(false)
	boss.global_position = Vector2(1000, 450)
	arena.player.global_position = Vector2(850, 450)
	arena.player.set_process(false)
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			(child as Camera2D).position_smoothing_enabled = false
	arena._spawn_training_add_wave()
	var adds: Array[CombatActor] = []
	for enemy: CombatActor in arena.enemies:
		if enemy != boss:
			adds.append(enemy)
	adds[0].global_position = boss.global_position + Vector2(-75, -55)
	adds[1].global_position = boss.global_position + Vector2(75, -55)
	for add: CombatActor in adds:
		add.set_process(false)
	valid = not arena.spiritualist_panel.visible and not arena.spiritualist_debug_text
	await _shot("01_before")
	arena._on_spiritualist_echo_curse_requested(_request(boss, &"spiritualist_echo_curse", 100.0, 1), boss, 0.35)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.spiritualist_echo_state.marks.size() == 3 and arena.battle_indicators.spiritualist_halo_groups().size() == 1
	await _shot("02_collective_mark")
	boss.apply_damage(_request(boss, &"soul_impact", 100.0, 2), arena.rng)
	arena._sync_spiritualist_combat_state()
	await _shot("03_first_pending")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.spiritualist_echo_state.pending.size() == 2
	await _shot("04_first_explosion")
	arena.battle_indicators._process(0.15)
	await _shot("05_first_spread_150ms")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.spiritualist_echo_state.pending.is_empty()
	await _shot("06_second_generation")
	arena.battle_indicators._process(0.16)
	await _shot("07_second_generation_160ms")
	arena.battle_indicators._process(0.55)
	arena._sync_spiritualist_combat_state()
	await _shot("08_rearmed_survivors")
	while arena.enemies.size() < 7:
		var extra := arena._spawn_enemy(&"archer", Vector2(1450, 450))
		extra.health.max_hp = RunController.TRAINING_ADD_HP
		extra.health.current_hp = RunController.TRAINING_ADD_HP
	var offsets := [Vector2(-80, -50), Vector2(0, -90), Vector2(80, -50), Vector2(-80, 50), Vector2(0, 90), Vector2(80, 50)]
	var index := 0
	for enemy: CombatActor in arena.enemies:
		if enemy == boss:
			continue
		enemy.set_process(false)
		enemy.global_position = boss.global_position + offsets[index]
		index += 1
	arena.spiritualist_echo_state.clear()
	arena._on_spiritualist_echo_curse_requested(_request(boss, &"spiritualist_echo_curse", 100.0, 3), boss, 0.35)
	arena._sync_spiritualist_combat_state()
	valid = valid and index == 6 and arena.spiritualist_echo_state.marks.size() == 7 and arena.battle_indicators.spiritualist_halo_groups().size() == 1
	await _shot("09_six_adds_bound")
	boss.apply_damage(_request(boss, &"soul_impact", 100.0, 4), arena.rng)
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.spiritualist_echo_state.pending.size() == 6
	await _shot("10_six_adds_first_wave")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.spiritualist_echo_state.pending.is_empty() and arena.battle_indicators.spiritualist_events.size() <= BattleIndicators.SPIRITUALIST_MAX_EVENTS
	await _shot("11_six_adds_second_wave")
	arena.battle_indicators._process(0.16)
	await _shot("12_six_adds_spread_160ms")
	print("Spiritualist spread renderer: ", "PASS" if valid and captured else "FAIL", " 12 stages; no diagnostic panel/status/numbers")
	arena.queue_free()
	current_scene = null
	quit(0 if valid and captured else 1)

func _request(target: CombatActor, skill_id: StringName, power: float, emission_id: int) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.emission_id = emission_id
	request.magic_damage = power
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _shot(stage: String) -> void:
	await process_frame
	await process_frame
	var screenshot := root.get_texture().get_image()
	if screenshot == null:
		captured = false
		return
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var filename := folder.path_join("spiritualist_spread_%s.png" % stage)
	captured = screenshot.save_png(filename) == OK and captured
	print(stage, " ", screenshot.get_size(), " ", filename)
