extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174099"

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e05_berserker_builds")
	_cleanup(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	await _check_build(directory.path_join("boss"), {
		&"fury": 5, &"brutal_strike": 5, &"blood_thirst": 3,
		&"berserker_rupture": 4, &"berserker_execution": 5,
		&"berserker_breath_steal": 4, &"berserker_pursuit": 3,
	}, [&"fury", &"brutal_strike", &"berserker_rupture", &"berserker_execution", &"berserker_breath_steal"], [&"blood_thirst", &"berserker_pursuit"], 16)
	await _check_build(directory.path_join("mobile"), {
		&"dash": 5, &"concentrated_rage": 5, &"vigor": 3,
		&"berserker_rupture": 2, &"berserker_wound_leap": 5,
		&"berserker_blood_rift": 5, &"berserker_obstinacy": 3,
	}, [&"dash", &"concentrated_rage", &"berserker_rupture", &"berserker_wound_leap", &"berserker_blood_rift"], [&"vigor", &"berserker_obstinacy"], 15)
	_cleanup(directory)
	print("E05 Berserker builds: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_build(directory: String, purchases: Dictionary, active: Array[Variant], passive: Array[Variant], evolution_spent: int) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Berserker", &"swordsman")
	character.evolution_id = &"berserker"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "seed evolved production character")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	_check(facade.open_profile()["ok"], "open Berserker profile")
	for skill_id: StringName in purchases:
		for index: int in int(purchases[skill_id]):
			var result := facade.learn_skill("buy-%s-%d" % [skill_id, index], facade.current_profile().revision, character_id, skill_id)
			_check(result["ok"], "buy %s rank %d" % [skill_id, index + 1])
			if not result["ok"]:
				return
	var summary := facade.progression_summary(character_id)
	_check(summary["base_skill_points_available"] == 6 and summary["evolution_skill_points_available"] == 20 - evolution_spent, "base and evolution wallets retain exact independent balances")
	var equipped: Dictionary[StringName, Variant] = {&"weapon": null, &"armor": null, &"accessory": null}
	var preset := facade.update_preset("equip", facade.current_profile().revision, character_id, 0, active, passive, equipped)
	_check(preset["ok"], "equip five actives and two passives")
	if not preset["ok"]:
		return
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := reloaded.open_profile()
	var durable: CharacterState = opened["profile"].character_by_id(character_id)
	_check(opened["ok"] and durable.presets[0]["active_slots"] == active and durable.presets[0]["passive_slots"] == passive, "ranks and slots survive durable reload")
	var preview := reloaded.build_preview(character_id)
	_check(preview["ok"] and preview["snapshot"].skill_ranks[&"berserker_rupture"] == int(purchases[&"berserker_rupture"]) + 1, "free Rupture entry combines correctly with purchased ranks")
	var started := reloaded.start_run("start", reloaded.current_profile().revision)
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"berserker", "production run starts from reloaded Berserker build")
	if not started["ok"]:
		return
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(nav, started["run_state"])
	player.global_position = Vector2(400, 350)
	root.add_child(player)
	player.set_process(false)
	_check(player.available_skill_ids() == player.run_state.build_snapshot.learned_skill_ids(ProfileCatalog.ACTIVE) and player.skill_rank(&"berserker_rupture") == int(purchases[&"berserker_rupture"]) + 1 and player.character_animation.actor_kind == &"berserker", "run exposes all learned legal actives and the distinct atlas")
	if &"berserker_execution" in active:
		_check_boss_without_adds(player)
	player.queue_free()
	await process_frame

func _check_boss_without_adds(player: PlayerActor) -> void:
	var boss := CombatActor.new()
	boss.setup("Boss solo", Color.WHITE, StatCalculator.calculate({&"vit": 20}), 24.0)
	boss.configure_hard_control_profile(true)
	boss.global_position = Vector2(470, 350)
	boss.health.max_hp = 100000.0
	boss.health.current_hp = 100000.0
	var controller := RunController.new()
	controller.player = player
	player.attack_requested.connect(_force_boss_direct_hit)
	player.attack_requested.connect(controller._on_attack_requested)
	player.berserker_breath_hit_requested.connect(_force_boss_breath_hit)
	player.berserker_breath_hit_requested.connect(controller._on_berserker_breath_hit_requested)
	boss.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var boss_id := boss.get_instance_id()
	_check(player.use_berserker_rupture(boss) and player.berserker_wound_stacks(boss_id) == 1, "solo boss gains first wound from real Rupture damage")
	player.health.current_hp = player.health.max_hp - 100.0
	var hp_before := player.health.current_hp
	player.current_sp = player.max_sp
	_check(player.use_berserker_breath_steal(boss) and boss.is_alive() and player.health.current_hp > hp_before and player.berserker_wound_stacks(boss_id) == 2, "marked surviving solo boss enables bounded recovery and another charge")
	player.current_sp = player.max_sp
	_check(player.use_berserker_execution(boss) and boss.is_alive() and player.berserker_wound_stacks(boss_id) == 0, "Execution converts the boss wound without adds or kill credit")
	boss.free()
	controller.free()

func _force_boss_direct_hit(request: DamageRequest, _target: CombatActor) -> void:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false

func _force_boss_breath_hit(request: DamageRequest, _target: CombatActor, _fraction: float, _marked: bool) -> void:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false

func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	for file: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for child: String in directory.get_directories():
		_cleanup(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
