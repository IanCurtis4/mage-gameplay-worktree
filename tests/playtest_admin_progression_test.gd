extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/playtest_admin")
	DirAccess.make_dir_recursive_absolute(directory)
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var profile := ProfileState.new("123e4567-e89b-42d3-a456-426614174000")
	var first_id := IdentityIds.character_id(profile.profile_id, 1)
	var second_id := IdentityIds.character_id(profile.profile_id, 2)
	for entry: Dictionary in [{"id": first_id, "name": "Primeiro"}, {"id": second_id, "name": "Segundo"}]:
		var character := CharacterState.new(entry["id"], entry["name"], &"swordsman")
		var slots := catalog.initial_skill_slots(&"swordsman")
		for preset: Dictionary in character.presets:
			preset["active_slots"] = slots["active_slots"].duplicate(true)
			preset["passive_slots"] = slots["passive_slots"].duplicate(true)
		profile.characters.append(character)
	profile.selected_character_id = first_id
	profile.next_character_counter = 3
	var seeded := store.commit(profile)
	_check(seeded["ok"], "seeded an isolated two-character profile")
	var facade := ProfileFacade.new(store)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu: Variant = scene.instantiate()
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	_check(not menu.playtest_toggle.button_pressed and not menu.playtest_panel.visible and menu.playtest_buttons.size() == 4, "admin controls start closed and expose four shortcuts")
	menu.playtest_toggle.button_pressed = true
	menu._select_roster_index(1)
	var added: Dictionary = menu._apply_playtest_progression(&"base_xp", 1000)
	_check(added["ok"] and facade.current_profile().character_by_id(first_id).base_xp_total == 0 and facade.current_profile().character_by_id(second_id).base_xp_total == 1000, "focused alt receives XP while selected run character remains unchanged")
	var prep: Dictionary = menu._apply_playtest_progression(&"prepare_evolution")
	var prepared: CharacterState = facade.current_profile().character_by_id(second_id)
	_check(prep["ok"] and prepared.base_xp_total == 1800 and prepared.job_xp_total == 4940 and prepared.evolution_id.is_empty() and prepared.purchased_skill_ranks.is_empty(), "preparation reaches canonical thresholds without evolving or granting skills")
	var revision := facade.current_profile().revision
	var repeated: Dictionary = menu._apply_playtest_progression(&"prepare_evolution")
	_check(repeated["ok"] and repeated["already_applied"] and facade.current_profile().revision == revision, "repeated preparation does not write")
	var maxed: Dictionary = menu._apply_playtest_progression(&"max_levels")
	_check(maxed["ok"] and facade.current_profile().character_by_id(second_id).base_xp_total == 13050 and facade.current_profile().character_by_id(second_id).job_xp_total == 4940, "unevolved maximum respects job level 20")
	var capped: Dictionary = menu._apply_playtest_progression(&"job_xp", 9223372036854775807)
	_check(capped["ok"] and capped["already_applied"] and facade.current_profile().revision == maxed["new_revision"], "XP shortcut at cap is a no-op")
	var stale: Dictionary = facade.grant_playtest_progression("stale-admin", 1, second_id, &"base_xp", 1000)
	var invalid: Dictionary = facade.grant_playtest_progression("invalid-admin", facade.current_profile().revision, second_id, &"job_xp", -1)
	_check(not stale["ok"] and stale["error_code"] == &"stale_revision" and not invalid["ok"] and invalid["error_code"] == &"invalid_playtest_amount", "revision and positive amount boundaries reject invalid writes")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var loaded := reloaded.open_profile()
	_check(loaded["ok"] and reloaded.current_profile().character_by_id(second_id).base_xp_total == 13050 and reloaded.current_profile().character_by_id(first_id).base_xp_total == 0, "XP survives reload only on focused character")
	var evolved: Dictionary = facade.change_evolution("admin-evolve", facade.current_profile().revision, second_id, &"defender")
	var max_evolved: Dictionary = menu._apply_playtest_progression(&"max_levels")
	_check(evolved["ok"] and max_evolved["ok"] and facade.current_profile().character_by_id(second_id).job_xp_total == ProgressionRules.MAX_JOB_XP, "evolved max reaches job40 through ordinary progression")
	var started: Dictionary = facade.start_run("admin-start", facade.current_profile().revision)
	var blocked: Dictionary = facade.grant_playtest_progression("admin-blocked", facade.current_profile().revision, second_id, &"max_levels")
	_check(started["ok"] and not blocked["ok"] and blocked["error_code"] == &"run_active", "admin mutation is rejected during a run")
	menu.playtest_toggle.button_pressed = false
	_check(not menu.playtest_panel.visible and facade.current_profile().character_by_id(second_id).base_xp_total == 13050, "closing panel does not undo persisted XP")
	menu.queue_free()
	print("Playtest admin progression: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d of %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


