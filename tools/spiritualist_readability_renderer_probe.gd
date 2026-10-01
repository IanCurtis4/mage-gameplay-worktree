extends SceneTree
## Real OpenGL sequence from the training arena; screenshots stay ignored by Git.

var arena: RunController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "renderer-spiritualist"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_dissipation": 1, &"spiritualist_soul_drain": 1, &"spiritualist_procession": 1, &"spiritualist_channel_focus": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", &"spiritualist_dissipation", &"spiritualist_soul_drain", &"spiritualist_procession", null]
	snapshot.passive_slots = [&"spiritualist_channel_focus", null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.combat_numbers_visible = false
	arena.help_panel.visible = false
	var boss := arena.training_boss
	boss.set_process(false)
	arena._spawn_training_add_wave()
	for enemy: CombatActor in arena.enemies:
		enemy.set_process(false)
	# Keep the boss and adds clear of the fixed right-side help/readability panels.
	boss.global_position = Vector2(1000, 450)
	var add_positions := [Vector2(900, 300), Vector2(780, 450)]
	var add_index := 0
	for enemy: CombatActor in arena.enemies:
		if enemy == boss:
			continue
		enemy.global_position = add_positions[add_index]
		add_index += 1
	arena.player.global_position = Vector2(880, 450)
	arena.player.set_process(false)
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			(child as Camera2D).position_smoothing_enabled = false
	arena._select_enemy(boss)
	arena._update_hud()
	var no_overlap: bool = not arena.spiritualist_panel.get_global_rect().intersects(arena.hud_panel.get_global_rect()) and not arena.spiritualist_panel.get_global_rect().intersects(arena.help_panel.get_global_rect()) and not arena.spiritualist_panel.get_global_rect().intersects(arena.bottom_controls.get_global_rect())
	var captured := await _capture("before")
	arena.spiritualist_help_toggle.button_pressed = true
	await process_frame
	no_overlap = no_overlap and not arena.spiritualist_panel.get_global_rect().intersects(arena.bottom_controls.get_global_rect())
	captured = (await _capture("expanded")) and captured
	arena.spiritualist_help_toggle.button_pressed = false
	var curse := _request(boss, &"spiritualist_echo_curse", 110.0)
	arena._on_spiritualist_echo_curse_requested(curse, boss, 0.50)
	arena._sync_spiritualist_combat_state()
	arena._update_hud()
	captured = (await _capture("mark")) and captured
	boss.apply_damage(_request(boss, &"soul_impact", 100.0), arena.rng)
	arena._sync_spiritualist_combat_state()
	arena._update_hud()
	var prepared: bool = arena.spiritualist_echo_state.pending.size() == 1
	captured = (await _capture("prepared")) and captured
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	arena._sync_spiritualist_combat_state()
	arena._update_hud()
	var success: bool = arena.battle_indicators.spiritualist_events[-1]["kind"] == &"echo_hit"
	captured = (await _capture("echo_hit")) and captured
	await create_timer(0.18).timeout
	captured = (await _capture("echo_hit_late")) and captured
	arena.spiritualist_echo_state.mark(boss.get_instance_id(), 0.50)
	arena._sync_spiritualist_combat_state()
	arena._on_spiritualist_dissipation_requested(boss.global_position, _request(boss, &"spiritualist_dissipation", 110.0), 0.0, 0.0)
	arena._sync_spiritualist_combat_state()
	arena._update_hud()
	var rite: bool = not arena.spiritualist_echo_state.has_mark(boss.get_instance_id()) and arena.spiritualist_echo_state.pending.is_empty()
	captured = (await _capture("rite")) and captured
	arena._update_hud()
	var weakened: bool = arena.battle_indicators.spiritualist_weakened.has(boss.get_instance_id())
	captured = (await _capture("weakened")) and captured
	arena.player.health.current_hp = maxf(1.0, arena.player.health.max_hp - 80.0)
	arena._on_spiritualist_drain_requested(_request(boss, &"spiritualist_soul_drain", 120.0), boss)
	arena._advance_spiritualist_drain(0.5)
	arena._update_hud()
	var channel: bool = arena.spiritualist_drain_state.ticks_resolved == 1
	captured = (await _capture("channel")) and captured
	arena._advance_spiritualist_drain(1.5)
	arena.battle_indicators.sync_spiritualist_focus(arena.player.get_instance_id(), arena.player.spiritualist_focus_remaining)
	arena._update_hud()
	var focus: bool = arena.player.spiritualist_focus_remaining > 0.0
	captured = (await _capture("focus")) and captured
	var add_count := 0
	for enemy: CombatActor in arena.enemies:
		if enemy == boss:
			continue
		arena.spiritualist_echo_state.mark(enemy.get_instance_id(), 0.50)
		add_count += 1
	arena._sync_spiritualist_combat_state()
	arena._update_hud()
	var multi: bool = add_count == 2 and arena.battle_indicators.spiritualist_marks.size() == 2
	captured = (await _capture("multi_targets")) and captured
	var passed: bool = captured and prepared and success and rite and weakened and channel and focus and multi and no_overlap
	print("Spiritualist renderer: ", "PASS" if passed else "FAIL", " panel=", arena.spiritualist_panel.get_global_rect(), " overlap=", not no_overlap)
	arena.queue_free()
	current_scene = null
	quit(0 if passed else 1)

func _request(target: CombatActor, skill_id: StringName, power: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.magic_damage = power
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _capture(stage: String) -> bool:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("O probe requer renderer real; execute sem --headless.")
		return false
	var output_dir := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var path := output_dir.path_join("spiritualist_readability_%s.png" % stage)
	var saved := image.save_png(path) == OK
	print(stage, " ", image.get_size(), " ", path)
	return saved
