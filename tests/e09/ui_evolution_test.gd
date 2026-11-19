extends SceneTree
## E09 T9: evolution choice with several hybrids per origin (A7), the four onboarding guides
## (C1.12) and the review-profile reader/generator (A11). Everything runs on fixture kits and
## isolated folders under .godot/verification; the personal save is never touched.

const FixtureKit = preload("res://scripts/classes/fixture/fixture_kit.gd")
const ReviewProfiles = preload("res://tools/e09_review_profiles.gd")
const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174091"
const SKILL_NAMES := {
	&"sp_ac": ["Juramento", "Graça de Guarda", "Impacto Consagrado", "Égide do Juramento", "Fé Inabalável", "Selo do Condenado", "Hora do Juramento"],
	&"mg_ac": ["Círculo Votivo", "Prisma Votivo", "Refração Curativa", "Mudança de Altar", "Coro dos Elementos", "Juízo Prismático", "Aurora Convergente"],
	&"sp_la": ["Aparo", "Leitura do Oponente", "Riposte Fatal", "Finta", "Guarda Paciente", "Recuo em Guarda", "Duelo"],
	&"mg_la": ["Marca Refratada", "Lâmina Encantada", "Refração", "Salto Prismático", "Fratura de Luz", "Sentença Prismática", "Espectro de Prisma"],
}
## Verbatim copies of the real review files delivered by K1 (6e37da52) and K2 (a0a65700).
const K1_REVIEW_BUILDS := """{
  "schema": "ragrpg_review_builds_v1",
  "identity_id": "sp_ac",
  "builds": [
    {
      "id": "paladin_bulwark",
      "name": "Baluarte da Luz",
      "base_ranks": {"shield_wall": 5, "perseverance": 5, "provoke": 3, "slash": 3, "swordsman_resistance": 3},
      "evolution_ranks": {"paladin_oath": 5, "paladin_guard_grace": 3, "paladin_consecrated_impact": 3, "paladin_oath_aegis": 4, "paladin_unshaken_faith": 3, "paladin_condemned_seal": 2, "paladin_oath_hour": 1},
      "shortcuts": ["paladin_oath", "paladin_consecrated_impact", "shield_wall", "paladin_oath_aegis", "paladin_condemned_seal", "provoke", "perseverance", "paladin_oath_hour", "slash"]
    },
    {
      "id": "paladin_hammer",
      "name": "Martelo Consagrado",
      "base_ranks": {"slash": 5, "shield_wall": 3, "perseverance": 3, "provoke": 1, "fury": 4, "swordsman_resistance": 3},
      "evolution_ranks": {"paladin_oath": 3, "paladin_guard_grace": 2, "paladin_consecrated_impact": 5, "paladin_oath_aegis": 2, "paladin_unshaken_faith": 1, "paladin_condemned_seal": 3, "paladin_oath_hour": 5},
      "shortcuts": ["paladin_oath", "paladin_consecrated_impact", "slash", "fury", "paladin_condemned_seal", "paladin_oath_hour", "shield_wall", "paladin_oath_aegis", "perseverance", "provoke"]
    }
  ]
}
"""
const K2_REVIEW_BUILDS := """{
  "schema": "ragrpg_review_builds_v1",
  "identity_id": "mg_ac",
  "builds": [
    {
      "id": "thaumaturge_prism_altar",
      "name": "Altar Prismático",
      "base_ranks": {"fireball": 5, "ice_spear": 5, "lightning": 5, "phantom_barrier": 2, "mage_mana_regeneration": 2},
      "evolution_ranks": {"thaumaturge_votive_circle": 5, "thaumaturge_votive_prism": 3, "thaumaturge_healing_refraction": 2, "thaumaturge_altar_shift": 4, "thaumaturge_elemental_choir": 3, "thaumaturge_prismatic_judgment": 3, "thaumaturge_convergent_dawn": 1},
      "shortcuts": ["thaumaturge_votive_circle", "fireball", "ice_spear", "lightning", "thaumaturge_altar_shift", "thaumaturge_prismatic_judgment", "thaumaturge_healing_refraction", "phantom_barrier", "thaumaturge_convergent_dawn"]
    },
    {
      "id": "thaumaturge_dawn_choir",
      "name": "Coro da Aurora",
      "base_ranks": {"fireball": 4, "ice_spear": 3, "lightning": 3, "fire_wall": 2, "phantom_barrier": 3, "mage_mana_regeneration": 3, "teleport": 1},
      "evolution_ranks": {"thaumaturge_votive_circle": 3, "thaumaturge_votive_prism": 2, "thaumaturge_healing_refraction": 4, "thaumaturge_altar_shift": 2, "thaumaturge_elemental_choir": 2, "thaumaturge_prismatic_judgment": 3, "thaumaturge_convergent_dawn": 5},
      "shortcuts": ["thaumaturge_votive_circle", "thaumaturge_convergent_dawn", "fireball", "ice_spear", "lightning", "thaumaturge_prismatic_judgment", "thaumaturge_healing_refraction", "thaumaturge_altar_shift", "fire_wall", "phantom_barrier", "teleport"]
    }
  ]
}
"""

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
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e09_ui_evolution")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	await _check_evolution_choice()
	await _check_onboarding()
	_check_review_reader()
	_check_review_writer()
	ClassKitRegistry.clear_fixtures()
	_cleanup_directory(root_directory)
	print("E09 T9 evolução, onboarding e perfis: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Evolution choice -------------------------------------------------------------

func _install_states(ready_ids: Array) -> void:
	ClassKitRegistry.clear_fixtures()
	for id: StringName in ClassKitRegistry.hybrid_ids():
		ClassKitRegistry.install_fixture(id, FixtureKit.new(id) if id in ready_ids else SkeletonKit.new(id))

func _open_menu(origin: StringName, label: String) -> CharacterMenu:
	var directory := root_directory.path_join(label)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(profile.profile_id, profile.next_character_counter)
	var character := CharacterState.new(character_id, "Escolha", origin)
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	profile.characters.append(character)
	profile.next_character_counter += 1
	profile.selected_character_id = character_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "%s: profile is seeded" % label)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(ProfileFacade.new(ProfileStore.new(directory, catalog)))
	root.add_child(menu)
	await process_frame
	return menu

func _option_ids(menu: CharacterMenu) -> Array[String]:
	var ids: Array[String] = []
	for child: Node in menu.evolution_options_list.get_children():
		if child is Button and String(child.name).begins_with("ChooseEvolution_"):
			ids.append(String(child.name).trim_prefix("ChooseEvolution_"))
	return ids

func _check_evolution_choice() -> void:
	# Zero ready kits: only the E00 choices that are ready; skeletons never appear (A7).
	_install_states([])
	var menu := await _open_menu(&"swordsman", "choice_zero")
	_check(_option_ids(menu) == ["defender", "berserker"], "zero ready kits: only the two ready E00 evolutions are offered")
	menu.queue_free()
	# Some ready: the origin shows its two E00 evolutions plus every ready hybrid, none hidden.
	_install_states([&"sp_ac", &"sp_la", &"mg_ac"])
	menu = await _open_menu(&"swordsman", "choice_swordsman")
	_check(_option_ids(menu) == ["defender", "berserker", "sp_ac", "sp_la"], "an origin with more than two 2-3 hybrids shows all ready ones (D-choice)")
	var paladin_label := menu.evolution_options_list.get_node("EvolutionOption_sp_ac") as Label
	var duelist_label := menu.evolution_options_list.get_node("EvolutionOption_sp_la") as Label
	_check(paladin_label.text.contains("Híbrida · afinidade Acólito") and duelist_label.text.contains("Híbrida · afinidade Ladino"), "each hybrid names its affinity in pt-BR")
	var opened := menu._begin_evolution_change(&"sp_la")
	_check(opened["ok"] and opened["pending_confirmation"] and menu.evolution_confirmation_label.text.contains("Confirmar"), "choosing a kit hybrid opens the usual explicit confirmation")
	menu._cancel_evolution_change()
	_check(not _option_ids(menu).has("sp_mg") and not _option_ids(menu).has("sp_ar"), "unready E00 placeholders stay hidden")
	menu.queue_free()
	menu = await _open_menu(&"mage", "choice_mage")
	_check(_option_ids(menu) == ["elementalist", "spiritualist", "mg_ar", "mg_ac"], "the mage origin lists the ready E00 identities and its ready kit hybrid, not the skeleton mg_la")
	menu.queue_free()
	# All four ready.
	_install_states(ClassKitRegistry.ids())
	menu = await _open_menu(&"mage", "choice_mage_all")
	_check(_option_ids(menu) == ["elementalist", "spiritualist", "mg_ar", "mg_ac", "mg_la"], "four ready kits: both mage hybrids are offered")
	menu.queue_free()
	await process_frame

# --- Onboarding --------------------------------------------------------------------

func _kit_player(id: StringName) -> PlayerActor:
	var player := PlayerActor.new()
	player.attach_kit(FixtureKit.new(id))
	return player

func _check_onboarding() -> void:
	ClassKitRegistry.clear_fixtures()
	# E10a C1.11: the E09 onboarding covers the four hybrids; the pure kits are T10's.
	for id: StringName in ClassKitRegistry.hybrid_ids():
		var script := ClassKitRegistry.onboarding_script(id)
		_check(script != null, "%s onboarding script is discovered by the C1.12 convention" % id)
		if script == null:
			continue
		var guide: Variant = script.new()
		_check(guide is Control and guide.identity_id() == id, "%s guide serves its own identity" % id)
		var player := _kit_player(id)
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
		for skill_name: String in SKILL_NAMES[id]:
			if not guide.help_label.text.contains(skill_name) and not guide.status_label.text.contains(skill_name):
				complete = false
		_check(complete, "%s help names the seven skills of the sheet" % id)
		var other := _kit_player(&"mg_la" if id != &"mg_la" else &"sp_ac")
		guide.configure(other)
		_check(not guide.visible, "%s guide hides for another kit" % id)
		var bare := PlayerActor.new()
		guide.configure(bare)
		_check(not guide.visible, "%s guide hides without a kit" % id)
		host.queue_free()
		player.free()
		other.free()
		bare.free()
	await process_frame

# --- Review profiles -----------------------------------------------------------------

func _fixture_root(label: String) -> String:
	return root_directory.path_join(label)

func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _real_files(label: String) -> String:
	var folder := _fixture_root(label)
	_write_file(folder.path_join("sp_ac/review_builds.json"), K1_REVIEW_BUILDS)
	_write_file(folder.path_join("mg_ac/review_builds.json"), K2_REVIEW_BUILDS)
	return folder

func _install_review_states() -> void:
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"sp_ac", FixtureKit.new(&"sp_ac"))
	ClassKitRegistry.install_fixture(&"mg_ac", FixtureKit.new(&"mg_ac"))
	ClassKitRegistry.install_fixture(&"sp_la", FixtureKit.new(&"sp_la"))
	ClassKitRegistry.install_fixture(&"mg_la", SkeletonKit.new(&"mg_la"))

func _check_review_reader() -> void:
	_install_review_states()
	var folder := _real_files("reader")
	var catalog := ProfileCatalog.pilot()
	_check(ReviewProfiles.review_job_xp() > 0 and ProgressionRules.job_level_for_xp(ReviewProfiles.review_job_xp(), true) == 40, "the review XP reaches exactly the maximum job (40: the 20 evolution points need it)")
	for id: StringName in [&"sp_ac", &"mg_ac"]:
		var read := ReviewProfiles.read_builds(id, folder, catalog)
		_check(read["status"] == ReviewProfiles.READY and read["builds"].size() == 2, "%s: the real review file is ready with two builds" % id)
		for build: Dictionary in read["builds"]:
			_check(build["base_points"] == 19 and build["evolution_points"] == 20, "%s/%s spends exactly 19 base and 20 evolution points (entry R1 is free)" % [id, build["id"]])
			var entry: StringName = ClassKitRegistry.entry_skill_id(id)
			var final_rank := int(build["evolution_ranks"][String(entry)])
			_check(int(build["purchased"][entry]) == final_rank - 1, "%s/%s: the entry's purchased rank is the final rank minus the free one" % [id, build["id"]])
			_check(build["shortcuts"].size() >= 9 and build["shortcuts"][0] == entry, "%s/%s: shortcuts are learned actives starting at the entry" % [id, build["id"]])
	# Pending: no file (sp_la ready, no file) and no ready_for_play (mg_la skeleton, with a file).
	_write_file(folder.path_join("mg_la/review_builds.json"), K1_REVIEW_BUILDS.replace("sp_ac", "mg_la"))
	var no_file := ReviewProfiles.read_builds(&"sp_la", folder, catalog)
	var not_ready := ReviewProfiles.read_builds(&"mg_la", folder, catalog)
	_check(no_file["status"] == ReviewProfiles.PENDING and no_file["error_code"] == &"" and not_ready["status"] == ReviewProfiles.PENDING and not_ready["error_code"] == &"", "a kit without the file, or without ready_for_play, is pending and not an error")
	_check(ReviewProfiles.read_builds(&"defender", folder, catalog)["error_code"] == &"unknown_identity", "an identity outside the four kits is refused")
	# Invalid files of a ready kit fail loudly with a code.
	var mutations := {
		&"malformed_json": func(_d: Dictionary) -> String: return "{ not json",
		&"unknown_schema": func(d: Dictionary) -> Dictionary: d["schema"] = "ragrpg_review_builds_v0"; return d,
		&"identity_mismatch": func(d: Dictionary) -> Dictionary: d["identity_id"] = "mg_ac"; return d,
		&"too_few_builds": func(d: Dictionary) -> Dictionary: d["builds"] = [d["builds"][0]]; return d,
		&"duplicate_build_id": func(d: Dictionary) -> Dictionary: d["builds"][1]["id"] = d["builds"][0]["id"]; return d,
		&"build_unnamed": func(d: Dictionary) -> Dictionary: d["builds"][0]["name"] = ""; return d,
		&"skill_not_allowed": func(d: Dictionary) -> Dictionary: d["builds"][0]["base_ranks"]["fireball"] = 1; return d,
		&"skill_in_wrong_map": func(d: Dictionary) -> Dictionary: d["builds"][0]["base_ranks"]["paladin_oath"] = 1; return d,
		&"rank_not_positive_integer": func(d: Dictionary) -> Dictionary: d["builds"][0]["base_ranks"]["slash"] = 0; return d,
		&"invalid_skill_ranks": func(d: Dictionary) -> Dictionary: d["builds"][0]["base_ranks"]["slash"] = 6; return d,
		&"base_budget_exceeded": func(d: Dictionary) -> Dictionary: d["builds"][0]["base_ranks"]["slash"] = 5; return d,
		&"evolution_budget_exceeded": func(d: Dictionary) -> Dictionary: d["builds"][0]["evolution_ranks"]["paladin_oath_hour"] = 3; return d,
		&"shortcut_not_learned_active": func(d: Dictionary) -> Dictionary: d["builds"][0]["shortcuts"].append("fury"); return d,
	}
	var mutated := _fixture_root("reader_invalid")
	for expected_code: StringName in mutations:
		var document: Dictionary = JSON.parse_string(K1_REVIEW_BUILDS)
		var changed: Variant = (mutations[expected_code] as Callable).call(document)
		_write_file(mutated.path_join("sp_ac/review_builds.json"), changed if changed is String else JSON.stringify(changed))
		var read := ReviewProfiles.read_builds(&"sp_ac", mutated, catalog)
		var code := StringName(read["error_code"])
		# A rank above the maximum or a budget overflow is reported by the shared catalog rules
		# or by the budget guard; both are legality failures, named by code.
		var accepted := code == expected_code or (expected_code == &"base_budget_exceeded" and code == &"invalid_skill_ranks")
		_check(read["status"] == ReviewProfiles.INVALID and accepted and read["builds"].is_empty(), "invalid review file is refused: %s (got %s)" % [expected_code, code])
	ClassKitRegistry.clear_fixtures()

func _check_review_writer() -> void:
	_install_review_states()
	var folder := _real_files("writer_source")
	var catalog := ProfileCatalog.pilot()
	var output := root_directory.path_join("writer_output")
	var report := ReviewProfiles.write_all(output, folder, catalog)
	_check(report["ok"] and report["profiles"].size() == 4 and report["invalid"].is_empty(), "four isolated profiles are written (two kits, two builds)")
	var pending_ids: Array = report["pending"].map(func(item: Dictionary) -> StringName: return item["identity_id"])
	_check(pending_ids == [&"sp_la", &"mg_la"], "kits without the file or the ready flag are reported pending, in order")
	var seen_directories: Dictionary = {}
	for item: Dictionary in report["profiles"]:
		_check(not seen_directories.has(item["directory"]) and String(item["directory"]).begins_with(output), "%s/%s has its own folder under the output root" % [item["identity_id"], item["build_id"]])
		seen_directories[item["directory"]] = true
		var store := ProfileStore.new(item["directory"], catalog)
		var loaded := store.load_profile()
		_check(loaded["ok"] and loaded["profile"].characters.size() == 1, "%s/%s reloads from disk" % [item["identity_id"], item["build_id"]])
		if not loaded["ok"]:
			continue
		var character: CharacterState = loaded["profile"].characters[0]
		var summary := CharacterProgression.summary(character, catalog)
		_check(character.evolution_id == item["identity_id"] and character.base_class_id == ClassKitRegistry.origin(item["identity_id"]) and summary["job_level"] == 40, "%s/%s is an evolved job-40 character of its origin" % [item["identity_id"], item["build_id"]])
		_check(summary["base_skill_points_available"] == 0 and summary["evolution_skill_points_available"] == 0, "%s/%s spent the whole 19 + 20 budget" % [item["identity_id"], item["build_id"]])
		var entry: StringName = ClassKitRegistry.entry_skill_id(item["identity_id"])
		_check(int(summary["effective_skill_ranks"].get(entry, 0)) >= 1 and character.action_slots[0] == entry, "%s/%s starts its action bar with the entry skill, learned" % [item["identity_id"], item["build_id"]])
	# The reader of the real files does not depend on the writer: running twice is refused, not merged.
	var again := ReviewProfiles.write_all(output, folder, catalog)
	_check(not again["ok"] and again["invalid"].size() == 4 and again["invalid"][0]["error_code"] == &"output_not_empty", "an existing review profile is never overwritten")
	# The personal save is out of reach.
	var personal := ReviewProfiles.write_all(OS.get_user_data_dir(), folder, catalog)
	var relative := ReviewProfiles.write_all("relative/path", folder, catalog)
	_check(not personal["ok"] and personal["error_code"] == &"unsafe_output_folder" and not relative["ok"] and relative["error_code"] == &"unsafe_output_folder", "output inside the user data directory, or relative, is refused")
	ClassKitRegistry.clear_fixtures()

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
