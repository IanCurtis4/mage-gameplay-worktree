extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var debuffs := AttributeDebuffState.new()
	debuffs.apply(AttributeDebuffState.DAMAGE_DEALT, &"weak", 0.15, 4.0)
	debuffs.apply(AttributeDebuffState.DAMAGE_DEALT, &"strong", 0.20, 2.0)
	_check(debuffs.effective_state(AttributeDebuffState.DAMAGE_DEALT) == {"fraction": 0.20, "remaining": 2.0}, "effective label uses strongest source rather than summing or longest weaker source")
	debuffs.advance(2.1)
	_check(is_equal_approx(float(debuffs.effective_state(AttributeDebuffState.DAMAGE_DEALT)["fraction"]), 0.15), "weaker source reappears after stronger source expires")

	var catalog := ProfileCatalog.pilot()
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "readability-character"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_soul_drain": 1, &"spiritualist_dissipation": 1, &"spiritualist_procession": 1, &"spiritualist_echo_recovery": 1, &"spiritualist_channel_focus": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", &"spiritualist_soul_drain", &"spiritualist_dissipation", &"spiritualist_procession", null]
	snapshot.passive_slots = [&"spiritualist_echo_recovery", &"spiritualist_channel_focus"]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	await process_frame
	var boss := arena.training_boss
	var boss_id := boss.get_instance_id()
	boss.set_process(false)
	arena.player.global_position = boss.global_position + Vector2(-65, 0)
	arena._select_enemy(boss)
	_check(not arena.spiritualist_panel.visible and not arena.spiritualist_debug_text, "Spiritualist explanation panel and floating notices are opt-in diagnostics")
	arena.set_spiritualist_debug_text(true)
	_check(arena.spiritualist_panel != null and arena.spiritualist_help_toggle != null and arena.training_mode, "real training arena builds the compact class panel")
	arena._update_spiritualist_panel()
	_check(arena.spiritualist_help_label.text.contains("Maldição") and arena.spiritualist_help_label.text.contains("Rito") and arena.spiritualist_help_label.text.contains("Foco"), "help describes only equipped combo routes and passive")
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	arena._sync_spiritualist_combat_state()
	arena._update_spiritualist_panel()
	_check(arena.battle_indicators.spiritualist_mark_remaining.has(boss_id) and arena.spiritualist_state_label.text.contains("MALDIÇÃO 5.0s"), "mark timer and focused-target text read the authoritative mark")
	var shield_request := _request(arena.player, boss, &"basic_attack", 70.0)
	boss.health.grant_shield(1000.0)
	boss.apply_damage(shield_request, arena.rng)
	_check(arena.spiritualist_echo_state.has_mark(boss_id) and arena.spiritualist_echo_state.pending.is_empty(), "fully absorbed hit preserves mark and never claims Eco")
	boss.health.clear_shield()
	arena.player.current_sp = 0.0
	boss.apply_damage(shield_request, arena.rng)
	arena._sync_spiritualist_combat_state()
	arena._update_spiritualist_panel()
	_check(not arena.spiritualist_echo_state.has_mark(boss_id) and arena.spiritualist_echo_state.pending.size() == 1 and arena.battle_indicators.spiritualist_pending_remaining.has(boss_id) and arena.spiritualist_state_label.text.contains("ECO PREPARADO"), "real direct hit converts mark to visible pending Echo")
	_check(arena.battle_indicators.spiritualist_events[-1]["kind"] == &"echo_ready" and _has_label(arena, "ECO PREPARADO"), "preparation is announced once without false damage confirmation")
	_check(arena.spiritualist_hint_label.text == "ECO PREPARADO", "focused panel repeats the recent transition if world text is obscured")
	_check(_has_label(arena, " SP"), "Recolhimento reports only a real SP restitution")
	var pending_before := float(arena.spiritualist_echo_state.pending[0]["remaining"])
	paused = true
	arena._process(1.0)
	arena.battle_indicators._process(1.0)
	_check(is_equal_approx(float(arena.spiritualist_echo_state.pending[0]["remaining"]), pending_before), "pause freezes pending Echo and presentation")
	_check(arena._spiritualist_recent_feedback_remaining > 0.0, "pause freezes recent feedback")
	paused = false
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	_check(arena.battle_indicators.spiritualist_events[-1]["kind"] == &"echo_hit" and _has_label(arena, "ECO! "), "positive Echo uses one real damage number labelled ECO and two-wave event")
	_check(_combat_lanes_unique(arena, boss), "damage numbers and status labels share three non-overlapping lanes per target")
	var echo_label := _feedback_label(arena, "ECO! ")
	var echo_position := echo_label.position if echo_label != null else Vector2.INF
	await create_timer(0.18).timeout
	_check(echo_label != null and is_instance_valid(echo_label) and echo_label.position.distance_to(echo_position) < 0.01 and _combat_lanes_unique(arena, boss), "Spiritualist labels fade in stationary lanes instead of drifting into neighboring text")
	arena._update_spiritualist_panel()
	_check(arena.spiritualist_hint_label.text.begins_with("ECO! "), "focused panel confirms Echo's real damage")
	arena._spawn_training_add_wave()
	var add := arena.enemies[1]
	add.set_process(false)
	var add_id := add.get_instance_id()
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	arena.spiritualist_echo_state.mark(add_id, 0.50)
	boss.apply_damage(shield_request, arena.rng)
	add.apply_damage(_request(arena.player, add, &"basic_attack", 70.0), arena.rng)
	arena._sync_spiritualist_combat_state()
	_check(arena.spiritualist_echo_state.pending.size() == 2 and arena.battle_indicators.spiritualist_pending_remaining.has(boss_id) and arena.battle_indicators.spiritualist_pending_remaining.has(add_id), "two targets keep independent pending Echo countdowns")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	_check(arena.spiritualist_echo_state.pending.is_empty() and boss.is_alive() and add.is_alive(), "both pending Echoes resolve independently without lingering state")
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	boss.apply_damage(shield_request, arena.rng)
	boss.health.grant_shield(1000.0)
	var hits_before := _event_count(arena, &"echo_hit")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	_check(_event_count(arena, &"echo_hit") == hits_before and _has_label(arena, "ABSORVIDO"), "fully absorbed Echo never announces a successful impact")
	boss.health.clear_shield()

	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	var pending_count := arena.spiritualist_echo_state.pending.size()
	arena._on_spiritualist_dissipation_requested(boss.global_position, _request(arena.player, boss, &"spiritualist_dissipation", 110.0), 0.0, 0.0)
	_check(not arena.spiritualist_echo_state.has_mark(boss_id) and arena.spiritualist_echo_state.pending.size() == pending_count and _has_label(arena, "MARCA DISSIPADA"), "positive Rito consumes mark distinctly and schedules no Echo")
	boss.apply_weaken(0.15, 4.0, &"weaker_fixture")
	arena._sync_spiritualist_combat_state()
	arena._update_spiritualist_panel()
	_check(arena.spiritualist_state_label.text.contains("DANO CAUSADO −20%") and arena.battle_indicators.spiritualist_weakened.has(boss_id), "focused text and world icon use actual strongest damage-dealt debuff")
	boss.attribute_debuffs.advance(2.1)
	arena._sync_spiritualist_combat_state()
	arena._update_spiritualist_panel()
	_check(arena.spiritualist_state_label.text.contains("DANO CAUSADO −15%"), "focused debuff text falls back to surviving weaker source")
	arena._select_enemy(add)
	arena.spiritualist_echo_state.mark(add_id, 0.50)
	arena._process(5.01)
	_check(not arena.spiritualist_echo_state.has_mark(add_id) and _has_label(arena, "MALDIÇÃO EXPIROU") and _event_count(arena, &"expire") > 0, "focused mark expiry dissipates discreetly without an Echo hit")
	arena._select_enemy(boss)

	arena.player.health.current_hp = maxf(1.0, arena.player.health.max_hp - 50.0)
	var drain_request := _request(arena.player, boss, &"spiritualist_soul_drain", 120.0)
	arena._on_spiritualist_drain_requested(drain_request, boss)
	arena._cancel_spiritualist_drain()
	_check(arena.player.spiritualist_focus_remaining == 0.0, "zero-tick interruption grants no Focus")
	arena._on_spiritualist_drain_requested(drain_request, boss)
	arena._advance_spiritualist_drain(0.5)
	arena._update_spiritualist_panel()
	_check(arena.spiritualist_state_label.text.contains("CANALIZANDO 1/4") and _has_label(arena, " HP"), "channel segments follow resolved ticks and actual healing")
	arena._cancel_spiritualist_drain()
	arena._update_spiritualist_panel()
	_check(arena.spiritualist_state_label.text.contains("CANAL INTERROMPIDO") and arena.battle_indicators.spiritualist_drain_target_id == 0, "interruption clears link and briefly explains the cancel")
	arena._on_spiritualist_drain_requested(drain_request, boss)
	for index: int in range(3):
		arena._advance_spiritualist_drain(0.5)
	arena._cancel_spiritualist_drain()
	_check(arena.player.spiritualist_focus_remaining == 0.0, "three-tick interruption still grants no Focus")
	arena._on_spiritualist_drain_requested(drain_request, boss)
	for index: int in range(4):
		arena._advance_spiritualist_drain(0.5)
	arena._update_spiritualist_panel()
	_check(arena.player.spiritualist_focus_remaining > 0.0 and arena.spiritualist_state_label.text.contains("FOCO PRONTO"), "completed four-tick channel grants and displays a real Focus charge")
	_check(arena.player.consume_spiritualist_focus() > 0.0 and arena.battle_indicators.spiritualist_events[-1]["kind"] == &"focus_consume", "Focus consumption is shown only on real charge spend")
	_check(arena.player.grant_spiritualist_focus(), "equipped passive can grant another charge")
	arena.player.spiritualist_focus_remaining = 0.1
	arena.player._process(0.2)
	arena.battle_indicators.sync_spiritualist_focus(arena.player.get_instance_id(), arena.player.spiritualist_focus_remaining)
	_check(arena.player.spiritualist_focus_remaining == 0.0 and arena.battle_indicators.spiritualist_focus_caster_id == 0, "expired Focus clears player diamond and HUD state without consumption feedback")
	arena.player.run_state.build_snapshot.passive_slots.clear()
	_check(not arena.player.grant_spiritualist_focus(), "unequipped Focus passive cannot create a fake charge")

	arena.spiritualist_echo_state.clear()
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	arena._on_spiritualist_drain_requested(drain_request, boss)
	var expiry_before := _event_count(arena, &"expire")
	arena._process(0.5)
	_check(_event_count(arena, &"expire") == expiry_before and arena.spiritualist_echo_state.pending.size() == 1, "real frame: Drain converts mark to pending Echo without false expiration")
	arena._cancel_spiritualist_drain()
	arena.spiritualist_echo_state.clear()
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	var procession_request := _request(arena.player, boss, &"spiritualist_procession", 100.0)
	arena._on_spiritualist_procession_requested(procession_request, boss)
	expiry_before = _event_count(arena, &"expire")
	arena._process(0.5)
	_check(_event_count(arena, &"expire") == expiry_before and arena.spiritualist_echo_state.pending.size() == 1, "real frame: Procession converts mark to pending Echo without false expiration")
	arena._cancel_spiritualist_procession()
	var saved_snapshot := arena.player.run_state.build_snapshot
	arena.player.run_state.build_snapshot = null
	arena._sync_spiritualist_combat_state()
	_check(arena.player.run_state.build_snapshot == null, "snapshot-null sync is a safe no-op")
	arena.player.run_state.build_snapshot = saved_snapshot

	arena._show_result(false)
	_check(arena.battle_indicators.spiritualist_marks.is_empty() and arena.battle_indicators.spiritualist_pending_remaining.is_empty() and arena._spiritualist_feedback_labels.is_empty() and arena._spiritualist_recent_feedback.is_empty(), "run end clears world markers and finite feedback queue")
	paused = false
	arena.queue_free()
	current_scene = null
	await process_frame
	var previous_class := RunController.selected_class_id
	RunController.selected_class_id = &"mage"
	var pilot := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(pilot)
	current_scene = pilot
	await process_frame
	pilot._process(0.1)
	_check(pilot.spiritualist_panel == null and pilot.battle_indicators.spiritualist_marks.is_empty(), "non-persistent Mage pilot scene has no Spiritualist UI")
	pilot.run_state.build_snapshot = null
	pilot._sync_spiritualist_combat_state()
	_check(pilot.run_state.build_snapshot == null and pilot.battle_indicators.spiritualist_marks.is_empty(), "snapshot-null sync in pilot scene is a safe no-op")
	pilot.queue_free()
	current_scene = null
	RunController.selected_class_id = previous_class
	await process_frame
	print("E05 legibilidade Espiritualista: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _request(player: PlayerActor, target: CombatActor, skill_id: StringName, power: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.magic_damage = power
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _has_label(arena: RunController, fragment: String) -> bool:
	return _feedback_label(arena, fragment) != null

func _feedback_label(arena: RunController, fragment: String) -> Label:
	for child: Node in arena.get_children():
		if child is Label and (child as Label).text.contains(fragment):
			return child as Label
	return null

func _event_count(arena: RunController, kind: StringName) -> int:
	var count := 0
	for event: Dictionary in arena.battle_indicators.spiritualist_events:
		if event["kind"] == kind:
			count += 1
	return count

func _combat_lanes_unique(arena: RunController, actor: CombatActor) -> bool:
	var lanes: Array[int] = []
	for label: Label in arena._spiritualist_feedback_labels:
		if not is_instance_valid(label) or label.is_queued_for_deletion() or label.get_meta("actor_id", 0) != actor.get_instance_id():
			continue
		var lane := int(label.get_meta("lane", -1))
		if lane < 0 or lanes.has(lane):
			return false
		lanes.append(lane)
	return lanes.size() <= 3

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
