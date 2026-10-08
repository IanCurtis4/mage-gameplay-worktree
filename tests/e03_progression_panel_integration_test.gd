extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174002"

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e03_progression_panel")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	await _test_panel_transaction_reload_preview()
	_cleanup_directory(root_directory)
	print("E03 painel de progressão: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_panel_transaction_reload_preview() -> void:
	var directory := root_directory.path_join("transaction_reload")
	var catalog := ProfileCatalog.pilot()
	var character_id := _seed_character(directory, catalog)
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var menu_scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	var allocated := menu._allocate_attribute(&"str")
	var learned := menu._learn_skill(&"slash")
	_check(allocated["ok"] and learned["ok"] and menu.progression_attributes_label.tooltip_text.contains("FOR: base 8 · investido 1 · base + investido: teto 60 · efetivo 9") and menu.progression_skill_tree.get_node("ProgressionSkill_slash").text.contains("Rank 1/5"), "panel actions publish one attribute and the learned rank one through ProfileFacade before reload")
	menu.queue_free()
	await process_frame

	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reopened := reloaded.open_profile()
	var summary := reloaded.progression_summary(character_id)
	var preview := reloaded.build_preview(character_id)
	var reloaded_menu := menu_scene.instantiate() as CharacterMenu
	reloaded_menu.set_profile_facade(reloaded)
	root.add_child(reloaded_menu)
	await process_frame
	var preview_stats: StatBreakdown = preview["stat_breakdown"]
	var preview_snapshot: BuildSnapshot = preview["snapshot"]
	var snapshot_stats: StatBreakdown = preview_snapshot.stat_breakdown()
	_check(reopened["ok"] and summary["attribute_points_available"] == 11 and summary["effective_skill_ranks"][&"slash"] == 1 and reloaded_menu.progression_attributes_label.tooltip_text.contains("FOR: base 8 · investido 1 · base + investido: teto 60 · efetivo 9") and reloaded_menu.progression_skill_tree.get_node("ProgressionSkill_slash").text.contains("Rank 1/5"), "reloaded panel renders the durable progression transaction for the same character")
	_check(_same_values(preview_stats, snapshot_stats) and reloaded_menu.progression_attributes_label.tooltip_text.contains("efetivo %d" % int(preview_stats.primary_detail(&"str")["effective"])), "panel attribute preview agrees with the facade BuildSnapshot and StatCalculator output")
	var started := reloaded.start_run("panel-preview-run", reloaded.current_profile().revision)
	var run_stats: StatBreakdown = started["run_state"].build_snapshot.stat_breakdown()
	_check(started["ok"] and _same_values(preview_stats, run_stats) and started["run_state"].skill_levels[&"slash"] == summary["effective_skill_ranks"][&"slash"], "run snapshot preserves the same reloaded preview stats and purchased rank without a UI formula")
	reloaded_menu.queue_free()
	await process_frame

func _seed_character(directory: String, catalog: ProfileCatalog) -> String:
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Integração", &"swordsman")
	character.base_xp_total = 100
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	var slots := catalog.initial_skill_slots(&"swordsman")
	for preset: Dictionary in character.presets:
		preset["active_slots"] = slots["active_slots"].duplicate(true)
		preset["passive_slots"] = slots["passive_slots"].duplicate(true)
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var committed := ProfileStore.new(directory, catalog).commit(profile)
	_check(committed["ok"], "panel integration fixture is durably seeded")
	return character_id

func _same_values(left: StatBreakdown, right: StatBreakdown) -> bool:
	if left == null or right == null:
		return false
	var left_values := left.values()
	var right_values := right.values()
	if left_values.keys() != right_values.keys():
		return false
	for stat_id: StringName in left_values:
		if not is_equal_approx(left_values[stat_id], right_values[stat_id]):
			return false
	return true

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
