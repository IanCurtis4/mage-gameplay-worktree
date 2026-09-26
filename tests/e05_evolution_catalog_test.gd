extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174000"

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e05_evolution_catalog")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_production_roster()
	_check_validation_and_isolation()
	_check_query_states()
	_cleanup_directory(root_directory)
	print("E05 S1A catálogo de evolução: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_production_roster() -> void:
	var catalog := ProfileCatalog.pilot()
	var definitions := catalog.evolution_definitions()
	var expected_order: Array[StringName] = [
		&"defender", &"berserker", &"sp_mg", &"sp_ar",
		&"elementalist", &"spiritualist", &"mg_sp", &"mg_ar",
		&"sentinel", &"hunter", &"ar_sp", &"ar_mg",
	]
	var actual_order: Array[StringName] = []
	for definition: EvolutionDefinition in definitions:
		actual_order.append(definition.id)
	_check(catalog.is_valid() and actual_order == expected_order, "production catalog registers the twelve accepted E00 identities in deterministic order")
	var expected: Dictionary[StringName, Array] = {
		&"defender": ["Defendente", &"swordsman", &"2-1", &""],
		&"berserker": ["Berserker", &"swordsman", &"2-2", &""],
		&"sp_mg": ["Cavaleiro Rúnico", &"swordsman", &"2-3", &"mage"],
		&"sp_ar": ["Baluarte de Cerco", &"swordsman", &"2-3", &"archer"],
		&"elementalist": ["Elementalista", &"mage", &"2-1", &""],
		&"spiritualist": ["Espiritualista", &"mage", &"2-2", &""],
		&"mg_sp": ["Devastador Astral", &"mage", &"2-3", &"swordsman"],
		&"mg_ar": ["Geômetra", &"mage", &"2-3", &"archer"],
		&"sentinel": ["Sentinela", &"archer", &"2-1", &""],
		&"hunter": ["Caçador", &"archer", &"2-2", &""],
		&"ar_sp": ["Saqueador", &"archer", &"2-3", &"swordsman"],
		&"ar_mg": ["Caçador de Espectros", &"archer", &"2-3", &"mage"],
	}
	for definition: EvolutionDefinition in definitions:
		var values: Array = expected[definition.id]
		_check(
			definition.display_name == values[0]
			and definition.origin_class_id == values[1]
			and definition.origin_class_id == IdentityIds.evolution_origin(definition.id)
			and definition.branch_kind == values[2]
			and definition.affinity_class_id == values[3],
			"%s preserves accepted name, origin, branch and affinity" % definition.id
		)
		var has_defender_metadata := definition.id == &"defender" and definition.entry_skill_id == &"defender_counterstroke" and definition.exclusive_skill_ids.size() == 7
		var has_no_kit := definition.id != &"defender" and definition.entry_skill_id.is_empty() and definition.exclusive_skill_ids.is_empty()
		_check(not definition.content_ready and (has_defender_metadata or has_no_kit), "%s remains unavailable until its complete kit is verified" % definition.id)
	var mage_options := catalog.evolution_definitions_for_origin(&"mage")
	_check(mage_options.map(func(definition: EvolutionDefinition) -> StringName: return definition.id) == [&"elementalist", &"spiritualist", &"mg_sp", &"mg_ar"], "origin query includes only the four Mage destinations")
	var geometer := catalog.evolution_definition(&"mg_ar")
	_check(geometer.origin_class_id == &"mage" and geometer.affinity_class_id == &"archer", "mg_ar remains Mage origin with Archer affinity")
	var defender := catalog.evolution_definition(&"defender")
	var expected_defender_ids: Array[StringName] = [
		&"defender_counterstroke", &"defender_watch", &"defender_anchor",
		&"defender_line_lock", &"defender_guard_return",
		&"defender_wall_advance", &"defender_reprisal_wave",
	]
	var defender_library := catalog.skill_ids_for_identity(&"swordsman", &"defender")
	_check(defender.entry_skill_id == &"defender_counterstroke" and defender.exclusive_skill_ids == expected_defender_ids and not defender.content_ready, "production declares the complete Defender library but does not enable gameplay")
	_check(&"slash" in defender_library and defender_library.slice(defender_library.size() - 7) == expected_defender_ids and &"defender_counterstroke" not in catalog.skill_ids_for_identity(&"mage", &"mg_sp") and &"defender_counterstroke" not in catalog.skill_ids_for_identity(&"swordsman", &"berserker"), "resolved library combines Swordsman base and only the Defender-exclusive seven")
	var job_gates: Array[int] = [20, 23, 25, 28, 31, 34, 37]
	for index: int in expected_defender_ids.size():
		var metadata := catalog.skill_metadata(expected_defender_ids[index])
		_check(metadata["rank_requirements"][1]["job_level"] == job_gates[index] and metadata["wallet"] == ProfileCatalog.EVOLUTION_WALLET and metadata["required_evolution_id"] == &"defender", "%s keeps its approved job gate and evolution wallet" % expected_defender_ids[index])

func _check_validation_and_isolation() -> void:
	var source := _definition(&"defender", "Defendente", &"swordsman", &"2-1")
	var isolated := ProfileCatalog.new()
	_check(isolated.add_evolution(source), "catalog accepts one structurally valid unavailable definition")
	source.display_name = "Mutado"
	source.exclusive_skill_ids.append(&"foreign")
	var first := isolated.evolution_definition(&"defender")
	first.display_name = "Retorno mutado"
	first.exclusive_skill_ids.append(&"another")
	var second := isolated.evolution_definition(&"defender")
	_check(isolated.seal().is_valid() and second.display_name == "Defendente" and second.exclusive_skill_ids.is_empty(), "catalog owns a deep definition copy and every returned Resource is isolated")

	var duplicate := ProfileCatalog.new()
	var duplicate_definition := _definition(&"defender", "Defendente", &"swordsman", &"2-1")
	var added_once := duplicate.add_evolution(duplicate_definition)
	var added_twice := duplicate.add_evolution(duplicate_definition)
	_check(added_once and not added_twice and not duplicate.seal().is_valid(), "duplicate evolution IDs invalidate construction instead of replacing metadata")

	var wrong_origin := ProfileCatalog.new()
	wrong_origin.add_evolution(_definition(&"mg_ar", "Geômetra", &"archer", &"2-3", &"mage"))
	_check(not wrong_origin.seal().is_valid(), "definition origin must match the authoritative IdentityIds map")
	var wrong_pure_affinity := ProfileCatalog.new()
	wrong_pure_affinity.add_evolution(_definition(&"defender", "Defendente", &"swordsman", &"2-1", &"mage"))
	_check(not wrong_pure_affinity.seal().is_valid(), "pure evolution rejects an affinity class")
	var wrong_hybrid_affinity := ProfileCatalog.new()
	wrong_hybrid_affinity.add_evolution(_definition(&"sp_mg", "Cavaleiro Rúnico", &"swordsman", &"2-3", &"swordsman"))
	_check(not wrong_hybrid_affinity.seal().is_valid(), "hybrid affinity must be a different valid base")

	var incomplete := ProfileCatalog.new()
	incomplete.add_evolution(_definition(&"defender", "Defendente", &"swordsman", &"2-1"))
	_check(incomplete.seal().is_valid(), "empty content references are valid only while the destination remains unavailable")

	var wrong_reference := ProfileCatalog.new()
	wrong_reference.add_skill(&"wrong_entry", [&"swordsman"], ProfileCatalog.ACTIVE, ProfileCatalog.EVOLUTION_WALLET, 1, 4, &"berserker")
	var wrong_definition := _definition(&"defender", "Defendente", &"swordsman", &"2-1")
	wrong_definition.entry_skill_id = &"wrong_entry"
	wrong_definition.exclusive_skill_ids = [&"wrong_entry"]
	wrong_reference.add_evolution(wrong_definition)
	_check(not wrong_reference.seal().is_valid(), "a filled skill reference to another evolution is always invalid")

	var metadata_only := _ready_catalog(false)
	var ready := _ready_catalog(true)
	_check(metadata_only.is_valid() and not metadata_only.evolution_definition(&"defender").content_ready, "a coherent entry skill does not make content ready without the explicit readiness assertion")
	_check(ready.is_valid() and ready.evolution_definition(&"defender").content_ready, "explicit readiness is accepted only with a coherent exclusive library and one free job-20 active")
	var extra_free := ProfileCatalog.new()
	extra_free.add_skill(&"defender_entry", [&"swordsman"], ProfileCatalog.ACTIVE, ProfileCatalog.EVOLUTION_WALLET, 1, 4, &"defender")
	extra_free.add_skill(&"defender_free_passive", [&"swordsman"], ProfileCatalog.PASSIVE, ProfileCatalog.EVOLUTION_WALLET, 1, 2, &"defender")
	var extra_free_definition := _definition(&"defender", "Defendente", &"swordsman", &"2-1")
	extra_free_definition.entry_skill_id = &"defender_entry"
	extra_free_definition.exclusive_skill_ids = [&"defender_entry", &"defender_free_passive"]
	extra_free_definition.content_ready = true
	extra_free.add_evolution(extra_free_definition)
	_check(not extra_free.seal().is_valid(), "ready content rejects any free rank beyond the single active entry")
	var returned := ready.evolution_definitions_for_origin(&"swordsman")
	returned[0].exclusive_skill_ids.clear()
	var copied := ready.copy_catalog()
	var copied_definition := copied.evolution_definition(&"defender")
	copied_definition.display_name = "Cópia mutada"
	_check(ready.evolution_definition(&"defender").exclusive_skill_ids == [&"defender_entry"] and copied.evolution_definition(&"defender").display_name == "Defendente", "origin lists and catalog copies cannot mutate either catalog")

func _check_query_states() -> void:
	var unavailable_directory := root_directory.path_join("unavailable_facade")
	_prepare_directory(unavailable_directory)
	var unopened := ProfileFacade.new(ProfileStore.new(unavailable_directory, _ready_catalog(true)))
	var unavailable := unopened.evolution_options("missing")
	_check(not unavailable["ok"] and unavailable["error_code"] == &"profile_unavailable" and not FileAccess.file_exists(unavailable_directory.path_join(ProfileStore.PRIMARY_FILE)), "query refuses unavailable facade state without opening, repairing or writing a profile")

	var locked_directory := root_directory.path_join("locked")
	_prepare_directory(locked_directory)
	var ready_catalog := _ready_catalog(true)
	var locked_id := _seed_profile(locked_directory, ready_catalog, 0, 0)
	var locked_facade := ProfileFacade.new(ProfileStore.new(locked_directory, ready_catalog))
	var locked_open := locked_facade.open_profile()
	var locked := locked_facade.evolution_options(locked_id)
	var locked_defender := _option(locked["options"], &"defender")
	_check(locked_open["ok"] and not locked_defender["requirements_met"] and locked_defender["content_ready"] and not locked_defender["can_select"] and &"requirements_unmet" in locked_defender["blocking_reasons"], "query separates unmet 10/20 requirements from ready content")

	var exact_directory := root_directory.path_join("exact_threshold")
	_prepare_directory(exact_directory)
	var exact_id := _seed_profile(exact_directory, ready_catalog, ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP)
	var exact_facade := ProfileFacade.new(ProfileStore.new(exact_directory, ready_catalog))
	var exact_open := exact_facade.open_profile()
	var primary_path := exact_directory.path_join(ProfileStore.PRIMARY_FILE)
	var before_text := _read_text(primary_path)
	var before_revision: int = exact_facade.current_profile().revision
	var exact := exact_facade.evolution_options(exact_id)
	var defender := _option(exact["options"], &"defender")
	var rune_knight := _option(exact["options"], &"sp_mg")
	_check(exact_open["ok"] and exact["base_level"] == 10 and exact["job_level"] == 20 and exact["options"].size() == 4, "exact base-10/job-20 threshold returns only the four destinations of the fixed origin")
	_check(defender["requirements_met"] and defender["content_ready"] and defender["can_select"] and defender["blocking_reasons"].is_empty(), "ready fixture becomes selectable exactly at the accepted threshold")
	_check(rune_knight["requirements_met"] and not rune_knight["content_ready"] and not rune_knight["can_select"] and rune_knight["blocking_reasons"] == [&"content_unavailable"], "requirements and content readiness remain independent for another destination")
	_check(_option(exact["options"], &"mg_ar").is_empty(), "directional destination from another origin never leaks into the option list")
	defender["exclusive_skill_ids"].clear()
	defender["blocking_reasons"].append(&"mutated")
	var clean_defender := _option(exact_facade.evolution_options(exact_id)["options"], &"defender")
	_check(clean_defender["exclusive_skill_ids"] == [&"defender_entry"] and clean_defender["blocking_reasons"].is_empty(), "facade option dictionaries and nested arrays are isolated between queries")
	_check(exact_facade.current_profile().revision == before_revision and _read_text(primary_path) == before_text, "evolution_options performs no profile mutation or disk write")
	_check(not exact_facade.evolution_options("missing")["ok"] and exact_facade.evolution_options("missing")["error_code"] == &"invalid_character_id", "unknown character is a query error without creating state")

	var current_directory := root_directory.path_join("current_unavailable")
	_prepare_directory(current_directory)
	var production_catalog := ProfileCatalog.pilot()
	var current_id := _seed_profile(current_directory, production_catalog, ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP, &"defender")
	var current_facade := ProfileFacade.new(ProfileStore.new(current_directory, production_catalog))
	var current_open := current_facade.open_profile()
	var current := _option(current_facade.evolution_options(current_id)["options"], &"defender")
	_check(current_open["ok"] and current["is_current"] and current["requirements_met"] and not current["content_ready"], "current identity remains visible even when its production content is unavailable")
	_check(&"content_unavailable" in current["blocking_reasons"] and &"already_current" in current["blocking_reasons"], "current flag does not hide the independent content-unavailable reason")
	_check(current_facade.current_profile().character_by_id(current_id).evolution_id == &"defender", "read-only query never clears an unavailable persisted identity")

	var run_directory := root_directory.path_join("run_active")
	_prepare_directory(run_directory)
	var run_id := _seed_profile(run_directory, ready_catalog, ProgressionRules.EVOLUTION_MIN_BASE_XP, ProgressionRules.EVOLUTION_MIN_JOB_XP)
	var run_facade := ProfileFacade.new(ProfileStore.new(run_directory, ready_catalog))
	var run_open := run_facade.open_profile()
	var started := run_facade.start_run("e05-s1a-run", run_open["profile"].revision)
	var during_run := _option(run_facade.evolution_options(run_id)["options"], &"defender")
	_check(started["ok"] and not during_run["can_select"] and &"run_active" in during_run["blocking_reasons"], "query reports the run boundary without attempting an evolution transaction")

func _ready_catalog(content_ready: bool) -> ProfileCatalog:
	return ProfileCatalog.pilot({}, {
		&"defender_entry": {
			"allowed_base_classes": [&"swordsman"],
			"category": ProfileCatalog.ACTIVE,
			"wallet": ProfileCatalog.EVOLUTION_WALLET,
			"free_rank": 1,
			"max_purchased_rank": 4,
			"required_evolution_id": &"defender",
			"rank_requirements": {1: {"job_level": 20, "skill_ranks": {}}},
		},
	}, {
		&"defender": {
			"entry_skill_id": &"defender_entry",
			"exclusive_skill_ids": [&"defender_entry"],
			"content_ready": content_ready,
		},
	})

func _definition(
	id: StringName,
	display_name: String,
	origin: StringName,
	branch: StringName,
	affinity: StringName = &""
) -> EvolutionDefinition:
	var definition := EvolutionDefinition.new()
	definition.id = id
	definition.display_name = display_name
	definition.origin_class_id = origin
	definition.branch_kind = branch
	definition.affinity_class_id = affinity
	return definition

func _seed_profile(
	directory: String,
	catalog: ProfileCatalog,
	base_xp: int,
	job_xp: int,
	evolution_id: StringName = &""
) -> String:
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Teste E05", &"swordsman")
	character.base_xp_total = base_xp
	character.job_xp_total = job_xp
	character.evolution_id = evolution_id
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var committed := ProfileStore.new(directory, catalog).commit(profile)
	_check(committed["ok"], "isolated query fixture is durably seeded")
	return character_id

func _option(options: Array, evolution_id: StringName) -> Dictionary:
	for option: Dictionary in options:
		if option["evolution_id"] == evolution_id:
			return option
	return {}

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _prepare_directory(path: String) -> void:
	_cleanup_directory(path)
	DirAccess.make_dir_recursive_absolute(path)

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
