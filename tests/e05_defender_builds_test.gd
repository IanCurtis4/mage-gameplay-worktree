extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174075"

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e05_defender_builds")
	_cleanup(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	await _check_build(directory.path_join("hold"), {
		&"shield_wall": 5, &"perseverance": 5, &"swordsman_resistance": 3,
		&"defender_counterstroke": 4, &"defender_anchor": 5, &"defender_line_lock": 4, &"defender_guard_return": 3,
	}, [&"shield_wall", &"perseverance", &"defender_counterstroke", &"defender_anchor", &"defender_line_lock"], [&"swordsman_resistance", &"defender_guard_return"], 16)
	await _check_build(directory.path_join("mobile"), {
		&"slash": 5, &"dash": 5, &"vigor": 3,
		&"defender_counterstroke": 2, &"defender_wall_advance": 5, &"defender_reprisal_wave": 5, &"defender_watch": 3,
	}, [&"slash", &"dash", &"defender_counterstroke", &"defender_wall_advance", &"defender_reprisal_wave"], [&"vigor", &"defender_watch"], 15)
	_cleanup(directory)
	print("E05 Defendente builds: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_build(directory: String, purchases: Dictionary, active: Array[Variant], passive: Array[Variant], evolution_spent: int) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Defendente", &"swordsman")
	character.evolution_id = &"defender"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "seed evolved build")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	_check(facade.open_profile()["ok"], "open evolved profile")
	for skill_id: StringName in purchases:
		for index: int in int(purchases[skill_id]):
			var result := facade.learn_skill("buy-%s-%d" % [skill_id, index], facade.current_profile().revision, character_id, skill_id)
			_check(result["ok"], "buy %s rank %d" % [skill_id, index + 1])
			if not result["ok"]:
				return
	var summary := facade.progression_summary(character_id)
	_check(summary["base_skill_points_available"] == 6 and summary["evolution_skill_points_available"] == 20 - evolution_spent, "wallets remain separate and within the 19/20 caps")
	var equipped: Dictionary[StringName, Variant] = {&"weapon": null, &"armor": null, &"accessory": null}
	var preset := facade.update_preset("equip", facade.current_profile().revision, character_id, 0, active, passive, equipped)
	_check(preset["ok"], "equip legal five-active/two-passive build")
	if not preset["ok"]:
		return
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := reloaded.open_profile()
	var durable: CharacterState = opened["profile"].character_by_id(character_id)
	_check(opened["ok"] and durable.presets[0]["active_slots"] == active and durable.presets[0]["passive_slots"] == passive, "build survives durable reload")
	var preview := reloaded.build_preview(character_id)
	_check(preview["ok"] and preview["snapshot"].skill_ranks[&"defender_counterstroke"] == int(purchases[&"defender_counterstroke"]) + 1, "preview uses persisted ranks and free entry")
	var started := reloaded.start_run("start", reloaded.current_profile().revision)
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"defender", "production run starts from reloaded build")
	if not started["ok"]:
		return
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(nav, started["run_state"])
	root.add_child(player)
	player.set_process(false)
	_check(player.available_skill_ids() == player.run_state.build_snapshot.learned_skill_ids(ProfileCatalog.ACTIVE) and player.skill_rank(&"defender_counterstroke") == int(purchases[&"defender_counterstroke"]) + 1, "runtime actor receives all learned legal actives and correct rank")
	player.queue_free()
	await process_frame

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
