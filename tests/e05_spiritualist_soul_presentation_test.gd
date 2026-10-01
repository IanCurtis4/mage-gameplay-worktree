extends SceneTree
## Visual state is sampled from real combat results, not from UI messages.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "soul-presentation"
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
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	await process_frame
	var boss := arena.training_boss
	boss.set_process(false)
	var boss_id := boss.get_instance_id()
	arena.player.global_position = boss.global_position + Vector2(-80, 0)
	arena._select_enemy(boss)
	arena.combat_numbers_visible = false
	_check(not arena.spiritualist_panel.visible and not arena.spiritualist_debug_text and arena.battle_indicators.z_index > boss.z_index, "soul presentation is above actors while optional explanation stays hidden")
	_check(arena.spiritualist_ground != null and arena.arena_view.z_index < arena.spiritualist_ground.z_index and arena.spiritualist_ground.z_index < boss.z_index and arena.spiritualist_ground.indicators == arena.battle_indicators, "ground halos draw above the floor but below actor bodies; elevated souls keep their own layer")
	var labels_before := _world_label_count(arena)
	arena._on_spiritualist_echo_curse_requested(_request(arena, boss, &"spiritualist_echo_curse", 110.0), boss, 0.50)
	arena._sync_spiritualist_combat_state()
	_check(arena.spiritualist_echo_state.has_mark(boss_id) and arena.battle_indicators.spiritualist_marks.has(boss_id) and _world_label_count(arena) == labels_before, "actual curse binds souls without floating status text")
	var torso_before := arena.battle_indicators._spiritualist_torso(boss)
	boss.global_position += Vector2(55, 0)
	_check(arena.battle_indicators._spiritualist_torso(boss).distance_to(torso_before + Vector2(55, 0)) < 0.01, "bound souls follow a moving boss and scaled torso")
	boss.global_position -= Vector2(55, 0)
	var direct := _request(arena, boss, &"soul_impact", 100.0)
	boss.health.grant_shield(1000.0)
	boss.apply_damage(direct, arena.rng)
	_check(arena.spiritualist_echo_state.has_mark(boss_id) and arena.spiritualist_echo_state.pending.is_empty(), "fully absorbed trigger keeps the bound souls")
	boss.health.clear_shield()
	boss.apply_damage(direct, arena.rng)
	arena._sync_spiritualist_combat_state()
	_check(not arena.spiritualist_echo_state.has_mark(boss_id) and arena.battle_indicators.spiritualist_pending_remaining.has(boss_id), "direct damage changes bound souls to converging pending state")
	var pending_before: float = arena.battle_indicators.spiritualist_pending_remaining[boss_id]
	paused = true
	arena._process(0.2)
	arena.battle_indicators._process(0.2)
	_check(is_equal_approx(float(arena.battle_indicators.spiritualist_pending_remaining[boss_id]), pending_before), "pause freezes convergence and its clock")
	paused = false
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	var hit := _last_event(arena, &"echo_hit")
	_check(not hit.is_empty() and hit.has("actor_scale") and not hit.has("ghost_atlas"), "effective Echo uses a scaled local impact pulse without duplicating the target body")
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	boss.apply_damage(direct, arena.rng)
	boss.health.grant_shield(1000.0)
	var successful_before := _count_event(arena, &"echo_hit")
	for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36):
		arena._apply_spiritualist_echo(echo)
	_check(_count_event(arena, &"echo_hit") == successful_before and not _last_event(arena, &"echo_absorbed").is_empty(), "absorbed Echo has muffled event but no successful ghost/expulsion")
	boss.health.clear_shield()
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	var expires_before := _count_event(arena, &"expire")
	arena._process(5.01)
	_check(_count_event(arena, &"expire") == expires_before + 1 and arena.spiritualist_echo_state.pending.is_empty(), "natural mark expiry releases souls without impact")
	arena.spiritualist_echo_state.mark(boss_id, 0.50)
	var pending_count := arena.spiritualist_echo_state.pending.size()
	arena._on_spiritualist_dissipation_requested(boss.global_position, _request(arena, boss, &"spiritualist_dissipation", 110.0), 0.0, 0.0)
	_check(not _last_event(arena, &"break").is_empty() and arena.spiritualist_echo_state.pending.size() == pending_count + 1, "Rito tears bound souls outward and prepares a delayed Echo")
	var veil_center := boss.global_position
	arena._on_spiritualist_veil_requested(veil_center, 2.0, 0.15)
	_check(arena.battle_indicators.spiritualist_veil_members.has(boss_id) and _count_event(arena, &"veil_apply") == 1, "Véu entry creates one local soul and effective low-body weakness")
	arena._advance_spiritualist_veil(0.05)
	_check(_count_event(arena, &"veil_apply") == 1, "Véu refresh does not burst again every frame")
	boss.global_position = veil_center + Vector2(SpiritualistVeilState.RADIUS + 35.0, 0)
	arena._advance_spiritualist_veil(0.05)
	arena._sync_spiritualist_combat_state()
	_check(not arena.battle_indicators.spiritualist_veil_members.has(boss_id) and boss.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil") == 0.0, "Véu exit removes only its own debuff under existing gameplay rules")
	_check(arena.battle_indicators.spiritualist_weakened.has(boss_id), "Rito weakness remains embodied outside Véu while its real duration persists")
	boss.global_position = veil_center
	arena._advance_spiritualist_veil(0.05)
	_check(_count_event(arena, &"veil_apply") == 2, "real re-entry adds one local emergence")
	arena._advance_spiritualist_veil(2.1)
	_check(arena.battle_indicators.spiritualist_veil_members.is_empty(), "Véu end clears target membership")
	arena.player.health.current_hp = arena.player.health.max_hp - 50.0
	var drain := _request(arena, boss, &"spiritualist_soul_drain", 120.0)
	arena._on_spiritualist_drain_requested(drain, boss)
	arena._advance_spiritualist_drain(0.5)
	_check(not _last_event(arena, &"heal_receive").is_empty() and arena.battle_indicators.spiritualist_return_wisps.size() > 0, "resolved Drain damage sends soul back and only real HP gain adds reception")
	arena._cancel_spiritualist_drain()
	_check(arena.battle_indicators.spiritualist_drain_target_id == 0, "interrupted channel removes organic link without completion")
	arena.player.health.current_hp = arena.player.health.max_hp
	var heals_before := _count_event(arena, &"heal_receive")
	arena._on_spiritualist_drain_requested(drain, boss)
	arena._advance_spiritualist_drain(0.5)
	_check(_count_event(arena, &"heal_receive") == heals_before, "full HP suppresses false healing reception")
	arena._advance_spiritualist_drain(1.5)
	arena.battle_indicators.sync_spiritualist_focus(arena.player.get_instance_id(), arena.player.spiritualist_focus_remaining)
	_check(arena.player.spiritualist_focus_remaining > 0.0 and arena.battle_indicators.spiritualist_focus_caster_id == arena.player.get_instance_id(), "completed channel creates real shoulder companion")
	var consumes_before := _count_event(arena, &"focus_consume")
	arena.player.consume_spiritualist_focus()
	_check(_count_event(arena, &"focus_consume") == consumes_before + 1, "valid Focus spend draws convergence once")
	_check(arena.player.grant_spiritualist_focus(), "Focus can be charged again")
	arena.battle_indicators.sync_spiritualist_focus(arena.player.get_instance_id(), arena.player.spiritualist_focus_remaining)
	arena.player.spiritualist_focus_remaining = 0.0
	arena.battle_indicators._process(0.40)
	arena.battle_indicators.sync_spiritualist_focus(arena.player.get_instance_id(), 0.0)
	_check(not _last_event(arena, &"focus_expire").is_empty(), "unspent Focus fades instead of converging as a cast")
	for wave: int in range(3):
		arena._spawn_training_add_wave()
	var adds := 0
	for enemy: CombatActor in arena.enemies:
		if enemy == boss:
			continue
		enemy.set_process(false)
		arena.spiritualist_echo_state.mark(enemy.get_instance_id(), 0.50)
		enemy.apply_weaken(0.15, 2.0, &"dense_probe")
		adds += 1
	arena._sync_spiritualist_combat_state()
	_check(adds == 6 and arena.battle_indicators.spiritualist_marks.size() == 6 and arena.battle_indicators.spiritualist_weakened.size() >= 6, "six adds preserve independent bounded mark/weakness compositions")
	var clustered_ids: Array[int] = []
	var clustered_actors: Array[CombatActor] = []
	for enemy: CombatActor in arena.enemies:
		if enemy != boss:
			clustered_ids.append(enemy.get_instance_id())
			clustered_actors.append(enemy)
	for index: int in range(clustered_actors.size()):
		clustered_actors[index].global_position = Vector2(500.0 + float(index) * 55.0, 420.0)
	arena.battle_indicators.sync_spiritualist_marks(clustered_ids)
	arena.battle_indicators.spiritualist_pending_remaining.clear()
	_check(arena.battle_indicators.spiritualist_halo_groups().size() == 1, "overlapping marked halos share one elevated soul without changing the marked actors")
	clustered_actors[-1].global_position += Vector2(500.0, 0.0)
	_check(arena.battle_indicators.spiritualist_halo_groups().size() == 2, "a separated marked actor receives its own visible soul")
	arena.battle_indicators.spiritualist_pending_remaining[clustered_ids[0]] = SpiritualistEchoState.ECHO_DELAY
	_check(arena.battle_indicators.spiritualist_halo_groups().size() == 2, "pending Echo does not duplicate a marked actor in visual groups")
	for index: int in range(90):
		arena.battle_indicators.show_spiritualist_event(&"burst", boss.global_position)
	_check(arena.battle_indicators.spiritualist_events.size() == BattleIndicators.SPIRITUALIST_MAX_EVENTS, "transient soul-event queue stays capped in dense scenes")
	arena._show_result(false)
	_check(arena.battle_indicators.spiritualist_marks.is_empty() and arena.battle_indicators.spiritualist_veil_members.is_empty() and arena.battle_indicators.spiritualist_events.is_empty() and arena.battle_indicators.spiritualist_focus_caster_id == 0, "run end clears all persistent and transient soul references")
	arena.queue_free()
	current_scene = null
	await process_frame
	print("E05 almas Espiritualista: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _request(arena: RunController, target: CombatActor, skill_id: StringName, power: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.magic_damage = power
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _last_event(arena: RunController, kind: StringName) -> Dictionary:
	for index: int in range(arena.battle_indicators.spiritualist_events.size() - 1, -1, -1):
		var event: Dictionary = arena.battle_indicators.spiritualist_events[index]
		if event["kind"] == kind:
			return event
	return {}

func _count_event(arena: RunController, kind: StringName) -> int:
	var count := 0
	for event: Dictionary in arena.battle_indicators.spiritualist_events:
		if event["kind"] == kind:
			count += 1
	return count

func _world_label_count(arena: RunController) -> int:
	var count := 0
	for child: Node in arena.get_children():
		if child is Label:
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
