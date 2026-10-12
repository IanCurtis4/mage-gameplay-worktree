extends SceneTree
const TX = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	var armor_path := "res://resources/build_effects/equipment/warden_mail.tres"
	var charm_path := "res://resources/build_effects/equipment/prismatic_charm.tres"
	var old_armor := load(armor_path) as EquipmentDefinition
	var old_charm := load(charm_path) as EquipmentDefinition
	var armor := old_armor.duplicate(true) as EquipmentDefinition
	var charm := old_charm.duplicate(true) as EquipmentDefinition
	armor.effects = [_exclusive(&"armor_effect")]
	charm.effects = [_exclusive(&"charm_effect")]
	armor.take_over_path(armor_path)
	charm.take_over_path(charm_path)
	var catalog := ProfileCatalog.pilot()
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_r1/conflict_fixture_%d" % Time.get_ticks_usec())
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	_check(facade.create_character("review-create", 0, "Revisao", &"mage")["ok"], "isolated character")
	var profile := facade.current_profile()
	for definition_id: StringName in [armor.id, charm.id]: TX.own(profile, definition_id, catalog)
	_check(store.commit(profile)["ok"] and facade.open_profile()["ok"], "collection accepts conflicting items independently")
	profile = facade.current_profile()
	var character := profile.characters[0]
	var equipped := character.equipped.duplicate(true)
	equipped[&"torso"] = profile.first_instance_for_definition(armor.id)
	equipped[&"accessory_1"] = profile.first_instance_for_definition(charm.id)
	var disk_before := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	var preset: Dictionary = character.presets[0]
	var update := facade.update_preset("review-conflicting-equip", profile.revision, character.character_id, 0, preset["active_slots"], preset["passive_slots"], equipped)
	var disk_after := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	print("REPRO conflict update=", update.get("ok"), " disk_changed=", disk_before != disk_after)
	_check(not update["ok"] and disk_before == disk_after, "exclusive equipment combination rejects entire preset before save")
	if update["ok"]:
		var start := facade.start_run("review-start", facade.current_profile().revision)
		var state: RunState = start["run_state"]
		print("REPRO conflict start=", start["ok"], " composition=", state.composed_build())
		_check(not start["ok"] or state.composed_build()["ok"], "accepted persistent build must compose without exclusive conflict")
	old_armor.take_over_path(armor_path)
	old_charm.take_over_path(charm_path)
	print("E06 independent review preset conflict: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _exclusive(id: StringName) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = id
	effect.axis = &"max_hp"
	effect.unit = &"points"
	effect.magnitude = 10.0
	effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
	effect.conflict_group = &"review_exclusive_group"
	return effect
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
