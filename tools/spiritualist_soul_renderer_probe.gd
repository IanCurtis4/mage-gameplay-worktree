extends SceneTree
## Real OpenGL gameplay-scale timeline. All screenshots are ignored by Git.

var arena: RunController
var captured := true
var valid := true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "renderer-souls"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_dissipation": 1, &"spiritualist_soul_drain": 1, &"spiritualist_spectral_veil": 1, &"spiritualist_procession": 1, &"spiritualist_channel_focus": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", &"spiritualist_dissipation", &"spiritualist_soul_drain", &"spiritualist_spectral_veil", &"spiritualist_procession"]
	snapshot.passive_slots = [&"spiritualist_channel_focus", null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	await process_frame
	# Freeze autonomous clocks; the named frames below advance only the intended
	# authoritative state and cosmetic clock, independent of PNG save latency.
	arena.set_process(false)
	arena.battle_indicators.set_process(false)
	arena.combat_numbers_visible = false
	arena.help_panel.visible = false
	arena.hud_panel.visible = false
	arena.bottom_controls.visible = false
	arena.battle_controls.skill_bar.visible = false
	arena.battle_controls.settings_button.visible = false
	var boss := arena.training_boss
	boss.set_process(false)
	boss.global_position = Vector2(1000, 450)
	arena.player.global_position = Vector2(880, 450)
	arena.player.set_process(false)
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			(child as Camera2D).position_smoothing_enabled = false
	arena._select_enemy(boss)
	valid = not arena.spiritualist_panel.visible and not arena.spiritualist_debug_text and not arena.combat_numbers_visible
	await _shot("01_before")
	var curse := _request(boss, &"spiritualist_echo_curse", 110.0)
	arena._on_spiritualist_echo_curse_requested(curse, boss, 0.50)
	arena._sync_spiritualist_combat_state()
	await _shot("02_bound_000ms")
	boss.global_position += Vector2(38, 0)
	arena._sync_spiritualist_combat_state()
	await _shot("03_bound_moving")
	boss.global_position -= Vector2(38, 0)
	boss.apply_damage(_request(boss, &"soul_impact", 100.0), arena.rng)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.spiritualist_echo_state.pending.size() == 1
	await _shot("04_pending_000ms")
	arena.spiritualist_echo_state.advance(0.16)
	arena.battle_indicators._process(0.16)
	arena._sync_spiritualist_combat_state()
	await _shot("05_pending_160ms")
	boss.global_position += Vector2(30, 0)
	arena._sync_spiritualist_combat_state()
	await _shot("06_pending_moving")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.22):
		arena._apply_spiritualist_echo(echo)
	arena.battle_indicators._process(0.03)
	arena._sync_spiritualist_combat_state()
	valid = valid and _has_event(&"echo_hit")
	await _shot("07_echo_impact_000ms")
	arena.battle_indicators._process(0.17)
	await _shot("08_echo_expulsion_170ms")
	arena.battle_indicators._process(0.50)
	boss.global_position -= Vector2(30, 0)
	arena.spiritualist_echo_state.mark(boss.get_instance_id(), 0.50)
	boss.apply_damage(_request(boss, &"soul_impact", 100.0), arena.rng)
	boss.health.grant_shield(1000.0)
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	boss.health.clear_shield()
	valid = valid and _has_event(&"echo_absorbed")
	await _shot("09_echo_absorbed")
	arena.battle_indicators._process(0.40)
	arena.spiritualist_echo_state.mark(boss.get_instance_id(), 0.50)
	var before_expiry := arena.spiritualist_echo_state.marks.keys()
	arena.spiritualist_echo_state.advance(5.01)
	arena._announce_spiritualist_mark_expiry(before_expiry)
	arena._sync_spiritualist_combat_state()
	valid = valid and _has_event(&"expire")
	await _shot("10_expiry_000ms")
	arena.battle_indicators._process(0.26)
	await _shot("11_expiry_260ms")
	arena.spiritualist_echo_state.mark(boss.get_instance_id(), 0.50)
	arena._sync_spiritualist_combat_state()
	arena._on_spiritualist_dissipation_requested(boss.global_position, _request(boss, &"spiritualist_dissipation", 110.0), 0.0, 0.0)
	arena._sync_spiritualist_combat_state()
	valid = valid and _has_event(&"break") and not arena.spiritualist_echo_state.has_mark(boss.get_instance_id())
	await _shot("12_rite_000ms")
	arena.battle_indicators._process(0.15)
	await _shot("13_rite_150ms")
	boss.remove_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_dissipation")
	var veil_center := boss.global_position
	arena._on_spiritualist_veil_requested(veil_center, 2.0, 0.15)
	arena._sync_spiritualist_combat_state()
	valid = valid and arena.battle_indicators.spiritualist_veil_members.has(boss.get_instance_id())
	await _shot("14_veil_entry")
	arena._advance_spiritualist_veil(0.18)
	arena._sync_spiritualist_combat_state()
	await _shot("15_veil_maintenance")
	boss.global_position = veil_center + Vector2(SpiritualistVeilState.RADIUS + 35, 0)
	arena._advance_spiritualist_veil(0.05)
	arena._sync_spiritualist_combat_state()
	valid = valid and not arena.battle_indicators.spiritualist_veil_members.has(boss.get_instance_id())
	await _shot("16_veil_exit")
	boss.global_position = veil_center
	arena._advance_spiritualist_veil(0.05)
	arena._sync_spiritualist_combat_state()
	await _shot("17_veil_reentry")
	arena._advance_spiritualist_veil(2.1)
	arena._sync_spiritualist_combat_state()
	await _shot("18_veil_end")
	arena.player.health.current_hp = arena.player.health.max_hp - 70.0
	arena._on_spiritualist_drain_requested(_request(boss, &"spiritualist_soul_drain", 120.0), boss)
	arena._advance_spiritualist_drain(0.5)
	await _shot("19_drain_tick")
	arena._advance_spiritualist_drain(1.5)
	arena.battle_indicators.sync_spiritualist_focus(arena.player.get_instance_id(), arena.player.spiritualist_focus_remaining)
	valid = valid and arena.player.spiritualist_focus_remaining > 0.0
	await _shot("20_focus_companion")
	arena._on_spiritualist_procession_requested(_request(boss, &"spiritualist_procession", 100.0), boss)
	arena._advance_spiritualist_procession(0.23)
	valid = valid and _has_event(&"procession_hit")
	await _shot("21_procession_impact")
	arena._spawn_training_add_wave()
	arena._spawn_training_add_wave()
	arena._spawn_training_add_wave()
	var add_positions := [Vector2(900, 260), Vector2(1030, 260), Vector2(1130, 330), Vector2(740, 450), Vector2(800, 540), Vector2(1100, 520)]
	var add_index := 0
	for enemy: CombatActor in arena.enemies:
		if enemy == boss:
			continue
		enemy.set_process(false)
		enemy.global_position = add_positions[add_index]
		arena.spiritualist_echo_state.mark(enemy.get_instance_id(), 0.50)
		enemy.apply_weaken(0.15, 2.0, &"renderer_dense")
		add_index += 1
	arena.spiritualist_echo_state.mark(boss.get_instance_id(), 0.50)
	boss.apply_weaken(0.20, 2.0, &"renderer_dense")
	arena._sync_spiritualist_combat_state()
	valid = valid and add_index == 6 and arena.battle_indicators.spiritualist_marks.size() == 7
	await _shot("22_six_adds_dense")
	var visual_clock := arena.battle_indicators.spiritualist_visual_clock
	paused = true
	arena.battle_indicators._process(0.3)
	valid = valid and is_equal_approx(arena.battle_indicators.spiritualist_visual_clock, visual_clock)
	paused = false
	valid = valid and arena._spiritualist_feedback_labels.is_empty()
	print("Spiritualist soul renderer: ", "PASS" if valid and captured else "FAIL", " 22 stages; no diagnostic panel/status/numbers")
	arena.queue_free()
	current_scene = null
	quit(0 if valid and captured else 1)

func _request(target: CombatActor, skill_id: StringName, power: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.magic_damage = power
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _has_event(kind: StringName) -> bool:
	for event: Dictionary in arena.battle_indicators.spiritualist_events:
		if event["kind"] == kind:
			return true
	return false

func _shot(stage: String) -> void:
	await process_frame
	await process_frame
	var screenshot := root.get_texture().get_image()
	if screenshot == null:
		push_error("Rode sem --headless, com renderer OpenGL real.")
		captured = false
		return
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var filename := folder.path_join("spiritualist_souls_%s.png" % stage)
	captured = screenshot.save_png(filename) == OK and captured
	print(stage, " ", screenshot.get_size(), " ", filename)
