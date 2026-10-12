extends SceneTree
const TX = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	var path := "res://resources/build_effects/equipment/warden_mail.tres"
	var original := load(path) as EquipmentDefinition
	var restricted := original.duplicate(true) as EquipmentDefinition
	restricted.allowed_evolutions = [&"defender"]
	restricted.take_over_path(path) # Process-local content fixture, never write production Resources.
	var catalog := ProfileCatalog.pilot()
	var effects := BuildContentLoader.pilot()
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_r1/identity_fixture_%d" % Time.get_ticks_usec())
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	_check(facade.create_character("review-create", 0, "Revisao", &"mage")["ok"], "create mage with isolated store")
	var profile := facade.current_profile()
	TX.own(profile, &"warden_mail", catalog)
	_check(store.commit(profile)["ok"], "collection may own equipment of any identity")
	_check(facade.open_profile()["ok"], "refresh isolated profile")
	profile = facade.current_profile()
	var character := profile.characters[0]
	var equipped := character.equipped.duplicate(true)
	equipped[&"torso"] = profile.first_instance_for_definition(&"warden_mail")
	var disk_before := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	var preset: Dictionary = character.presets[0]
	var update := facade.update_preset("review-restricted-equip", profile.revision, character.character_id, 0, preset["active_slots"], preset["passive_slots"], equipped)
	var disk_after := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
	print("REPRO evolution metadata=", catalog.equipment_metadata(&"warden_mail"), " restricted=", restricted.allowed_evolutions, " update=", update.get("ok"), " disk_changed=", disk_before != disk_after)
	_check(not update["ok"] and disk_before == disk_after, "persistent preset rejects equipment restricted to another evolution before save")
	if update["ok"]:
		var start := facade.start_run("review-start", facade.current_profile().revision)
		var state: RunState = start["run_state"]
		print("REPRO start accepted=", start["ok"], " composition=", state.composed_build())
		_check(not start["ok"] or state.composed_build()["ok"], "accepted persistent build must remain composable")
	original.take_over_path(path)
	print("E06 independent review identity: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
