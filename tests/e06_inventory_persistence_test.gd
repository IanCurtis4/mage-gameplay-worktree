extends SceneTree
const TX = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_identity()
	_conflicts()
	print("E06 persistence guards: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _identity() -> void:
	var path := "res://resources/build_effects/equipment/warden_mail.tres"
	var original := load(path) as EquipmentDefinition
	var restricted := original.duplicate(true) as EquipmentDefinition
	restricted.allowed_evolutions = [&"defender"]
	restricted.take_over_path(path)
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.equipment_metadata(restricted.id)["allowed_evolutions"] == [&"defender"], "resource evolution restriction preserved")
	_check(catalog.equipment_is_allowed(restricted.id, &"torso", &"swordsman", &"defender") and not catalog.equipment_is_allowed(restricted.id, &"torso", &"swordsman", &"berserker"), "correct evolution accepted and sibling rejected")
	var store := ProfileStore.new(_directory("identity"), catalog)
	var facade := ProfileFacade.new(store)
	_check(facade.create_character("create", 0, "Defensor", &"swordsman")["ok"], "create isolated character")
	var profile := facade.current_profile()
	var character := profile.characters[0]
	character.evolution_id = &"defender"
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	TX.own(profile, restricted.id, catalog)
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "legal evolved profile")
	profile = facade.current_profile()
	character = profile.characters[0]
	var equipped := character.equipped.duplicate(true)
	equipped[&"torso"] = profile.first_instance_for_definition(restricted.id)
	var preset: Dictionary = character.presets[0]
	_check(facade.update_preset("equip", profile.revision, character.character_id, 0, preset["active_slots"], preset["passive_slots"], equipped)["ok"], "legal restricted equipment persists")
	_check(profile.first_instance_for_definition(restricted.id) in facade.available_build_options(character.character_id)["equipment_by_slot"][&"torso"], "legal equipment remains in menu options")
	var started := facade.start_run("start", facade.current_profile().revision)
	_check(started["ok"] and started["run_state"].effects_valid(), "legal persistent equipment composes at start")
	var invalid := profile.copy_state()
	invalid.characters[0].evolution_id = &"berserker"
	invalid.characters[0].presets[1]["equipped"][&"torso"] = profile.first_instance_for_definition(restricted.id)
	_check(not ProfileCodec.encode(invalid, catalog)["ok"], "inactive preset cannot bypass evolution restriction")
	original.take_over_path(path)
func _conflicts() -> void:
	var paths := ["res://resources/build_effects/equipment/warden_mail.tres", "res://resources/build_effects/equipment/prismatic_charm.tres"]
	var originals: Array[EquipmentDefinition] = []
	var fixtures: Array[EquipmentDefinition] = []
	for index: int in paths.size():
		var original := load(paths[index]) as EquipmentDefinition
		originals.append(original)
		var item := original.duplicate(true) as EquipmentDefinition
		var effect := EffectDefinition.new()
		effect.id = StringName("guard_%d" % index)
		effect.family_id = effect.id
		effect.kind = EffectDefinition.Kind.SKILL_RULE
		effect.handler_id = EffectDefinition.Handler.PROJECTILE_COUNT
		effect.axis = &"projectile_count"
		effect.unit = &"count"
		effect.magnitude = 1.0
		effect.limit = 16.0
		effect.target_skill_ids = [&"fire_spear"]
		effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
		effect.conflict_group = &"guard_group"
		item.effects = [effect]
		item.take_over_path(paths[index])
		fixtures.append(item) # Keep process-local overrides alive throughout the scenario.
	var catalog := ProfileCatalog.pilot()
	var directory := _directory("conflict")
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	_check(facade.create_character("create", 0, "Mago", &"mage")["ok"], "isolated conflict character")
	var profile := facade.current_profile()
	var character := profile.characters[0]
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	for definition_id: StringName in [&"warden_mail", &"prismatic_charm"]: TX.own(profile, definition_id, catalog)
	character.presets[1]["equipped"][&"torso"] = profile.first_instance_for_definition(&"warden_mail")
	character.presets[1]["equipped"][&"accessory_1"] = profile.first_instance_for_definition(&"prismatic_charm")
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "unlearned skill keeps equipment effects inactive")
	var disk := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	var learned := facade.learn_skill("learn", facade.current_profile().revision, character.character_id, &"fire_spear")
	_check(not learned["ok"] and learned["error_code"] == &"effect_conflict" and disk == FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)), "learning cannot activate conflict in inactive preset or change disk")
	profile = facade.current_profile()
	profile.characters[0].purchased_skill_ranks[&"fire_spear"] = 1
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "simulate previously saved conflicting preferences")
	disk = FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	print("Guard learn result: ", learned)
	var selected := facade.select_preset("select", facade.current_profile().revision, character.character_id, 1)
	_check(not selected["ok"] and selected["error_code"] == &"effect_conflict", "select preset blocks an existing conflict")
	var started := facade.start_run("start", facade.current_profile().revision)
	_check(not started["ok"] and started["error_code"] == &"effect_conflict" and disk == FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)), "start blocks invalid preferences without writing a reward session")
	print("Guard select/start results: ", selected.get("error_code"), " / ", started.get("error_code"))
	for index: int in paths.size():
		originals[index].take_over_path(paths[index])
func _directory(label: String) -> String:
	return ProjectSettings.globalize_path("res://.godot/verification/e06_r1/author_%s_%d" % [label, Time.get_ticks_usec()])
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
