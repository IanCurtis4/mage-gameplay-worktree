extends SceneTree
## S7 complete legal production builds. Explicit fixture timings are not DPS/FPS qualification.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174217"
const LABELS: Array[String] = ["entry", "critical", "caster"]
const BASE_PURCHASES := {&"double_shot": 5, &"piercing_arrow": 5, &"arrow_rain": 5, &"archer_precision": 3, &"archer_cadence": 1}
var checks := 0
var failures := 0
var directory: String
var metrics: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_sentinel_integration")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	_check(ProfileCatalog.pilot().evolution_is_ready(&"sentinel", &"archer"), "complete Sentinel uses default production catalog readiness")
	_production_entry()
	var critical := _legal_character("critical", {&"sentinel_headshot": 4, &"sentinel_observe": 3, &"sentinel_piercing_shot": 5, &"sentinel_concussion_shot": 1, &"sentinel_absolute_focus": 1, &"sentinel_precision_stance": 3, &"sentinel_opening_read": 3}, [&"sentinel_headshot", &"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_concussion_shot", &"sentinel_absolute_focus"], {&"dex": 45, &"agi": 27, &"luk": 15})
	var caster := _legal_character("caster", {&"sentinel_observe": 1, &"sentinel_piercing_shot": 5, &"sentinel_net_shot": 5, &"sentinel_explosive_shot": 5, &"sentinel_absolute_focus": 1, &"sentinel_precision_stance": 1, &"sentinel_opening_read": 2}, [&"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_absolute_focus"], {&"int": 45, &"dex": 27, &"luk": 15})
	for label: String in ["critical", "caster"]:
		var character := critical if label == "critical" else caster
		var facade := _saved_facade(label, character)
		for dense: bool in [false, true]:
			await _combat(label, facade, dense)
	print("Sentinel S7 observed per-use fixtures (not DPS/FPS): " + JSON.stringify(metrics))
	_cleanup()
	print("Sentinel S7 integrated: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _profile(character: CharacterState) -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	return profile

func _saved_facade(label: String, character: CharacterState) -> ProfileFacade:
	var catalog := ProfileCatalog.pilot()
	var path := directory.path_join(label)
	_check(ProfileStore.new(path, catalog).commit(_profile(character))["ok"], "%s valid build saved only in verification folder" % label)
	var facade := ProfileFacade.new(ProfileStore.new(path, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile()["ok"], "%s actual durable profile opens" % label)
	return facade

func _production_entry() -> void:
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Sentinela de entrada", &"archer")
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	var facade := _saved_facade("entry", character)
	var before_base := character.base_xp_total
	var before_job := character.job_xp_total
	var id := character.character_id
	_check(facade.change_evolution("s7-production-entry", facade.current_profile().revision, id, &"sentinel")["ok"], "default production Archer base10/job20 evolves normally")
	var durable := facade.current_profile().character_by_id(id)
	var summary := facade.progression_summary(id)
	_check(durable.base_class_id == &"archer" and durable.evolution_id == &"sentinel" and durable.base_xp_total == before_base and durable.job_xp_total == before_job, "entry fixes Archer origin and preserves earned XP")
	_check(summary["effective_skill_ranks"] == {&"sentinel_headshot": 1} and summary["evolution_skill_points_available"] == 0 and durable.presets[0]["active_slots"] == [null, null, null, null, null], "entry HeadshotR1 free but not autoequipped or paid points")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory.path_join("entry"), ProfileCatalog.pilot()), ProfileRewardResolver.pilot_progression())
	_check(reloaded.open_profile()["ok"] and reloaded.current_profile().character_by_id(id).evolution_id == &"sentinel" and reloaded.progression_summary(id)["effective_skill_ranks"] == {&"sentinel_headshot": 1}, "production identity/free rank survive isolated durable reload")

func _legal_character(label: String, evolution: Dictionary, active: Array[Variant], allocations: Dictionary) -> CharacterState:
	var catalog := ProfileCatalog.pilot()
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Sentinela " + label, &"archer")
	character.evolution_id = &"sentinel"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	var purchases := BASE_PURCHASES.duplicate(true)
	purchases.merge(evolution)
	for skill: StringName in purchases:
		for index: int in int(purchases[skill]):
			_check(CharacterProgression.learn_skill(character, catalog, skill)["ok"], "%s legal purchase %s#%d" % [label, skill, index + 1])
	_check(CharacterProgression.allocate_attributes(character, allocations)["ok"], "%s actual equal87 attribute budget allocated" % label)
	var summary := CharacterProgression.summary(character, catalog)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20 and summary["attribute_points_spent"] == 87 and summary["base_skill_points_available"] == 0 and summary["evolution_skill_points_available"] == 0, "%s exact independent19/20/87 legal wallets" % label)
	character.presets[0]["active_slots"] = active
	character.presets[0]["passive_slots"] = [&"sentinel_precision_stance", &"sentinel_opening_read"]
	character.presets[0]["equipped"] = {&"weapon": null, &"armor": null, &"accessory": null}
	_check(active.size() == 5 and character.presets[0]["passive_slots"].size() == 2 and catalog.effective_skill_ranks(&"archer", &"sentinel", character.purchased_skill_ranks, {}).has(&"sentinel_headshot"), "%s kit uses5+2 slots with free Head retained in library" % label)
	return character

func _freeze(arena: RunController) -> void:
	arena.set_process(false)
	arena.player.set_process(false)
	for actor: CombatActor in arena.enemies:
		actor.set_process(false)
	for node: Node in get_nodes_in_group("player_projectiles"):
		node.set_process(false)

func _flush() -> void:
	for node: Node in get_nodes_in_group("player_projectiles"):
		node.set_process(false)
		for _step: int in 120:
			if not node.is_queued_for_deletion():
				node._process(1.0 / 60.0)
	await process_frame

func _combat(label: String, facade: ProfileFacade, dense: bool) -> void:
	var character_id := facade.current_profile().selected_character_id
	var before_disk := FileAccess.get_file_as_string(directory.path_join(label).path_join("profile.json"))
	var revision := facade.current_profile().revision
	var training := facade.prepare_playtest_training(character_id)
	_check(training["ok"] and training["run_state"].run_id.is_empty() and facade.current_profile().reward_session == null and facade.current_profile().revision == revision, "%s training uses saved build without XP/reward session" % label)
	if not training["ok"]:
		return
	RunController.pending_run_state = training["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	_freeze(arena)
	arena._training_add_elapsed = -1000.0
	arena.rng.seed = 42517
	arena.cast_intent.set_mode(CastIntent.Mode.CONFIRM)
	arena._process(0.0) # Synchronize the canonical encounter flag into the actor.
	arena.navigation.configure(Rect2(0, 0, 1500, 1000), [], 20.0)
	arena.player.position = Vector2(200, 350)
	arena.training_boss.position = Vector2(450, 350)
	if dense:
		for index: int in 19:
			var actor := arena._spawn_enemy(&"archer" if index % 4 == 0 else &"chaser", Vector2(380 + index % 5 * 38, 450 + index / 5 * 38))
			actor.health.max_hp = 10000.0
			actor.health.current_hp = 10000.0
			actor.set_process(false)
	_check(arena.training_mode and arena.encounter_active and arena.training_boss.hard_controls.boss and arena.enemies.size() == (20 if dense else 1), "%s %s uses real boss and <=20 total enemies" % [label, "dense" if dense else "solo"])
	var player := arena.player
	_check(player.character_animation.actor_kind == &"sentinel" and player.character_animation.atlas != null and player.character_animation.atlas.resource_path.ends_with("/sentinel.png"), "actual identity selects own Sentinel atlas, not base Archer")
	var guide: Variant = arena.get("sentinel_onboarding")
	_check(guide != null and guide.visible and not arena.help_panel.visible, "real Sentinel guide replaces generic help without extra panel")
	if guide != null:
		var before := [player.current_sp, player.sentinel_state.focus, arena.cast_intent.active_skill]
		guide.toggle_button.pressed.emit()
		_check(guide.help_label.visible and before == [player.current_sp, player.sentinel_state.focus, arena.cast_intent.active_skill] and not paused, "guide opens without consuming resources, canceling aim, or pausing")
	_check(player.available_skill_ids() == training["run_state"].build_snapshot.learned_skill_ids(ProfileCatalog.ACTIVE) and player.available_skill_ids().size() > 5 and arena.action_slots.size() == 24, "all legally learned actives enter dispatcher independently of24 shortcut layout")
	arena._update_hud()
	_check(not arena.skill_label.visible and arena.sentinel_focus_bar.visible, "Sentinel HUD has one Focus meter without duplicate skill list")
	for skill: StringName in arena.battle_controls.skill_buttons:
		var card: Button = arena.battle_controls.skill_buttons[skill]
		_check(card.text.split("\n").size() >= 2 and card.tooltip_text.contains("SP") and card.tooltip_text.contains("Foco"), "compact shortcut names/state retain full SP/Focus cost in tooltip")
	# No invented resource grant: a measured stationary window generates60 Focus.
	player._process(0.01) # Observe fixture reposition as effective movement.
	player._process(6.5)
	_close(player.sentinel_state.focus, 60.0, "real6.5s stationary combat window generates60Focus")
	_check(player._sentinel_stance_active and player.stat_breakdown.sources().filter(func(source: Dictionary) -> bool: return source["source_id"] == &"sentinel_precision_stance").size() == 1, "equipped posture enters canonical stats exactly once")
	var events: Array[Dictionary] = []
	for actor: CombatActor in arena.enemies:
		actor.health.damage_applied.connect(func(result: Dictionary) -> void: events.append(result.duplicate()))
	var order: Array = [&"sentinel_observe", &"sentinel_absolute_focus", &"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_concussion_shot"] if label == "critical" else [&"sentinel_observe", &"sentinel_net_shot", &"sentinel_piercing_shot", &"sentinel_explosive_shot", &"sentinel_absolute_focus"]
	for skill: StringName in order:
		var sp := player.current_sp
		var focus := player.sentinel_state.focus
		var marker := events.size()
		var point := arena.training_boss.position + PlayerProjectile.BODY_OFFSET
		if skill == &"sentinel_net_shot":
			point = arena.training_boss.position
		elif skill == &"sentinel_piercing_shot":
			point = arena.enemies[1].global_position if dense else arena.training_boss.position
		arena._commit_skill(skill, point)
		if player.has_active_cast():
			player._process(player.active_cast_remaining + 0.001)
		if skill == &"sentinel_explosive_shot":
			_check(player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 25.0 and player.skill_cooldown(skill) == 0.0, "real caster command reserves ammunition without reset/CD")
			var reserved := [player.sentinel_state.reserved_focus, player.sentinel_state.reserved_sp, player.sentinel_state.focus, player.current_sp]
			arena._toggle_settings(true)
			player._process(5.0)
			_check(paused and reserved == [player.sentinel_state.reserved_focus, player.sentinel_state.reserved_sp, player.sentinel_state.focus, player.current_sp] and player.sentinel_state.explosive_prepared, "actual settings button pauses without canceling or decaying prepared reservation")
			arena._toggle_settings(false)
			arena._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			_check(player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 25.0, "window focus-out does not silently erase prepared ammunition")
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			arena._input(escape)
			_check(not player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.reserved_sp == 0.0 and not paused and not arena.battle_controls.settings_overlay.visible, "first Esc releases reservation without opening settings or spending")
			arena._commit_skill(skill, point)
			_check(player.sentinel_state.explosive_prepared and player.current_sp == sp, "reprepare after cancel reserves exactly once without charging")
			var before_move := player.sentinel_state.focus
			player.move_to(Vector2(250, 370))
			player._process(0.1)
			_close(player.sentinel_state.focus, before_move, "movement window preserves prepared Focus without passive generation")
			_check(player.sentinel_state.explosive_prepared and not player._sentinel_stance_active, "walking preserves ammunition but immediately removes posture")
			player.pursue(arena.training_boss)
			await process_frame
			await process_frame
			player._process(player.attack_cooldown + 0.001)
			_check(not player.sentinel_state.explosive_prepared and player.sentinel_state.reserved_sp == 0.0, "ordinary auto consumes prepared shot exactly once")
			player.target = null
			player.velocity = Vector2.ZERO
			player._path.clear()
			player._has_path_goal = false
		var projectiles := get_nodes_in_group("player_projectiles")
		if skill in [&"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_concussion_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
			_check(projectiles.size() == 1, "one equipped offensive command spawns one projectile")
		_check(player.skill_cooldown(skill) > 0.0, "%s actual launch captures its CD" % skill)
		var committed_cd := player.skill_cooldown(skill)
		await _flush()
		var damage := 0.0
		var landed := 0
		var unique: Dictionary[int, bool] = {}
		for index: int in range(marker, events.size()):
			var event := events[index]
			if StringName(event.get("skill_id", &"")) == skill:
				_check(not unique.has(int(event["target_id"])), "one action resolves each victim once")
				unique[int(event["target_id"])] = true
				landed += 1 if bool(event.get("landed", false)) else 0
				damage += float(event.get("actual_damage", 0.0))
		if skill not in [&"sentinel_observe", &"sentinel_absolute_focus"]:
			_check(damage > 0.0 or (skill in [&"sentinel_headshot", &"sentinel_concussion_shot"] and unique.size() == 1 and landed == 0), "%s resolves real HP damage or a canonical contested miss in legal%s build" % [skill, label])
			if damage == 0.0 and skill == &"sentinel_concussion_shot":
				_check(not arena.training_boss.is_stunned(), "legitimate Concussion miss cannot apply support control")
		metrics.append({"build": label, "actors": arena.enemies.size(), "skill": String(skill), "actual_hp_damage": damage, "cd_captured_s": committed_cd, "sp_net_change": sp - player.current_sp, "focus_net_change": focus - player.sentinel_state.focus, "victims": unique.size(), "landed": landed})
		_check(player.current_sp >= 0.0 and player.sentinel_state.focus >= 0.0 and player.sentinel_state.focus <= 100.0, "integrated launch/procs never overdraw or overflow resources")
		if skill == &"sentinel_observe":
			_check(player.sentinel_state.observed_target_id == arena.training_boss.get_instance_id() and player.sentinel_state.observation_charges == 3, "smart-lock Observe attaches one3charge mark without damage")
	if label == "caster":
		player._process(player.skill_cooldown(&"sentinel_net_shot") + 0.001)
		var blocked := Vector2(300, 350)
		arena.navigation.configure(Rect2(0, 0, 1500, 1000), [Rect2(280, 330, 40, 40)], 20.0)
		arena.cast_intent.press(&"sentinel_net_shot")
		arena._update_aim(blocked)
		_check(arena.battle_controls.aim_label.text.contains("POSIÇÃO BLOQUEADA"), "real Net preview reports obstructed placement before charging")
		arena.battle_indicators.show_aim(&"sentinel_net_shot", player, blocked, false)
		_check(not arena.battle_indicators.available and arena.battle_indicators.endpoint == player.sentinel_net_center(blocked), "blocked preview shows actual clamped Net endpoint and state")
		arena._cancel_aim()
		arena.navigation.configure(Rect2(0, 0, 1500, 1000), [], 20.0)
	if dense:
		await _dense_proc_and_vfx(arena, label)
	# End-of-combat invariant independent of available skills and hostile population.
	player.target = null
	player.velocity = Vector2.ZERO
	player._path.clear()
	player._has_path_goal = false
	var prior_focus := player.sentinel_state.focus
	player.position += Vector2(1, 0)
	player._process(0.01)
	_check(not player._sentinel_stance_active and player.sentinel_state.focus == prior_focus, "external reposition removes posture but does not erase stored Focus")
	player.apply_stun(0.5)
	var prior_sp := player.current_sp
	var prior_cd := player.skill_cooldown(&"sentinel_piercing_shot")
	arena._commit_skill(&"sentinel_piercing_shot", arena.training_boss.position)
	_check(get_nodes_in_group("player_projectiles").is_empty() and player.current_sp == prior_sp and player.skill_cooldown(&"sentinel_piercing_shot") == prior_cd, "hard control blocks offensive transaction without spending")
	var clock := [player.sentinel_state.focus, player.sentinel_state.absolute_remaining, player.sentinel_state.observation_remaining, player.skill_cooldown(&"sentinel_observe")]
	paused = true
	player._process(5.0)
	_check(clock == [player.sentinel_state.focus, player.sentinel_state.absolute_remaining, player.sentinel_state.observation_remaining, player.skill_cooldown(&"sentinel_observe")], "dense real player pause freezes all resource/buff/CD/mark clocks")
	paused = false
	arena._show_result(false)
	_check(player.sentinel_state.focus == 0.0 and player.sentinel_state.observed_target_id == 0 and player.sentinel_state.absolute_remaining == 0.0 and player.sentinel_state.reserved_focus == 0.0 and player.sentinel_state.reserved_sp == 0.0, "terminal result synchronously clears every Sentinel run resource")
	_check(facade.current_profile().revision == revision and facade.current_profile().reward_session == null and FileAccess.get_file_as_string(directory.path_join(label).path_join("profile.json")) == before_disk, "actual training death/result cannot mutate saved profile/XP")
	arena._restart_run()
	await scene_changed
	await process_frame
	var restarted := current_scene as RunController
	_check(restarted != null and restarted.training_mode and restarted.player.is_sentinel() and restarted.player.sentinel_state.focus == 0.0 and restarted.player.sentinel_state.observed_target_id == 0 and not restarted.player.sentinel_state.explosive_prepared, "actual restart starts same saved training build with clean run-only state")
	if restarted != null:
		_freeze(restarted)
		_check(get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "restart carries no projectile/burst orphans")
		restarted.queue_free()
	await process_frame
	current_scene = null

func _dense_proc_and_vfx(arena: RunController, label: String) -> void:
	var player := arena.player
	player.sentinel_state.clear_observation()
	player.sentinel_state.advance(1.0, true, true) # Release shared ICD without generating Focus.
	if player.sentinel_state.focus > 90.0:
		player.sentinel_state.spend(30.0) # Make proc headroom explicit in saturation fixture.
	var prior := player.sentinel_state.focus
	var expected_gain := float(player.skill_rank(&"sentinel_opening_read") + 1) + 4.0
	var skill := &"sentinel_concussion_shot" if label == "critical" else &"sentinel_net_shot"
	for index: int in 20:
		arena._show_sentinel_visual(skill, Vector2(450, 350), 20.0)
	var cosmetics := arena.get_children().filter(func(node: Node) -> bool: return node is SentinelBurst and not node.is_queued_for_deletion())
	_check(cosmetics.size() == 12, "twenty requested reactions retain at most12 active cosmetic bursts")
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.skill_id = skill
	request.emission_id = 999
	request.physical_damage = 10.0 if label == "critical" else 0.0
	request.magic_damage = 10.0 if label == "caster" else 0.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = true
	request.force_critical = true # Proc saturation fixture, not launch/runtime crit policy.
	var hp: Array[float] = []
	for actor: CombatActor in arena.enemies:
		actor.position = Vector2(450, 350)
		actor.hard_controls.clear()
		hp.append(actor.health.current_hp)
	if label == "caster":
		arena._on_sentinel_burst(Vector2(450, 350), request, SentinelTuning.values(skill, player.skill_rank(skill)))
	else:
		for actor: CombatActor in arena.enemies:
			request.target_id = actor.get_instance_id()
			arena._on_sentinel_direct_hit(request.copy(), actor, SentinelTuning.values(skill, player.skill_rank(skill)))
	for index: int in arena.enemies.size():
		var actor := arena.enemies[index]
		_check(actor.health.current_hp < hp[index] and (actor.is_rooted() if label == "caster" else actor.is_stunned()), "cosmetic cap cannot suppress any of20 real direct impacts or controls")
	_close(player.sentinel_state.focus - prior, minf(expected_gain, 100.0 - prior), "twenty victims pay one intrinsic gain and one shared OpeningRead proc")
	cosmetics = arena.get_children().filter(func(node: Node) -> bool: return node is SentinelBurst and not node.is_queued_for_deletion())
	_check(cosmetics.size() == 12, "real gameplay processing does not breach cosmetic cap")
	var forged := {"source_id": 9999999, "target_id": arena.training_boss.get_instance_id(), "emission_id": 1000, "actual_damage": 1.0, "can_trigger_effects": true, "critical": true}
	player.sentinel_state.advance(1.0, true, true)
	var before := player.sentinel_state.focus
	player.record_sentinel_damage(forged)
	_check(player.sentinel_state.focus == before, "foreign-source positive hit cannot recover Sentinel resource")

func _cleanup() -> void:
	assert(directory == ProjectSettings.globalize_path("res://.godot/verification/e05_sentinel_integration"))
	for label: String in LABELS:
		var path := directory.path_join(label)
		if DirAccess.dir_exists_absolute(path):
			for file: String in DirAccess.get_files_at(path):
				DirAccess.remove_absolute(path.path_join(file))
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel S7: " + label)
