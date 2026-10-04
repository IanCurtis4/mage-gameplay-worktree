extends SceneTree
## Native renderer snapshots using legal class builds; no personal save or FPS claim.

var arena: RunController
var checks := 0
var failures := 0
var captures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for caster: bool in [false, true]:
		await _show_build(caster)
	print("Sentinel renderer: %d checks, %d captures, %d failures" % [checks, captures, failures])
	quit(1 if failures else 0)

func _build(caster: bool) -> BuildSnapshot:
	var catalog := ProfileCatalog.pilot()
	var character := CharacterState.new("sentinel-renderer", "Sentinela", &"archer")
	character.evolution_id = &"sentinel"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	var skills := {&"sentinel_observe": 1, &"sentinel_piercing_shot": 5, &"sentinel_net_shot": 5, &"sentinel_explosive_shot": 5, &"sentinel_absolute_focus": 1, &"sentinel_precision_stance": 1, &"sentinel_opening_read": 2} if caster else {&"sentinel_headshot": 4, &"sentinel_observe": 3, &"sentinel_piercing_shot": 5, &"sentinel_concussion_shot": 1, &"sentinel_absolute_focus": 1, &"sentinel_precision_stance": 3, &"sentinel_opening_read": 3}
	skills.merge({&"double_shot": 5, &"piercing_arrow": 5, &"arrow_rain": 5, &"archer_precision": 3, &"archer_cadence": 1})
	for skill: StringName in skills:
		for _purchase: int in int(skills[skill]):
			_check(CharacterProgression.learn_skill(character, catalog, skill)["ok"], "legal purchase " + String(skill))
	_check(CharacterProgression.allocate_attributes(character, {&"int": 45, &"dex": 27, &"luk": 15} if caster else {&"dex": 45, &"agi": 27, &"luk": 15})["ok"], "legal equal attribute allocation")
	character.presets[0]["active_slots"] = [&"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_absolute_focus"] if caster else [&"sentinel_headshot", &"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_concussion_shot", &"sentinel_absolute_focus"]
	character.presets[0]["passive_slots"] = [&"sentinel_precision_stance", &"sentinel_opening_read"]
	var summary := CharacterProgression.summary(character, catalog)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20, "equal legal wallets")
	return BuildSnapshot.from_character(character, summary["base_level"], summary["job_level"], summary["effective_skill_ranks"], catalog.skill_ids_for_identity(&"archer", &"sentinel"))

func _show_build(caster: bool) -> void:
	var prefix := "caster" if caster else "critical"
	RunController.pending_run_state = RunState.from_build("", _build(caster))
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena.player.position = Vector2(850, 450)
	arena.player.sentinel_combat_active = true
	arena.training_boss.set_process(false)
	arena.training_boss.position = Vector2(1000, 550)
	arena.training_boss.health.max_hp = 100000
	arena.training_boss.health.current_hp = 100000
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1800, 1000), [], 20.0)
	for child: Node in arena.player.get_children():
		if child is Camera2D: child.position_smoothing_enabled = false
	_check(arena.player.character_animation.actor_kind == &"sentinel" and arena.sentinel_onboarding != null, "own atlas and run guide wired")
	await _shot(prefix + "_solo")
	for index: int in 19:
		var actor := arena._spawn_enemy(&"archer" if index % 4 == 0 else &"chaser", Vector2(940 + index % 5 * 42, 470 + index / 5 * 42))
		actor.set_process(false)
		actor.health.max_hp = 10000
		actor.health.current_hp = 10000
	_check(arena.enemies.size() == 20, "dense boss +19 adds respects cap")
	var floor_sample := Polygon2D.new()
	floor_sample.polygon = PackedVector2Array([Vector2(680, 370), Vector2(1250, 370), Vector2(1250, 730), Vector2(680, 730)])
	floor_sample.z_index = -2
	arena.add_child(floor_sample)
	for dark: bool in [false, true]:
		var label := prefix + ("_dark" if dark else "_light")
		floor_sample.color = Color("142a34") if dark else Color("cdd3aa")
		arena.player.sentinel_state.gain(80.0)
		arena.player.mage_cooldowns[&"sentinel_observe"] = 0.0
		arena._execute_skill(&"sentinel_observe", arena.training_boss.position, arena.training_boss)
		arena.player.mage_cooldowns[&"sentinel_absolute_focus"] = 0.0
		arena._execute_skill(&"sentinel_absolute_focus", arena.player.position)
		for id: StringName in arena.player.available_skill_ids():
			if id in [&"sentinel_observe", &"sentinel_absolute_focus"]: continue
			arena.player.current_sp = arena.player.max_sp # Visual probe setup, not balance measurement.
			arena.player.sentinel_state.gain(80.0)
			arena.player.mage_cooldowns[id] = 0.0
			arena.battle_indicators.show_aim(id, arena.player, arena.training_boss.position, true, arena.training_boss)
			if id == &"sentinel_explosive_shot":
				_check(arena.player.prepare_sentinel_explosive(), "prepared ammunition visible")
				await _shot(label + "_reserved")
				_check(arena.player._launch_sentinel_explosive(arena.training_boss), "paid prepared launch")
			else:
				arena._execute_skill(id, arena.training_boss.position, arena.training_boss)
			var projectiles := get_nodes_in_group("player_projectiles")
			_check(projectiles.size() == 1, "one real projectile per visual action")
			for projectile: PlayerProjectile in projectiles:
				projectile.set_process(false)
				projectile._process(0.07)
			await _shot(label + "_" + String(id).trim_prefix("sentinel_"))
			arena.battle_indicators.clear_aim()
			for projectile: PlayerProjectile in projectiles:
				if is_instance_valid(projectile) and not projectile.is_queued_for_deletion(): projectile._process(1.0)
			for effect: Node in get_nodes_in_group("player_effects"):
				if effect is SentinelBurst: effect.set_process(false)
			await _shot(label + "_impact_" + String(id).trim_prefix("sentinel_"))
			for effect: Node in get_nodes_in_group("player_effects"):
				if effect is SentinelBurst: effect.queue_free()
			await process_frame
	arena.sentinel_onboarding.toggle_button.pressed.emit()
	await _shot(prefix + "_guide")
	arena.sentinel_onboarding.toggle_button.pressed.emit()
	arena._show_result(false)
	_check(arena.player.sentinel_state.focus == 0.0 and not arena.player.sentinel_state.explosive_prepared, "result clears resource/buff/reservation")
	paused = false
	arena.queue_free()
	await process_frame
	_check(get_nodes_in_group("player_projectiles").is_empty() and get_nodes_in_group("player_effects").is_empty(), "scene has no owned orphans")

func _shot(label: String) -> void:
	arena._update_hud()
	arena.training_status_label.text = "CENA DE VALIDAÇÃO · %d atores · build legal" % arena.enemies.size()
	arena.status_label.text = "Captura controlada · sem medida de DPS/FPS"
	await process_frame
	await process_frame
	for button: Button in arena.battle_controls.skill_buttons.values():
		_check(arena.get_viewport_rect().encloses(button.get_global_rect()), "skill button within viewport")
	var capture := root.get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://.godot/verification/sentinel_renderer")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(capture != null and capture.save_png(directory.path_join(label + ".png")) == OK, "native capture " + label)
	captures += 1

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
