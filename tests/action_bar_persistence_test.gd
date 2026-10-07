extends SceneTree
## Authorized bars/passive migration, using isolated profiles and real purchases.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174333"
const SWORD_ACTIVES: Array[StringName] = [&"slash", &"dash", &"shield_wall", &"provoke", &"perseverance", &"piercing_shout", &"fury"]
const SWORD_PASSIVES: Array[StringName] = [&"swordsman_resistance", &"vigor", &"blood_thirst"]
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/action_bar_persistence_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	_migration_and_codec()
	await _facade_and_run()
	_passive_identities_and_pruning()
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
	print("Action bars persistence: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({&"training_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"], "starter": true}})

func _character(base: StringName, evolution: StringName = &"") -> CharacterState:
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Barras", base)
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.evolution_id = evolution
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP if evolution.is_empty() else ProgressionRules.MAX_JOB_XP
	return character

func _snapshot(character: CharacterState, catalog: ProfileCatalog) -> BuildSnapshot:
	var summary := CharacterProgression.summary(character, catalog)
	return BuildSnapshot.from_character(character, summary["base_level"], summary["job_level"], summary["effective_skill_ranks"], catalog.skill_ids_for_identity(character.base_class_id, character.evolution_id), catalog)

func _migration_and_codec() -> void:
	var catalog := _catalog()
	var character := _character(&"swordsman")
	character.granted_skill_ranks = {&"slash": 1, &"dash": 1, &"swordsman_resistance": 1}
	for id: StringName in SWORD_ACTIVES + SWORD_PASSIVES:
		_check(CharacterProgression.learn_skill(character, catalog, id)["ok"], "legacy fixture purchases %s legally" % id)
	character.equipped[&"weapon"] = &"training_sword"
	for preset: Dictionary in character.presets:
		preset["equipped"][&"weapon"] = &"training_sword"
	character.presets[0]["active_slots"] = [&"slash", null, &"dash", null, &"shield_wall"]
	character.presets[1]["active_slots"] = [null, &"provoke", null, &"perseverance", null]
	character.presets[0]["passive_slots"] = [&"swordsman_resistance", &"vigor"]
	character.selected_preset = 1
	character.extension_fields["future_cosmetic"] = "preservado"
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	profile.equipment_collection.append(&"training_sword")
	var encoded := ProfileCodec.encode(profile, catalog)
	_check(encoded["ok"], "legacy valid profile encodes")
	if not encoded["ok"]:
		return
	var raw: Dictionary = encoded["data"].duplicate(true)
	raw["characters"][0].erase("action_slots")
	var decoded := ProfileCodec.decode(JSON.stringify(raw), catalog)
	_check(decoded["ok"], "schema2 missing optional bar migrates")
	if not decoded["ok"]:
		return
	var restored: CharacterState = decoded["profile"].characters[0]
	_check(restored.action_slots.size() == 24 and restored.action_slots.slice(0, 5) == character.presets[1]["active_slots"], "selected legacy bar preserves order and holes")
	_check(restored.presets == character.presets and restored.selected_preset == 1, "both legacy presets preserved")
	_check(restored.granted_skill_ranks == character.granted_skill_ranks and restored.purchased_skill_ranks == character.purchased_skill_ranks, "grants and purchases unchanged")
	_check(restored.equipped == character.equipped and decoded["profile"].equipment_collection == profile.equipment_collection, "inventory and equipment unchanged")
	_check(restored.extension_fields["future_cosmetic"] == "preservado", "unrelated future character fields survive")
	_check(restored.extension_fields.get("action_slots") == null, "recognized bar is not a duplicate extension")
	_check(_snapshot(restored, catalog).has_passive(&"blood_thirst"), "unselected learned passive becomes automatic after migration")
	var before_wallet := CharacterProgression.summary(character, catalog)
	var after_wallet := CharacterProgression.summary(restored, catalog)
	_check(before_wallet == after_wallet, "migration does not grant or refund points")
	# Every position, including the second row's final slot, survives JSON and reload.
	for index: int in 24:
		restored.action_slots = ActionBarLayout.empty()
		restored.action_slots[index] = &"slash"
		decoded["profile"].characters[0] = restored
		var roundtrip := ProfileCodec.encode(decoded["profile"], catalog)
		_check(roundtrip["ok"], "slot%d encodes" % index)
		if not roundtrip["ok"]:
			continue
		var reread := ProfileCodec.decode(roundtrip["text"], catalog)
		_check(reread["ok"] and reread["profile"].characters[0].action_slots == restored.action_slots, "slot%d roundtrip exact" % index)
	var copy := restored.copy_state()
	copy.action_slots[23] = null
	_check(restored.action_slots[23] == &"slash", "character copy owns its own layout")
	restored.action_slots = ActionBarLayout.empty()
	var cleared := ProfileCodec.encode(decoded["profile"], catalog)
	_check(cleared["ok"] and ProfileCodec.decode(cleared["text"], catalog)["profile"].characters[0].action_slots == ActionBarLayout.empty(), "explicitly cleared24 never refills from old preset")
	var invalid_cases: Array[Array] = []
	for invalid_id: StringName in [&"blood_thirst", &"fireball", &"terrifying_shout", &"defender_counterstroke"]:
		var invalid := ActionBarLayout.empty()
		invalid[0] = invalid_id
		invalid_cases.append(invalid)
	var duplicate := ActionBarLayout.empty()
	duplicate[0] = &"slash"
	duplicate[23] = &"slash"
	invalid_cases.append(duplicate)
	invalid_cases.append([null])
	for invalid: Array in invalid_cases:
		var damaged: Dictionary = cleared["data"].duplicate(true)
		damaged["characters"][0]["action_slots"] = invalid
		_check(not ProfileCodec.decode(JSON.stringify(damaged), catalog)["ok"], "codec rejects illegal layout without partial acceptance")

func _facade_and_run() -> void:
	var catalog := _catalog()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile()["ok"], "isolated profile opens")
	var created := facade.create_character("bar-create", facade.current_profile().revision, "Espada", &"swordsman")
	_check(created["ok"], "facade creates actual character")
	var id: String = created["character_id"]
	_check(facade.grant_playtest_progression("bar-max", facade.current_profile().revision, id, &"max_levels")["ok"], "admin grants XP only")
	for skill: StringName in SWORD_ACTIVES + SWORD_PASSIVES:
		_check(facade.learn_skill("bar-buy-%s" % skill, facade.current_profile().revision, id, skill)["ok"], "facade purchases %s" % skill)
	var other := facade.create_character("bar-other", facade.current_profile().revision, "Mago", &"mage")
	_check(other["ok"], "second character exists")
	var other_id: String = other["character_id"]
	_check(facade.select_character("bar-select", facade.current_profile().revision, id)["ok"], "run selection restored")
	var before := facade.current_profile()
	var slots := ActionBarLayout.empty()
	for index: int in SWORD_ACTIVES.size():
		slots[index] = SWORD_ACTIVES[index]
	slots[23] = slots[6]
	slots[6] = null
	_check(facade.update_action_slots("bar-save", before.revision, id, slots)["ok"], "seventh learned active legal, final Alt slot available")
	var after := facade.current_profile()
	var before_character := before.character_by_id(id)
	var after_character := after.character_by_id(id)
	_check(before_character.purchased_skill_ranks == after_character.purchased_skill_ranks and before_character.granted_skill_ranks == after_character.granted_skill_ranks and before_character.attribute_allocations == after_character.attribute_allocations, "organization never edits build or ranks")
	_check(before_character.presets == after_character.presets and before.equipment_collection == after.equipment_collection and before_character.equipped == after_character.equipped, "organization never edits presets/inventory/equipment")
	_check(CharacterProgression.summary(before_character, catalog) == CharacterProgression.summary(after_character, catalog), "organization does not grant/refund wallet")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(reloaded.open_profile()["ok"] and reloaded.current_profile().character_by_id(id).action_slots == slots, "bar survives actual disk reload")
	var revision := facade.current_profile().revision
	for invalid_id: StringName in [&"blood_thirst", &"fireball", &"terrifying_shout", &"defender_counterstroke"]:
		var invalid := slots.duplicate()
		invalid[0] = invalid_id
		_check(not facade.update_action_slots("bar-bad-%s" % invalid_id, revision, id, invalid)["ok"] and facade.current_profile().revision == revision, "facade rejects passive/foreign/unlearned/class gate atomically")
	var duplicated := slots.duplicate()
	duplicated[22] = &"slash"
	_check(not facade.update_action_slots("bar-duplicate", revision, id, duplicated)["ok"], "duplicate skill cannot acquire separate cooldown shortcut")
	_check(not facade.update_action_slots("bar-short", revision, id, [null])["ok"], "wrong size rejected")
	var started := facade.start_run("bar-start", revision)
	_check(started["ok"], "run starts with learned library despite empty old active preset")
	if not started["ok"]:
		return
	var run: RunState = started["run_state"]
	var initial_snapshot := run.build_snapshot.copy_snapshot()
	_check(run.build_snapshot.learned_skill_ids(ProfileCatalog.ACTIVE).size() == 7, "run has all seven learned active skills")
	_check(run.build_snapshot.learned_skill_ids(ProfileCatalog.PASSIVE).size() == 3 and run.build_snapshot.passive_slots == [null, null], "three learned passives automatically active without slots")
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1280, 720), [], 22.0)
	var player := PlayerActor.new()
	root.add_child(player)
	player.configure(nav, run)
	player.set_process(false)
	player.health.current_hp -= 7.0
	player.current_sp -= 5.0
	player.slash_cooldown = 2.0
	var hp := player.health.current_hp
	var sp := player.current_sp
	var changed := ActionBarLayout.move(slots, 0, 12)
	var current_revision := facade.current_profile().revision
	_check(facade.update_action_slots("bar-live", current_revision, id, changed)["ok"], "same-character layout edit allowed during run")
	_check(not facade.update_action_slots("bar-other-live", facade.current_profile().revision, other_id, ActionBarLayout.empty())["ok"], "other-character edit rejected during run")
	_check(not facade.learn_skill("bar-live-buy", facade.current_profile().revision, id, &"brutal_strike")["ok"] and not facade.respec_skills("bar-live-respec", facade.current_profile().revision, id)["ok"], "bar operation does not unlock live build editing")
	_check(run.build_snapshot.action_slots == initial_snapshot.action_slots and run.build_snapshot.skill_ranks == initial_snapshot.skill_ranks, "facade cannot mutate copied run snapshot")
	# Even a copied layout cannot carry modifiers into the canonical stat recalc.
	run.build_snapshot.action_slots = changed.duplicate()
	player.apply_run_modifiers(run)
	_check(is_equal_approx(player.health.current_hp, hp) and is_equal_approx(player.current_sp, sp), "canonical stat recalc after layout does not heal or refill")
	_check(is_equal_approx(player.slash_cooldown, 2.0) and player.available_skill_ids().size() == 7, "layout changes neither cooldown nor library")
	_check(run.build_snapshot.stat_breakdown().value(&"max_hp") == initial_snapshot.stat_breakdown().value(&"max_hp"), "bar carries no stat modifier")
	player.free()
	await process_frame
	_check(facade.end_run("bar-end", facade.current_profile().revision, started["run_id"], &"abandoned")["ok"], "run closes normally")
	var frozen_profile := facade.current_profile().character_by_id(id)
	_check(facade.respec_skills("bar-respec", facade.current_profile().revision, id)["ok"], "respec uses existing progression transaction")
	var respecced := facade.current_profile().character_by_id(id)
	_check(respecced.action_slots == ActionBarLayout.empty() and _snapshot(respecced, catalog).learned_skill_ids(ProfileCatalog.PASSIVE).is_empty(), "respec prunes stale bar and automatic passive effects")
	_check(frozen_profile.purchased_skill_ranks.size() == 10, "older returned profile remains immutable value")
	_check(facade.grant_playtest_progression("bar-admin-after", facade.current_profile().revision, id, &"max_levels")["ok"] and facade.current_profile().character_by_id(id).purchased_skill_ranks.is_empty(), "admin XP does not relearn removed passives")

func _passive_identities_and_pruning() -> void:
	var catalog := ProfileCatalog.pilot()
	var identities: Array[Array] = [[&"swordsman", &""], [&"mage", &""], [&"archer", &""], [&"swordsman", &"defender"], [&"swordsman", &"berserker"], [&"mage", &"elementalist"], [&"mage", &"spiritualist"], [&"mage", &"mg_ar"], [&"archer", &"sentinel"]]
	for identity: Array in identities:
		var character := _character(identity[0], identity[1])
		var expected: Array[StringName] = []
		for skill: StringName in catalog.skill_ids_for_identity(identity[0], identity[1]):
			if catalog.skill_metadata(skill)["category"] == ProfileCatalog.PASSIVE:
				_check(CharacterProgression.learn_skill(character, catalog, skill)["ok"], "legal passive purchase for %s/%s" % identity)
				expected.append(skill)
		var snapshot := _snapshot(character, catalog)
		_check(snapshot.passive_slots == [null, null] and snapshot.learned_skill_ids(ProfileCatalog.PASSIVE) == expected, "all base/evolution learned passives derive without equips")
		for skill: StringName in expected:
			_check(snapshot.has_passive(skill), "automatic passive effective %s" % skill)
		_check(not snapshot.has_passive(&"fireball") and not snapshot.has_passive(&"missing_skill"), "category and unknown ids never become passives")
		var restricted := snapshot.copy_snapshot()
		restricted.library_skill_ids = [&"slash"]
		_check(restricted.learned_skill_ids(ProfileCatalog.PASSIVE).is_empty(), "explicit identity library restricts passives")
		if not identity[1].is_empty():
			var gated := snapshot.copy_snapshot()
			gated.job_level = 20
			for skill: StringName in expected:
				if catalog.skill_metadata(skill)["wallet"] == ProfileCatalog.EVOLUTION_WALLET:
					_check(not gated.has_passive(skill), "below-job evolution passive remains locked despite fixture rank")
	# Branch switch strips old evolution while keeping learned base passives.
	var defender := _character(&"swordsman", &"defender")
	for skill: StringName in [&"swordsman_resistance", &"vigor", &"blood_thirst", &"defender_watch", &"defender_guard_return", &"defender_anchor"]:
		_check(CharacterProgression.learn_skill(defender, catalog, skill)["ok"], "switch fixture legal purchase")
	defender.action_slots = ActionBarLayout.empty()
	defender.action_slots[23] = &"defender_anchor"
	_check(CharacterProgression.change_evolution(defender, catalog, &"berserker")["ok"], "admin branch switch uses canonical progression")
	var switched := _snapshot(defender, catalog)
	_check(defender.action_slots[23] == null and not switched.has_passive(&"defender_watch") and switched.has_passive(&"vigor"), "class lock prunes old bar/passives but retains base")
	_check(not CharacterProgression.learn_skill(defender, catalog, &"defender_watch")["ok"], "foreign evolution passive cannot be repurchased")
	var invalid := switched.copy_snapshot()
	invalid.skill_ranks[&"defender_watch"] = 1
	_check(not invalid.has_passive(&"defender_watch"), "foreign rank injection cannot activate a passive")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
