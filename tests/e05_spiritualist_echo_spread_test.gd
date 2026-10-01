extends SceneTree
## Real arena: finite wave identity, overlap, positive-only rearming and solo/group comparison.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var menu := CharacterMenu.new()
	var option := {"skill_id": &"spiritualist_echo_curse", "metadata": {"category": ProfileCatalog.ACTIVE, "wallet": ProfileCatalog.EVOLUTION_WALLET}, "rank": 1, "maximum_rank": 5, "next_rank": null}
	_check(menu._skill_progression_tooltip(option).contains("raio de 110") and menu._skill_progression_tooltip(option).contains("autoataque não ativa"), "curse tooltip describes AoE mark and skill-only trigger")
	option["skill_id"] = &"spiritualist_dissipation"
	_check(menu._skill_progression_tooltip(option).contains("também ativa uma onda"), "Rite tooltip reflects its new triggering rule")
	menu.free()
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "echo-spread-test"
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.base_level = 30
	snapshot.job_level = 40
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_dissipation": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", &"spiritualist_dissipation", null, null, null]
	RunController.pending_run_state = RunState.from_build("", snapshot)
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.set_process(false)
	var boss := arena.training_boss
	boss.set_process(false)
	boss.global_position = Vector2(1300, 450)
	arena.player.global_position = Vector2(1100, 450)
	arena.player.set_process(false)
	arena._spawn_training_add_wave()
	var adds: Array[CombatActor] = []
	for enemy: CombatActor in arena.enemies:
		if enemy != boss:
			adds.append(enemy)
	adds[0].global_position = Vector2(1360, 450)
	adds[1].global_position = Vector2(1250, 500)
	for add: CombatActor in adds:
		add.set_process(false)
	var state := arena.spiritualist_echo_state
	arena._on_spiritualist_echo_curse_requested(_request(arena, boss, &"spiritualist_echo_curse", 100.0, 1), boss, 0.35)
	_check(state.marks.size() == 3 and state.has_mark(boss.get_instance_id()) and state.has_mark(adds[0].get_instance_id()) and state.has_mark(adds[1].get_instance_id()), "curse marks target and both visible neighbors")
	_check(_count_event(arena, &"spread_link") == 2, "collective application has two spatial soul links")
	boss.apply_damage(_request(arena, boss, &"basic_attack", 100.0, 2), arena.rng)
	_check(state.pending.is_empty() and state.has_mark(boss.get_instance_id()), "autoattack leaves wave untriggered")
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 3), arena.rng)
	_check(state.pending.size() == 1 and not state.has_mark(boss.get_instance_id()), "first direct skill schedules one carrier")
	var wave_id := int(state.pending[0]["wave_id"])
	_check(state.advance(0.34).is_empty() and state.pending.size() == 1, "wave preserves 0.35s anticipation")
	var boss_hp_before_wave := boss.health.current_hp
	_resolve(arena, state.advance(0.02))
	_check(state.pending.size() == 2 and state.has_mark(boss.get_instance_id()), "first explosion re-arms survivor and schedules both premarked neighbors")
	_check(state.waves[wave_id]["pairs"].size() == 3 and not state.claim_pair(wave_id, boss.get_instance_id(), adds[0].get_instance_id()), "origin/destination pair is claimed before damage and cannot resolve twice")
	_check(_count_event(arena, &"spread_link") >= 4, "explosion travels to neighboring bodies")
	_resolve(arena, state.advance(0.36))
	state.finish_resolution()
	_check(state.pending.is_empty() and state.waves.is_empty() and state.wave_by_emission.is_empty(), "two neighboring carriers terminate the same wave without cycles")
	_check(state.marks.size() == 3, "all surviving bodies remain marked for a later player action")
	var group_boss_damage := boss_hp_before_wave - boss.health.current_hp
	_check(group_boss_damage > 0.0, "group wave damages boss through central resolver")
	var group_events := _count_event(arena, &"echo_hit")
	_check(group_events == 3, "three carriers emit three major impact ghosts; neighbor hits use lighter spatial links")
	for add: CombatActor in adds:
		add.global_position += Vector2(350, 0)
	state.clear()
	state.mark(boss.get_instance_id(), 0.35)
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 4), arena.rng)
	var solo_hp_before_wave := boss.health.current_hp
	_resolve(arena, state.advance(0.36))
	state.finish_resolution()
	var solo_boss_damage := solo_hp_before_wave - boss.health.current_hp
	_check(solo_boss_damage > 0.0 and group_boss_damage > solo_boss_damage, "fixed-power comparison: group propagation exceeds solo wave without changing coefficients")
	print("Comparativo Eco controlado: boss solo %.0f HP/1 explosão; boss com 2 vizinhos %.0f HP/3 explosões (janela 0,72 s)" % [solo_boss_damage, group_boss_damage])
	_check(state.has_mark(boss.get_instance_id()) and state.pending.is_empty(), "solo boss also rearms without self-loop")
	state.clear()
	state.mark(boss.get_instance_id(), 0.35)
	state.mark(adds[0].get_instance_id(), 0.35)
	boss.apply_damage(_request(arena, boss, &"spiritualist_dissipation", 100.0, 20), arena.rng)
	state.mark(adds[1].get_instance_id(), 0.35)
	adds[0].apply_damage(_request(arena, adds[0], &"spiritualist_dissipation", 100.0, 20), arena.rng)
	adds[1].apply_damage(_request(arena, adds[1], &"spiritualist_dissipation", 100.0, 20), arena.rng)
	_check(state.pending.size() == 2 and int(state.pending[0]["wave_id"]) == int(state.pending[1]["wave_id"]) and state.waves.size() == 1, "same AoE emission shares one wave; mark created after first impact cannot enter it")
	state.clear()
	adds[0].global_position = Vector2(790, 270)
	adds[1].global_position = Vector2(1600, 450)
	boss.global_position = Vector2(840, 350)
	_check(boss.global_position.distance_to(adds[0].global_position) < SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS and not arena.navigation.is_segment_clear(boss.global_position, adds[0].global_position, 0.0), "nearby target can be excluded by obstacle LoS")
	arena._on_spiritualist_echo_curse_requested(_request(arena, boss, &"spiritualist_echo_curse", 100.0, 21), boss, 0.35)
	_check(state.has_mark(boss.get_instance_id()) and not state.has_mark(adds[0].get_instance_id()), "initial collective mark respects shared LoS")
	state.clear()
	state.mark(boss.get_instance_id(), 0.35)
	state.mark(adds[0].get_instance_id(), 0.35)
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 25), arena.rng)
	var blocked_hp := adds[0].health.current_hp
	_resolve(arena, state.advance(0.36))
	_check(adds[0].health.current_hp == blocked_hp and state.pending.is_empty() and state.has_mark(adds[0].get_instance_id()), "LoS is rechecked at explosion; blocked marked neighbor neither takes damage nor transmits")
	state.clear()
	boss.global_position = Vector2(1300, 450)
	adds[0].global_position = Vector2(1360, 450)
	state.mark(boss.get_instance_id(), 0.35)
	state.mark(adds[0].get_instance_id(), 0.35)
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 26), arena.rng)
	adds[0].global_position = Vector2(1600, 450)
	var escaped_hp := adds[0].health.current_hp
	_resolve(arena, state.advance(0.36))
	_check(adds[0].health.current_hp == escaped_hp and state.pending.is_empty(), "moving outside radius before resolution prevents a stale chained explosion")
	state.clear()
	adds[0].global_position = Vector2(1600, 450)
	state.mark(boss.get_instance_id(), 0.35)
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 22), arena.rng)
	adds[0].global_position = Vector2(1360, 450)
	_resolve(arena, state.advance(0.36))
	_check(state.has_mark(adds[0].get_instance_id()) and state.pending.is_empty(), "clean enemy entering radius before impact is marked but does not transmit in same wave")
	state.clear()
	arena._on_spiritualist_echo_curse_requested(_request(arena, boss, &"spiritualist_echo_curse", 100.0, 27), boss, 0.35)
	_check(state.has_mark(boss.get_instance_id()) and state.pending.is_empty(), "first curse applies its own mark without self-triggering")
	arena._on_spiritualist_echo_curse_requested(_request(arena, boss, &"spiritualist_echo_curse", 100.0, 28), boss, 0.35)
	_check(state.has_mark(boss.get_instance_id()) and state.pending.size() == 1, "reapplying curse activates the previous mark and installs a fresh one")
	state.clear()
	state.mark(boss.get_instance_id(), 0.35)
	boss.health.grant_shield(1000.0)
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 5), arena.rng)
	_check(state.has_mark(boss.get_instance_id()) and state.pending.is_empty(), "fully absorbed skill cannot start a wave")
	boss.health.clear_shield()
	arena._on_spiritualist_dissipation_requested(boss.global_position, _request(arena, boss, &"spiritualist_dissipation", 100.0, 6), 35.0, 0.0)
	_check(state.pending.size() == 1 and not state.has_mark(boss.get_instance_id()), "Rite receives marked bonus and schedules Echo instead of discarding mark")
	var before_rite_echo := boss.health.current_hp
	_resolve(arena, state.advance(0.36))
	_check(boss.health.current_hp < before_rite_echo, "Rite wave resolves real damage")
	state.clear()
	arena._spawn_training_add_wave()
	arena._spawn_training_add_wave()
	while arena.enemies.size() < 7:
		var extra := arena._spawn_enemy(&"archer", Vector2(1500, 450))
		extra.health.max_hp = RunController.TRAINING_ADD_HP
		extra.health.current_hp = RunController.TRAINING_ADD_HP
	var all_adds: Array[CombatActor] = []
	for enemy: CombatActor in arena.enemies:
		if enemy != boss:
			all_adds.append(enemy)
	var offsets := [Vector2(-80, -50), Vector2(0, -90), Vector2(80, -50), Vector2(-80, 50), Vector2(0, 90), Vector2(80, 50)]
	for index: int in range(all_adds.size()):
		all_adds[index].set_process(false)
		all_adds[index].global_position = boss.global_position + offsets[index]
	arena._on_spiritualist_echo_curse_requested(_request(arena, boss, &"spiritualist_echo_curse", 100.0, 23), boss, 0.35)
	_check(all_adds.size() == 6 and state.marks.size() == 7, "six adds and boss receive one initial area application (adds=%d marks=%d)" % [all_adds.size(), state.marks.size()])
	boss.apply_damage(_request(arena, boss, &"soul_impact", 100.0, 24), arena.rng)
	var dense_wave_id := int(state.pending[0]["wave_id"])
	var dense_steps := 0
	while not state.pending.is_empty() and dense_steps < 10:
		_resolve(arena, state.advance(0.36))
		dense_steps += 1
	var dense_scheduled := int(state.waves[dense_wave_id]["scheduled"].size())
	state.finish_resolution()
	_check(dense_steps == 2 and dense_scheduled == 7 and state.pending.is_empty(), "seven carriers explode once each across two finite delayed generations (steps=%d scheduled=%d pending=%d)" % [dense_steps, dense_scheduled, state.pending.size()])
	_check(arena.battle_indicators.spiritualist_events.size() <= BattleIndicators.SPIRITUALIST_MAX_EVENTS, "dense-wave VFX queue remains capped")
	state.clear()
	all_adds[3].health.current_hp = 1.0
	all_adds[3].health.grant_shield(100000.0)
	arena._on_spiritualist_echo_curse_requested(_request(arena, all_adds[3], &"spiritualist_echo_curse", 10000.0, 998), all_adds[3], 0.35)
	_check(not state.has_mark(boss.get_instance_id()) and state.pending.is_empty(), "fully shielded initial Curse cannot mark its living neighbors")
	all_adds[3].health.clear_shield()
	all_adds[0].health.current_hp = 1.0
	arena._on_spiritualist_echo_curse_requested(_request(arena, all_adds[0], &"spiritualist_echo_curse", 10000.0, 999), all_adds[0], 0.35)
	_check(not all_adds[0].is_alive() and state.has_mark(boss.get_instance_id()) and not state.has_mark(all_adds[0].get_instance_id()), "lethal initial Curse still binds surviving neighbors, never the corpse")
	state.clear()
	state.mark(all_adds[1].get_instance_id(), 0.35)
	all_adds[1].apply_damage(_request(arena, all_adds[1], &"soul_impact", 10.0, 1000), arena.rng)
	_check(state.pending.size() == 1, "living add schedules delayed carrier")
	all_adds[1].apply_damage(_request(arena, all_adds[1], &"basic_attack", 10000.0, 1001), arena.rng)
	state.finish_resolution()
	_check(not all_adds[1].is_alive() and state.pending.is_empty() and state.waves.is_empty(), "carrier killed before delay cancels its pending wave and identity")
	state.clear()
	state.mark(all_adds[2].get_instance_id(), 0.35)
	state.mark(boss.get_instance_id(), 0.35)
	all_adds[2].apply_damage(_request(arena, all_adds[2], &"soul_impact", 10.0, 1002), arena.rng)
	all_adds[2].health.current_hp = 1.0
	_resolve(arena, state.advance(0.36))
	_check(not all_adds[2].is_alive() and state.pending.size() == 1 and not state.has_mark(all_adds[2].get_instance_id()), "carrier death during explosion clears corpse but still reaches living marked neighbor")
	_resolve(arena, state.advance(0.36))
	state.finish_resolution()
	_check(state.pending.is_empty() and state.waves.is_empty(), "wave completes and cleans up after carrier death during resolution")
	state.clear()
	_check(state.waves.is_empty() and state.pending.is_empty(), "run cleanup clears wave identities and queued carriers")
	arena.queue_free()
	current_scene = null
	await process_frame
	print("E05 Espiritualista propagação: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _request(arena: RunController, target: CombatActor, skill_id: StringName, power: float, emission: int) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.skill_id = skill_id
	request.emission_id = emission
	request.magic_damage = power
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _resolve(arena: RunController, due: Array[Dictionary]) -> void:
	for echo: Dictionary in due:
		arena._apply_spiritualist_echo(echo)

func _count_event(arena: RunController, kind: StringName) -> int:
	var count := 0
	for event: Dictionary in arena.battle_indicators.spiritualist_events:
		if event["kind"] == kind:
			count += 1
	return count

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
