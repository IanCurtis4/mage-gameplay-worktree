extends SceneTree
## Published resources retain old exemplars and preserve approved build mechanics.
const Publication = preload("res://tools/content/publication_bundle.gd")
const Directions = preload("res://tools/content/directions_bundle.gd")
const Transform = preload("res://tools/content/transform_bundle.gd")
const IDENTITIES := ["swordsman", "mage", "archer", "defender", "berserker", "elementalist", "spiritualist", "sentinel", "hunter", "mg_ar"]
const SOURCE_DIGEST := "b2480230ac8691fe155976ce4e311cfef233e6b32618a3ebd8a7c87fbd0658fd"
var checks := 0
var failures := 0
var mapping: Dictionary
var active: BuildEffectCatalog
var source: BuildEffectCatalog
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var text: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/transform_texts.json"))
	var original := ContentAuthoring.compile_bundle(Transform.entries(), text)
	var publication := Publication.compile()
	var loaded := BuildContentLoader.load_catalog()
	_check(original["ok"] and publication["ok"] and loaded["ok"], "offline source, publication and active loader all validate")
	if not original["ok"] or not publication["ok"] or not loaded["ok"]: print([original, publication, loaded]); quit(1); return
	source = original["catalog"]; active = loaded["catalog"]; mapping = publication["id_mapping"]
	_check(original["mechanical_digest"] == SOURCE_DIGEST and publication["source_mechanical_digest"] == SOURCE_DIGEST, "publication cannot change frozen 69 recipe digest")
	_check(mapping.size() == 12 and publication["entries"].size() == 83, "twelve explicit mappings plus legacy equipment/mobs produce83 resources")
	_check(active.ids(&"equipment").size() == 37 and active.ids(&"augment").size() == 31 and active.ids(&"card").size() == 6 and active.mob_catalog().ids().size() == 8 and BuildContentLoader.definitions(&"set").size() == 1, "37 equipment31 augments6 cards8 mobs1set active")
	var native_entries: Array[Dictionary] = []
	for entry: Dictionary in publication["entries"]:
		var expected: Resource = entry["definition"]
		var actual: Resource
		if entry["origin"] == &"mob": actual = active.mob_catalog().get_definition(expected.id)
		elif entry["origin"] == &"set": actual = active.get_set(expected.id)
		else: actual = active.get_definition(entry["origin"], expected.id)
		if actual != null: native_entries.append({"origin": entry["origin"], "definition": actual, "purpose": entry["purpose"]})
		_check(actual != null and _normalize(actual) == _normalize(expected), "native active resource matches publication %s/%s" % [entry["origin"], expected.id])
	var native := ContentAuthoring.prepare(native_entries)
	_check(native["ok"] and native["mechanical_digest"] == publication["mechanical_digest"], "native complete83 bundle has exact canonical publication fingerprint")
	_legacy_definitions()
	_build_equivalence()
	_profile_preservation()
	_coexistence()
	_acquisitions()
	_identity_restrictions()
	_stage_pool()
	print("E06 publication: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _normalize(value: Variant, reverse_mapping: bool = false) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[_normalize(key, reverse_mapping)] = _normalize(value[key], reverse_mapping)
		return result
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for item: Variant in value: result.append(_normalize(item, reverse_mapping))
		return result
	if value is Resource:
		var result: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			var name: String = property["name"]
			if int(property["usage"]) & PROPERTY_USAGE_STORAGE and name not in ["script", "resource_name", "resource_local_to_scene", "resource_path"]: result[name] = _normalize(value.get(name), reverse_mapping)
		return result
	if value is String or value is StringName:
		if reverse_mapping:
			for old: Variant in mapping:
				if String(value) == String(mapping[old]): return String(old)
		return String(value)
	if value is float: return snappedf(value, 0.000000000001) # Native decimal0.45 and0.15*3 differ below storage precision.
	return value
func _legacy_definitions() -> void:
	var profile_catalog := ProfileCatalog.pilot()
	_check(profile_catalog.is_valid() and ProfileState.SCHEMA_VERSION == 6 and ProfileState.CATALOG_VERSION == 13, "additive publication keeps valid catalog13/schema6")
	var starters: Array[StringName] = []
	for id: StringName in active.ids(&"equipment"):
		var item := active.get_definition(&"equipment", id) as EquipmentDefinition
		if item.starter: starters.append(id)
		_check(item.metadata() == profile_catalog.equipment_metadata(id), "profile metadata has same active source %s" % id)
		_check(item.item_level == 1 and item.origin_id == &"demo_arena", "published ilvl1 origin explicit")
		_check(item.socket_capacity >= 0 and item.socket_capacity <= 4 and (item.socket_capacity == 0 or item.item_kind in [&"weapon", &"armor", &"shield"]), "socket eligibility excludes focus/jewelry")
	_check(starters.size() == 5 and starters.has(&"starter_blade") and starters.has(&"starter_staff") and starters.has(&"starter_bow") and starters.has(&"traveler_vest") and starters.has(&"traveler_charm"), "five historical starters are the only defaults")
	for old: StringName in mapping:
		var previous := active.get_definition(&"equipment", old) as EquipmentDefinition
		var published := active.get_definition(&"equipment", mapping[old]) as EquipmentDefinition
		_check(previous != null and previous.effects.is_empty() and previous.set_id.is_empty(), "historical exemplar retains neutral effects/set %s" % old)
		_check(published != null and not published.effects.is_empty() and not published.starter, "new equivalent has recipe without replacing starter %s" % old)
		for field: String in ["slot", "item_kind", "hand_usage", "quality_id", "item_level", "origin_id", "socket_capacity", "allowed_origins", "allowed_evolutions"]:
			_check(_normalize(previous.get(field)) == _normalize(published.get(field)), "mapped equipment preserves approved physical metadata %s/%s" % [old, field])
	for origin: StringName in IdentityIds.base_class_ids():
		var initial := profile_catalog.starter_equipment(origin)
		_check(initial[&"torso"] == &"traveler_vest" and initial[&"accessory_1"] == &"traveler_charm" and not String(initial[&"main_hand"]).begins_with("arena_"), "new character continues receiving old trio")
	for card_id: StringName in active.ids(&"card"):
		var card := active.get_definition(&"card", card_id) as CardDefinition
		var species := active.mob_catalog().get_definition(card.mob_base_id)
		_check(not card.effects.is_empty() and species != null, "active ephemeral card has valid recipe/species binding")
func _build_equivalence() -> void:
	for identity: String in IDENTITIES:
		for branch: int in 2:
			var old := Directions.comparison(identity, branch, source)
			var current := Publication.comparison(identity, branch, active, source)
			_check(old["ok"] and current["ok"], "old and published blueprints compose %s/%d" % [identity, branch])
			if not old["ok"] or not current["ok"]: print([old, current]); continue
			var before: Dictionary = old["composed"]; var after: Dictionary = current["composed"]
			_check(before["breakdown"].values() == after["breakdown"].values(), "full published build preserves all derived stats")
			for field: String in ["skill_ranks", "skill_rules", "kit_policies", "procs", "item_grants", "unique_effects", "inactive", "provenance", "conflicts"]:
				_check(_normalize(before[field]) == _normalize(after[field], true), "same mechanics and causal origins after remap %s" % field)
			_check(after["inactive"].is_empty(), "publication cannot silently deactivate chosen recipe")
			_check(old["purchased_ranks"] == current["purchased_ranks"] and old["snapshot"].action_slots == current["snapshot"].action_slots, "publication preserves wallets and layout")
			var snapshot: BuildSnapshot = current["snapshot"]
			for id: StringName in snapshot.equipment_instances:
				var instance: EquipmentInstance = snapshot.equipment_instances[id]
				var previous: EquipmentInstance = old["snapshot"].equipment_instances[id]
				_check(instance.instance_id == previous.instance_id and instance.definition_id == mapping.get(previous.definition_id, previous.definition_id), "only blueprint definition mapping changes instance selection")
			for skill: StringName in before["skill_ranks"]:
				var rank: int = before["skill_ranks"][skill]
				var first := SkillEffectResolver.capture(skill, rank, before)
				var second := SkillEffectResolver.capture(skill, rank, after)
				_check(first["ok"] and second["ok"] and _normalize(first) == _normalize(second, true), "published skill capture unchanged %s" % skill)
			var old_sets: Array = before["provenance"].filter(func(row: Dictionary) -> bool: return row["origin"] == &"set")
			var new_sets: Array = after["provenance"].filter(func(row: Dictionary) -> bool: return row["origin"] == &"set")
			_check(not old_sets.is_empty() and _normalize(old_sets) == _normalize(new_sets, true), "same real set threshold survives remapped member")
func _profile_preservation() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_publication/profile_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(ProfileStore.new(directory))
	_check(facade.create_character("old-first", 0, "Mago antigo", &"mage")["ok"], "isolated profile initial old mage")
	_check(facade.create_character("old-second", facade.current_profile().revision, "Outro mago", &"mage")["ok"], "second character shares old collection")
	var profile := facade.current_profile()
	var profile_catalog := ProfileCatalog.pilot()
	for old: StringName in mapping:
		if profile.first_instance_for_definition(old).is_empty(): _check(profile.add_equipment_instance(old, profile_catalog.equipment_metadata(old))["ok"], "historical acquisition added exactly once")
	var armor := profile.first_instance_for_definition(&"warden_mail")
	profile.characters[0].presets[1]["equipped"][&"torso"] = armor
	profile.settings = {"custom": ["preserve", 7.0]}; profile.extension_fields["opaque"] = {"keep": true}
	var encoded := ProfileCodec.encode(profile)
	_check(encoded["ok"], "published catalog accepts unchanged old profile")
	if not encoded["ok"]: print(encoded); return
	var decoded := ProfileCodec.decode(encoded["text"])
	_check(decoded["ok"] and not decoded.get("migrated", false), "catalog addition does not trigger schema migration")
	if not decoded["ok"]: return
	var again: ProfileState = decoded["profile"]
	_check(again.settings == JSON.parse_string(encoded["text"])["settings"] and again.extension_fields["opaque"] == profile.extension_fields["opaque"], "opaque JSON values remain preserved")
	_check(ProfileCodec.encode(again)["text"] == encoded["text"], "old current envelope roundtrips byte-identically")
	_check(again.equipment_instances.size() == profile.equipment_instances.size() and again.next_equipment_counter == profile.next_equipment_counter, "no clone/conversion introduced during reopen")
	for id: StringName in profile.equipment_instances:
		_check(again.equipment_instances[id].to_record() == profile.equipment_instances[id].to_record(), "all six exemplar record fields preserved")
	for index: int in profile.characters.size():
		_check(again.characters[index].equipped == profile.characters[index].equipped and again.characters[index].presets == profile.characters[index].presets and again.characters[index].action_slots == profile.characters[index].action_slots, "alt, inactive preset and current references preserved")
	_check(again.characters[0].equipped[&"accessory_1"] == again.characters[1].equipped[&"accessory_1"], "shared old exemplar stays shared across alts")
	var wire: Dictionary = encoded["data"].duplicate(true)
	wire["schema_version"] = 2; wire["catalog_version"] = 9
	wire.erase("card_inventory")
	wire.erase("equipment_instances"); wire.erase("next_equipment_counter")
	wire["equipment_collection"] = []
	for id: StringName in profile.equipment_instance_ids(): wire["equipment_collection"].append(String(profile.equipment_instances[id].definition_id))
	for character: Dictionary in wire["characters"]:
		character["equipped"] = _old_layout(character["equipped"], profile)
		for preset: Dictionary in character["presets"]: preset["equipped"] = _old_layout(preset["equipped"], profile)
	var migrated := ProfileCodec.decode(JSON.stringify(wire))
	_check(migrated["ok"] and migrated.get("migrated", false), "schema2/catalog9 still migrates under published catalog")
	if migrated["ok"]:
		var result: ProfileState = migrated["profile"]
		_check(result.equipment_instances.size() == profile.equipment_instances.size(), "migration creates one old exemplar per recorded acquisition")
		for instance: EquipmentInstance in result.equipment_instances.values(): _check(mapping.has(instance.definition_id), "migration preserves old definition instead of arena equivalent")
		_check(result.characters[0].presets[1]["equipped"][&"torso"] == result.first_instance_for_definition(&"warden_mail") and result.characters[0].equipped[&"accessory_1"] == result.characters[1].equipped[&"accessory_1"], "legacy preset and shared selection survive publication")
func _old_layout(layout: Dictionary, profile: ProfileState) -> Dictionary:
	var result := {}
	for pair: Array in [["weapon", "main_hand"], ["armor", "torso"], ["accessory", "accessory_1"]]:
		var id: Variant = layout[pair[1]]
		result[pair[0]] = null if id == null else String(profile.equipment_instances[StringName(id)].definition_id)
	return result
func _coexistence() -> void:
	var profile_catalog := ProfileCatalog.pilot()
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"; snapshot.job_level = 20; snapshot.skill_ranks = {&"fireball": 1}
	for pair: Array in [[&"old_charm", &"traveler_charm", &"accessory_1"], [&"new_charm", mapping[&"traveler_charm"], &"accessory_2"]]:
		var instance := EquipmentInstance.from_metadata(pair[0], pair[1], profile_catalog.equipment_metadata(pair[1]))
		_check(instance["ok"], "coexistence uses valid definition metadata")
		snapshot.equipment_instances[pair[0]] = instance["instance"]; snapshot.equipped[pair[2]] = pair[0]
	var composed := BuildEffectComposer.compose(snapshot, {}, [], active)
	_check(composed["ok"], "old and new accessory coexist by distinct definition")
	var baseline := snapshot.copy_snapshot(); baseline.equipped[&"accessory_2"] = null
	var neutral := BuildEffectComposer.compose(baseline, {}, [], active)
	_check(neutral["ok"] and neutral["breakdown"].values() == baseline.stat_breakdown().values(), "old-only accessory remains mechanically neutral")
	_check(composed["breakdown"].value(&"max_hp") - neutral["breakdown"].value(&"max_hp") == 6, "only new equivalent contributes approved six HP")
	var duplicate := EquipmentInstance.from_metadata(&"second_new_charm", mapping[&"traveler_charm"], profile_catalog.equipment_metadata(mapping[&"traveler_charm"]))
	snapshot.equipment_instances[&"second_new_charm"] = duplicate["instance"]; snapshot.equipped[&"accessory_3"] = &"second_new_charm"
	_check(BuildEffectComposer.compose(snapshot, {}, [], active)["error_code"] == &"identical_accessory", "two separate new identical accessories remain forbidden")
	# Different fixture IDs carrying the same published named grant cannot bypass uniqueness.
	var definition := active.get_definition(&"equipment", &"pilot_step_neck") as EquipmentDefinition
	var clone := definition.duplicate(true) as EquipmentDefinition
	clone.id = &"publication_named_fixture"; clone.slot = &"accessory"
	var collision := active.copy_catalog()
	_check(collision.register_definition(&"equipment", clone)["ok"], "isolated alternate fixture definition structurally valid")
	var named := BuildSnapshot.new(); named.base_class_id = &"mage"; named.job_level = 20; named.skill_ranks = {&"fireball": 1}
	for pair: Array in [[&"neck_one", definition, &"neck"], [&"grant_two", clone, &"accessory_1"]]:
		named.equipment_instances[pair[0]] = EquipmentInstance.from_metadata(pair[0], pair[1].id, pair[1].metadata())["instance"]
		named.equipped[pair[2]] = pair[0]
	_check(BuildEffectComposer.compose(named, {}, [], collision)["error_code"] == &"duplicate_unique_effect", "different IDs cannot repeat a named published grant")
func _acquisitions() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_publication/acquire_%d" % Time.get_ticks_usec())
	var id: StringName = mapping[&"traveler_charm"]
	var resolver := ProfileRewardResolver.new({&"publication_fixture": {"equipment_ids": [id, id]}})
	var facade := ProfileFacade.new(ProfileStore.new(directory), resolver)
	_check(facade.create_character("new-mage", 0, "Aquisição", &"mage")["ok"], "acquisition fixture starts with historical defaults")
	var started := facade.start_run("start", facade.current_profile().revision)
	_check(started["ok"], "published definitions pass reward-catalog boundary")
	if not started["ok"]: return
	var reward := facade.grant_reward("new-reward", facade.current_profile().revision, started["run_id"], 1, &"publication_fixture")
	_check(reward["ok"] and reward["equipment_instance_ids"].size() == 2 and reward["equipment_instance_ids"][0] != reward["equipment_instance_ids"][1], "two approved acquisitions produce distinct exemplars")
	if reward["ok"]:
		for instance_id: StringName in reward["equipment_instance_ids"]: _check(facade.current_profile().equipment_instances[instance_id].definition_id == id, "only new requested definition acquired")
	var before := facade.current_profile()
	var frozen := {"base_xp": 0, "job_xp": 0, "stat_increments": {}, "equipment_ids": [&"nonexistent_publication_item"]}
	var invalid := facade._grant_reward_payload("bad-reward", before.revision, started["run_id"], 2, &"publication_fixture", frozen)
	_check(invalid["error_code"] == &"invalid_catalog" and ProfileCodec.encode(facade.current_profile())["text"] == ProfileCodec.encode(before)["text"], "unknown definition is rejected atomically at actual acquisition boundary")
	var layout := EquipmentRules.empty_layout()
	var mage_only := active.get_definition(&"equipment", mapping[&"starter_staff"]) as EquipmentDefinition
	var instance := EquipmentInstance.from_metadata(&"mage_only", mage_only.id, mage_only.metadata())["instance"] as EquipmentInstance
	layout[&"main_hand"] = instance.instance_id
	_check(EquipmentRules.validate_layout(layout, {instance.instance_id: instance}, {mage_only.id: mage_only.metadata()}, &"archer", &"")["error_code"] == &"identity_restricted", "acquisition does not remove published equipment identity eligibility")

func _identity_restrictions() -> void:
	var profile_catalog := ProfileCatalog.pilot()
	var closed: Array[StringName] = IdentityIds.pure_evolution_ids()
	closed.append_array(IdentityIds.hybrid_evolution_ids())
	_check(closed.size() == 12, "twelve closed default evolution identities")
	for evolution: StringName in closed:
		_check(profile_catalog.evolution_definition(evolution) != null, "closed restriction identity has canonical profile definition")
		_check(BuildEffectCatalog._restrictions_valid([IdentityIds.evolution_origin(evolution)], [evolution]), "closed identity accepted as metadata restriction")
	_check(not BuildEffectCatalog._restrictions_valid([&"mage"], [&"unknown_publication_evolution"]), "unknown evolution cannot become valid restriction")
	_check(not BuildEffectCatalog._restrictions_valid([&"mage"], [&"spiritualist", &"spiritualist"]), "duplicate evolution restriction rejected")
	_check(not BuildEffectCatalog._restrictions_valid([&"mage", &"mage"], []), "duplicate origin restriction rejected")
	for unavailable: StringName in [&"sp_mg", &"mg_sp", &"sp_ar", &"ar_sp", &"ar_mg"]:
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = IdentityIds.evolution_origin(unavailable); snapshot.evolution_id = unavailable
		_check(BuildEffectComposer.compose(snapshot, {}, [], active)["error_code"] == &"identity_unavailable", "valid restriction metadata never enables blocked hybrid")
func _stage_pool() -> void:
	for origin: StringName in IdentityIds.base_class_ids():
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = origin; snapshot.character_id = "publication-stage"
		var state := RunState.from_build("publication-stage-%s" % origin, snapshot)
		_check(state.set_effect_catalog(active)["ok"], "stage selector consumes actual published catalog")
		var controller := RunController.new()
		controller.run_state = state
		controller.player = PlayerActor.new()
		controller.player.configure(controller.navigation, state)
		controller.encounter_active = false; controller.rng.seed = 349
		var rewards := RunRewardService.new(controller)
		var new_seen := false
		_check(controller.persistent_facade == null and not rewards.mob_loot_enabled(), "isolated stage fixture has no personal save or new mob loot rates")
		for index: int in 8:
			var ticket := rewards.issue("publication-stage-%s-%d" % [origin, index], &"encounter_one", true)
			_check(ticket["ok"], "actual current stage path emits publication ticket")
			if not ticket["ok"]: continue
			var item_id := StringName(ticket["item_id"])
			var item := active.get_definition(&"equipment", item_id) as EquipmentDefinition
			_check(item != null and not item.starter and BuildEffectCatalog.definition_allowed(item, snapshot), "stage selection contains only known eligible nonstarter definition")
			if mapping.values().has(item_id): new_seen = true
			var drops: Array = ticket["payload"]["equipment_drops"]
			_check(drops.size() == 1 and drops[0]["definition_id"] == item_id and EquipmentInstance.from_metadata(&"stage_instance", item_id, drops[0])["ok"], "stage output has valid captured acquisition metadata")
		_check(new_seen, "approved new arena IDs actually participate in existing stage selection")
		controller.player.free(); controller.player = null; controller.free()
