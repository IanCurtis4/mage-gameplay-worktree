extends SceneTree
## E10a T10 (C7): creation of the Acólito, evolution choice (Sacerdote and Cultista), the three
## onboarding guides and the review-profile tool. Production modules (T5, T6, T7); profiles and
## saves live in isolated folders under .godot/verification; the personal save is never touched.

const FamilyProfiles = preload("res://tools/e10a_review_profiles.gd")
const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174101"
const GUIDE_TERMS := {
	&"acolyte": ["Loucura", "Delírio", "Luz Punitiva", "Prece", "Escudo Votivo", "Visão Eldritch", "Devoção", "Sacerdote", "Cultista"],
	&"priest": ["Santuário", "Graça", "Égide", "Juízo", "Exorcista", "Selo de Luz", "Hora Santa"],
	&"cultist": ["Olhar do Abismo", "Delírio", "Êxtase", "Ídolo Impossível", "Delírio Compartilhado", "Pupila Aberta", "Geometria Impossível", "Revelação", "Loucura"],
}
const BUILD_NAMES := {&"priest": ["Bastião da Fé", "Inquisição"], &"cultist": ["Profeta", "Vidente"]}

class SkeletonKit extends ClassKit:
	var skeleton_id: StringName = &""
	func _init(id: StringName = &"") -> void:
		skeleton_id = id
	func kit_id() -> StringName:
		return skeleton_id

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e10a_ui_family")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	await _check_creation()
	await _check_evolution_choice()
	await _check_onboarding()
	_check_review_reader()
	_check_review_writer()
	ClassKitRegistry.clear_fixtures()
	ClassBaseRegistry.clear_fixtures()
	_cleanup_directory(root_directory)
	print("E10a T10 criação, evolução, onboarding e perfis: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _open_menu(directory_label: String, character: CharacterState = null) -> CharacterMenu:
	var directory := root_directory.path_join(directory_label)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	if character != null:
		var profile := ProfileState.new(PROFILE_ID)
		character.character_id = IdentityIds.character_id(profile.profile_id, profile.next_character_counter)
		profile.characters.append(character)
		profile.next_character_counter += 1
		profile.selected_character_id = character.character_id
		_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "%s: profile is seeded" % directory_label)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(ProfileFacade.new(ProfileStore.new(directory, catalog)))
	root.add_child(menu)
	await process_frame
	return menu

# --- Creation ----------------------------------------------------------------------

func _check_creation() -> void:
	ClassKitRegistry.clear_fixtures()
	ClassBaseRegistry.clear_fixtures()
	var menu := await _open_menu("creation")
	_check(ProfileCatalog.pilot().base_class_is_available(&"acolyte"), "the Acólito is an available base (T5 ready_for_play)")
	_check(menu.create_buttons.size() == 4 and menu.create_buttons[3].text == "Criar Acólito", "creation lists the four bases, the Acólito last")
	var description := menu.create_panel.get_node_or_null("CreateDescription_acolyte") as Label
	_check(description != null and description.text.contains("Sacerdote") and description.text.contains("Cultista"), "the Acólito carries a pt-BR description naming its two evolutions")
	for class_id: StringName in [&"swordsman", &"mage", &"archer"]:
		_check(menu.create_panel.get_node_or_null("CreateDescription_%s" % class_id) != null, "%s also has a creation description" % class_id)
	var created := menu.create_character(&"acolyte")
	_check(created["ok"] and menu.facade.current_profile().characters.size() == 1, "the Acólito can be created")
	var character: CharacterState = menu.facade.current_profile().characters[0]
	_check(character.base_class_id == &"acolyte" and character.display_name == "Novo Acólito" and menu.roster_list.get_item_text(0).contains("Acólito"), "the new character is an Acólito, named in pt-BR in the roster")
	menu.queue_free()
	await process_frame

# --- Evolution choice -----------------------------------------------------------------

func _option_ids(menu: CharacterMenu) -> Array[String]:
	var ids: Array[String] = []
	for child: Node in menu.evolution_options_list.get_children():
		if child is Button and String(child.name).begins_with("ChooseEvolution_"):
			ids.append(String(child.name).trim_prefix("ChooseEvolution_"))
	return ids

func _check_evolution_choice() -> void:
	var character := CharacterState.new("placeholder", "Escolha", &"acolyte")
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	var menu := await _open_menu("choice", character)
	_check(_option_ids(menu) == ["priest", "cultist"], "the Acólito's evolution choice shows Sacerdote and Cultista, in order (got %s)" % [_option_ids(menu)])
	var priest_label := menu.evolution_options_list.get_node_or_null("EvolutionOption_priest") as Label
	var cultist_label := menu.evolution_options_list.get_node_or_null("EvolutionOption_cultist") as Label
	_check(priest_label != null and priest_label.text.contains("Sacerdote") and priest_label.text.contains("2-1"), "the Sacerdote row names its branch")
	_check(cultist_label != null and cultist_label.text.contains("Cultista") and cultist_label.text.contains("2-2"), "the Cultista row names its branch")
	_check(menu.evolution_state_label.text.contains("Origem: Acólito"), "the evolution summary names the Acólito origin")
	var opened := menu._begin_evolution_change(&"cultist")
	_check(opened["ok"] and opened["pending_confirmation"] and menu.evolution_confirmation_label.text.contains("Confirmar"), "choosing the Cultista opens the explicit confirmation")
	menu._cancel_evolution_change()
	menu.queue_free()
	var swordsman := CharacterState.new("placeholder", "Paladino", &"swordsman")
	swordsman.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	swordsman.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	menu = await _open_menu("choice_swordsman", swordsman)
	_check(menu._affinity_name(&"acolyte") == "Acólito", "the hybrids' affinity label resolves to the real base name")
	menu.queue_free()
	await process_frame

# --- Onboarding --------------------------------------------------------------------

func _player_for(id: StringName) -> PlayerActor:
	var player := PlayerActor.new()
	var origin_id: StringName = &"acolyte" if id == &"acolyte" else ClassKitRegistry.origin(id)
	player.attach_origin_kit(ClassBaseRegistry.module(origin_id).create_runtime())
	if id != &"acolyte":
		player.attach_kit(ClassKitRegistry.module(id).create_runtime())
	return player

func _check_onboarding() -> void:
	for id: StringName in [&"acolyte", &"priest", &"cultist"]:
		var script := ClassKitRegistry.onboarding_script(id)
		_check(script != null, "%s onboarding script is discovered by the C1.12 convention" % id)
		if script == null:
			continue
		var guide: Variant = script.new()
		_check(guide is Control and guide.identity_id() == id and not guide.guide_title().is_empty(), "%s guide serves its own identity" % id)
		var player := _player_for(id)
		_check(player.has_kit() and (id != &"acolyte" or player.kit == null), "%s: the player carries the module (the base guide reads a null kit)" % id)
		guide.configure(player)
		var host := Control.new()
		root.add_child(host)
		host.add_child(guide)
		await process_frame
		_check(guide.visible and guide.mouse_filter == Control.MOUSE_FILTER_IGNORE and guide.toggle_button.focus_mode == Control.FOCUS_NONE and guide.toggle_button.mouse_filter == Control.MOUSE_FILTER_STOP, "%s guide is visible, passes clicks through and only its button captures" % id)
		_check(not guide.help_label.visible and not guide.status_label.text.is_empty(), "%s guide starts compact with a loop line" % id)
		guide.toggle_button.pressed.emit()
		_check(guide.help_label.visible and guide.toggle_button.text == "Guia −", "%s help expands and collapses without touching the run" % id)
		var complete := true
		for term: String in GUIDE_TERMS[id]:
			if not guide.help_label.text.contains(term) and not guide.status_label.text.contains(term):
				complete = false
				push_error("guide %s missing term %s" % [id, term])
		_check(complete, "%s help names its mechanics and skills in pt-BR" % id)
		var other_id: StringName = &"cultist" if id != &"cultist" else &"priest"
		var other := _player_for(other_id)
		guide.configure(other)
		_check(not guide.visible, "%s guide hides for another identity" % id)
		var bare := PlayerActor.new()
		guide.configure(bare)
		_check(not guide.visible, "%s guide hides without a kit" % id)
		host.queue_free()
		player.free()
		other.free()
		bare.free()
	await process_frame

# --- Review profiles -------------------------------------------------------------------

func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _check_review_reader() -> void:
	ClassKitRegistry.clear_fixtures()
	var catalog := ProfileCatalog.pilot()
	_check(FamilyProfiles.family_ids() == [&"acolyte", &"priest", &"cultist"], "the family list is the base and its two pure kits")
	for id: StringName in [&"priest", &"cultist"]:
		var read := FamilyProfiles.read_builds(id, "res://scripts/classes", catalog)
		_check(read["status"] == FamilyProfiles.READY and read["builds"].size() == 2, "%s: the real review file is ready with two builds" % id)
		var names: Array = read["builds"].map(func(build: Dictionary) -> String: return build["name"])
		_check(names == BUILD_NAMES[id], "%s: the builds are named as D6 says (got %s)" % [id, names])
		for build: Dictionary in read["builds"]:
			_check(build["base_points"] == 19 and build["evolution_points"] == 20, "%s/%s spends exactly 19 base and 20 evolution points" % [id, build["id"]])
			_check(build["shortcuts"].size() >= 6 and build["shortcuts"][0] == ClassKitRegistry.entry_skill_id(id), "%s/%s: shortcuts start at the entry skill" % [id, build["id"]])
	var base := FamilyProfiles.read_builds(&"acolyte", "res://scripts/classes", catalog)
	_check(base["status"] == FamilyProfiles.PENDING and base["error_code"] == &"" and base["builds"].is_empty(), "the base has no builds: pending, no error")
	var empty_root := root_directory.path_join("reader_empty")
	DirAccess.make_dir_recursive_absolute(empty_root)
	var no_file := FamilyProfiles.read_builds(&"priest", empty_root, catalog)
	_check(no_file["status"] == FamilyProfiles.PENDING and no_file["error_code"] == &"" and no_file["reason"].contains("review_builds.json"), "a kit without the file is pending, not an error")
	ClassKitRegistry.install_fixture(&"cultist", SkeletonKit.new(&"cultist"))
	var not_ready := FamilyProfiles.read_builds(&"cultist", "res://scripts/classes", catalog)
	_check(not_ready["status"] == FamilyProfiles.PENDING and not_ready["error_code"] == &"" and not_ready["reason"].contains("ready_for_play"), "a kit without ready_for_play is pending, not an error")
	ClassKitRegistry.clear_fixtures()
	_check(FamilyProfiles.read_builds(&"defender", "res://scripts/classes", catalog)["error_code"] == &"unknown_identity", "an identity outside the kits is refused")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/classes/priest/review_builds.json"))
	document["builds"][0]["evolution_ranks"]["priest_holy_hour"] = 5
	document["builds"][0]["evolution_ranks"]["priest_judgment"] = 5
	var invalid_root := root_directory.path_join("reader_invalid")
	_write_file(invalid_root.path_join("priest/review_builds.json"), JSON.stringify(document))
	var invalid := FamilyProfiles.read_builds(&"priest", invalid_root, catalog)
	_check(invalid["status"] == FamilyProfiles.INVALID and not StringName(invalid["error_code"]).is_empty() and invalid["builds"].is_empty(), "an over-budget review file is invalid with a code (%s)" % [invalid["error_code"]])
	_check(FamilyProfiles.review_display_name("Profeta") == "E10a Profeta" and FamilyProfiles.review_display_name("Bastião da Fé") == "E10a Bastião da Fé" and FamilyProfiles.review_display_name("X".repeat(30)).length() <= 24, "profile names are prefixed and fit the 24-character limit")

func _check_review_writer() -> void:
	ClassKitRegistry.clear_fixtures()
	var catalog := ProfileCatalog.pilot()
	var output := root_directory.path_join("writer_output")
	var report := FamilyProfiles.write_all(output, "res://scripts/classes", catalog)
	_check(report["ok"] and report["profiles"].size() == 4 and report["invalid"].is_empty(), "four isolated profiles are written (two kits, two builds each)")
	var pending_ids: Array = report["pending"].map(func(item: Dictionary) -> StringName: return item["identity_id"])
	_check(pending_ids == [&"acolyte"], "the base is reported pending, in order")
	var seen: Dictionary = {}
	for item: Dictionary in report["profiles"]:
		_check(not seen.has(item["directory"]) and String(item["directory"]).begins_with(output), "%s/%s has its own folder under the output root" % [item["identity_id"], item["build_id"]])
		seen[item["directory"]] = true
		var loaded := ProfileStore.new(item["directory"], catalog).load_profile()
		_check(loaded["ok"] and loaded["profile"].characters.size() == 1, "%s/%s reloads from disk" % [item["identity_id"], item["build_id"]])
		if not loaded["ok"]:
			continue
		var character: CharacterState = loaded["profile"].characters[0]
		var summary := CharacterProgression.summary(character, catalog)
		_check(character.evolution_id == item["identity_id"] and character.base_class_id == &"acolyte" and summary["job_level"] == 40 and character.display_name.begins_with("E10a "), "%s/%s is an evolved job-40 Acólito, named E10a" % [item["identity_id"], item["build_id"]])
		_check(summary["base_skill_points_available"] == 0 and summary["evolution_skill_points_available"] == 0, "%s/%s spent the whole 19 + 20 budget" % [item["identity_id"], item["build_id"]])
		var entry: StringName = ClassKitRegistry.entry_skill_id(item["identity_id"])
		_check(int(summary["effective_skill_ranks"].get(entry, 0)) >= 1 and character.action_slots[0] == entry, "%s/%s starts its action bar with the entry skill, learned" % [item["identity_id"], item["build_id"]])
	var again := FamilyProfiles.write_all(output, "res://scripts/classes", catalog)
	_check(not again["ok"] and again["invalid"].size() == 4 and again["invalid"][0]["error_code"] == &"output_not_empty", "an existing review profile is never overwritten")
	var personal := FamilyProfiles.write_all(OS.get_user_data_dir(), "res://scripts/classes", catalog)
	var relative := FamilyProfiles.write_all("relative/path", "res://scripts/classes", catalog)
	_check(not personal["ok"] and personal["error_code"] == &"unsafe_output_folder" and not relative["ok"] and relative["error_code"] == &"unsafe_output_folder", "output inside the user data directory, or relative, is refused")

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
