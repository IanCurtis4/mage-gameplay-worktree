extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_check_stable_ids()
	_check_profile_and_alt_isolation()
	_check_run_snapshot_isolation()
	print("Estado persistente E01.1: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_stable_ids() -> void:
	_check(IdentityIds.base_class_ids() == [&"swordsman", &"mage", &"archer"], "base class IDs match the accepted E00 contract")
	_check(IdentityIds.hybrid_evolution_ids() == [&"sp_mg", &"mg_sp", &"sp_ar", &"ar_sp", &"mg_ar", &"ar_mg"], "directional hybrid IDs remain stable")
	var mutable_copy := IdentityIds.hybrid_evolution_ids()
	mutable_copy.clear()
	_check(IdentityIds.hybrid_evolution_ids().size() == 6, "callers cannot mutate the stable identity registry")
	var expected_origins: Dictionary[StringName, StringName] = {
		&"defender": &"swordsman",
		&"berserker": &"swordsman",
		&"elementalist": &"mage",
		&"spiritualist": &"mage",
		&"sentinel": &"archer",
		&"hunter": &"archer",
		&"sp_mg": &"swordsman",
		&"mg_sp": &"mage",
		&"sp_ar": &"swordsman",
		&"ar_sp": &"archer",
		&"mg_ar": &"mage",
		&"ar_mg": &"archer",
	}
	for evolution_id: StringName in expected_origins:
		var origin: StringName = expected_origins[evolution_id]
		_check(IdentityIds.evolution_belongs_to(evolution_id, origin), "%s retains its accepted origin" % evolution_id)
	_check(not IdentityIds.evolution_belongs_to(&"sp_mg", &"mage"), "directional evolution rejects a different valid origin")
	_check(not IdentityIds.evolution_belongs_to(&"unknown", &"") and not IdentityIds.evolution_belongs_to(&"", &"") and not IdentityIds.evolution_belongs_to(&"sp_mg", &"unknown"), "unknown and empty identity pairs are rejected")
	_check(IdentityIds.character_id("profile", 3) == "profile_3" and IdentityIds.run_id("profile", 3) == "profile_3", "profile counters produce deterministic stable IDs")

func _check_profile_and_alt_isolation() -> void:
	var profile := ProfileState.new("00000000-0000-4000-8000-000000000001")
	var first := CharacterState.new(IdentityIds.character_id(profile.profile_id, 1), "Ana", &"swordsman")
	var second := CharacterState.new(IdentityIds.character_id(profile.profile_id, 2), "Bia", &"mage")
	profile.characters = [first, second]
	profile.selected_character_id = first.character_id
	first.attribute_allocations[&"str"] = 4
	first.presets[0]["active_slots"][0] = &"slash"
	first.presets[0]["equipped"][&"weapon"] = &"training_sword"
	_check(second.attribute_allocations[&"str"] == 0, "attribute allocation does not leak between alts")
	_check(second.presets[0]["active_slots"][0] == null and second.presets[0]["equipped"][&"weapon"] == null, "preset and equipment containers do not leak between alts")
	var copied := profile.copy_state()
	first.attribute_allocations[&"str"] = 9
	first.presets[0]["active_slots"][0] = &"dash"
	_check(copied.character_by_id(first.character_id).attribute_allocations[&"str"] == 4, "profile copy owns deep character state")
	_check(copied.character_by_id(first.character_id).presets[0]["active_slots"][0] == &"slash", "profile copy owns deep preset arrays")
	_check(profile.character_by_id("missing") == null and profile.characters.size() == 2, "profile lookup neither creates nor removes characters")

func _check_run_snapshot_isolation() -> void:
	var character := CharacterState.new("profile_1", "Ana", &"swordsman")
	character.base_xp_total = 350
	character.job_xp_total = 80
	character.attribute_allocations[&"str"] = 4
	character.presets[0]["active_slots"][0] = &"slash"
	character.presets[0]["equipped"][&"weapon"] = &"training_sword"
	var snapshot := BuildSnapshot.from_character(character, 3, 2, {&"slash": 2, &"dash": 1})
	var run := RunState.from_build("profile_7", snapshot)
	character.attribute_allocations[&"str"] = 12
	character.presets[0]["active_slots"][0] = &"dash"
	snapshot.skill_ranks[&"slash"] = 5
	_check(run.run_id == "profile_7" and run.character_id == character.character_id, "run references stable IDs instead of persistent objects")
	_check(run.build_snapshot.attribute_allocations[&"str"] == 4 and run.build_snapshot.active_slots[0] == &"slash", "run owns a deep build snapshot")
	_check(run.skill_levels[&"slash"] == 2, "runtime skill ranks are copied from the build snapshot")
	run.skill_levels[&"slash"] = 3
	run.augment_stacks[&"vitality"] = 2
	run.queue_choice()
	_check(character.purchased_skill_ranks.is_empty() and character.base_xp_total == 350, "runtime mutation cannot change persistent progression")
	_check(not character.get_property_list().any(func(property: Dictionary) -> bool: return property["name"] in [&"augment_stacks", &"pending_choices", &"current_offer"]), "character state exposes no augment or reward-choice runtime fields")
	var persistent_build := run.build_snapshot
	_check(not run.select_class(&"mage"), "persistent run rejects the pilot class-switch operation")
	_check(run.run_id == "profile_7" and run.character_id == "profile_1" and run.build_snapshot == persistent_build and run.class_id == &"swordsman", "rejected class switch preserves persistent run identity and snapshot")
	_check(run.skill_levels[&"slash"] == 3 and run.augment_stacks[&"vitality"] == 2 and run.pending_choices == 1, "rejected class switch preserves runtime state")
	run.reset()
	_check(run.skill_levels[&"slash"] == 2 and run.augment_stacks.is_empty() and run.pending_choices == 0, "run reset restores copied build and clears transient state")
	var pilot_run := RunState.new()
	_check(pilot_run.select_class(&"mage") and pilot_run.class_id == &"mage" and pilot_run.skill_levels.has(&"fireball"), "pilot run keeps its legacy class-switch behavior")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
