extends SceneTree
const TX = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_identity_edges()
	_conflict_edges()
	print("E06 independent persistence edges: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _identity_edges() -> void:
	var path := "res://resources/build_effects/equipment/warden_mail.tres"
	var original := load(path) as EquipmentDefinition
	var fixture := original.duplicate(true) as EquipmentDefinition
	fixture.allowed_evolutions = [&"defender"]
	fixture.take_over_path(path)
	_reset_fixture_catalogs()
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(_directory("identity"), catalog)
	var facade := ProfileFacade.new(store)
	_check(facade.create_character("create", 0, "Revisao", &"swordsman")["ok"], "create identity fixture")
	var profile := facade.current_profile()
	TX.own(profile, fixture.id, catalog)
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "own restricted item without equipping")
	profile = facade.current_profile()
	var character := profile.characters[0]
	_check(profile.first_instance_for_definition(fixture.id) not in facade.available_build_options(character.character_id)["equipment_by_slot"][&"torso"], "unevolved same origin does not see restricted item")
	var data: Dictionary = ProfileCodec.encode(profile, catalog)["data"]
	data["characters"][0]["presets"][1]["equipped"]["torso"] = String(profile.first_instance_for_definition(fixture.id))
	_check(not ProfileCodec.decode(JSON.stringify(data), catalog)["ok"], "decode rejects illegal restricted item in inactive preset")
	character.evolution_id = &"defender"
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "legal evolution fixture")
	profile = facade.current_profile()
	character = profile.characters[0]
	_check(profile.first_instance_for_definition(fixture.id) in facade.available_build_options(character.character_id)["equipment_by_slot"][&"torso"], "matching evolution exposes item")
	var equipped := character.equipped.duplicate(true)
	equipped[&"torso"] = profile.first_instance_for_definition(fixture.id)
	var preset: Dictionary = character.presets[0]
	_check(facade.update_preset("legal", profile.revision, character.character_id, 0, preset["active_slots"], preset["passive_slots"], equipped)["ok"], "legal restricted item commits")
	var started := facade.start_run("start", facade.current_profile().revision)
	_check(started["ok"] and started["run_state"].effects_valid(), "accepted build starts with valid composition")
	original.take_over_path(path)
func _conflict_edges() -> void:
	var paths := ["res://resources/build_effects/equipment/warden_mail.tres", "res://resources/build_effects/equipment/prismatic_charm.tres"]
	var originals: Array[EquipmentDefinition] = []
	var fixtures: Array[EquipmentDefinition] = []
	for index: int in paths.size():
		var original := load(paths[index]) as EquipmentDefinition
		originals.append(original)
		var fixture := original.duplicate(true) as EquipmentDefinition
		var effect := EffectDefinition.new()
		effect.id = StringName("review_edge_%d" % index)
		effect.family_id = effect.id
		effect.axis = &"max_hp"
		effect.unit = &"points"
		effect.magnitude = 10.0
		effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
		effect.conflict_group = &"review_edge_exclusive"
		fixture.effects = [effect]
		fixture.take_over_path(paths[index])
		fixtures.append(fixture)
	_reset_fixture_catalogs()
	var catalog := ProfileCatalog.pilot()
	var directory := _directory("conflict")
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	_check(facade.create_character("create", 0, "Revisao", &"mage")["ok"], "create conflict fixture")
	var profile := facade.current_profile()
	for definition_id: StringName in [&"warden_mail", &"prismatic_charm"]: TX.own(profile, definition_id, catalog)
	var character := profile.characters[0]
	character.equipped[&"torso"] = profile.first_instance_for_definition(&"warden_mail")
	character.equipped[&"accessory_1"] = profile.first_instance_for_definition(&"prismatic_charm")
	character.presets[0]["equipped"] = character.equipped.duplicate(true)
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "load old conflicting preferences through codec")
	profile = facade.current_profile()
	var disk := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	var rejected := facade.start_run("bad-start", profile.revision)
	var after := facade.current_profile()
	_check(not rejected["ok"] and rejected["error_code"] == &"effect_conflict", "start rejects old exclusive conflict")
	_check(after.revision == profile.revision and after.next_run_counter == profile.next_run_counter and after.lifetime_stats == profile.lifetime_stats and after.reward_session == null, "rejected start preserves revision counter stats and session")
	_check(disk == FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)), "rejected start preserves durable bytes")
	character = after.characters[0]
	var repaired := character.equipped.duplicate(true)
	repaired[&"accessory_1"] = profile.first_instance_for_definition(&"traveler_charm")
	var preset: Dictionary = character.presets[0]
	_check(facade.update_preset("repair", after.revision, character.character_id, 0, preset["active_slots"], preset["passive_slots"], repaired)["ok"], "legal repair remains possible after rejected start")
	var started := facade.start_run("good-start", facade.current_profile().revision)
	_check(started["ok"] and started["run_state"].effects_valid() and facade.current_profile().next_run_counter == profile.next_run_counter + 1, "repaired build starts once with valid effects and one counter increment")
	for index: int in paths.size():
		originals[index].take_over_path(paths[index])
func _directory(label: String) -> String:
	return ProjectSettings.globalize_path("res://.godot/verification/e06_r1/resume_independent/fixture_%s_%d" % [label, Time.get_ticks_usec()])
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _reset_fixture_catalogs() -> void:
	# These adversarial fixtures replace registered Resource paths inside one process.
	# Production catalogs are immutable; each fixture needs a fresh cache boundary.
	ProfileCatalog._default_pilot = null
	BuildContentLoader._catalog_cache.clear()
