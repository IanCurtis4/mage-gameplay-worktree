extends SceneTree
const Demo = preload("res://tools/content/demo_bundle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _texts(prepared: Dictionary) -> Dictionary:
	var text: Dictionary = prepared["text_template"].duplicate(true)
	for key: String in text["entries"]: text["entries"][key] = {"name": "Nome de teste", "flavor": "Uma lembrança guardada no caminho."}
	return text
func _run() -> void:
	var entries: Array[Dictionary] = Demo.entries()
	var prepared := ContentAuthoring.prepare(entries)
	_check(prepared["ok"], "authoring pack validates with canonical catalogs")
	if not prepared["ok"]:
		print(prepared); quit(1); return
	_check(entries.size() == 24 and prepared["briefs"].size() == 24, "fourteen positions, focus/two-hand alternatives and five content origins are explicit demo entries")
	var reversed := entries.duplicate()
	reversed.reverse()
	_check(ContentAuthoring.prepare(reversed)["mechanical_digest"] == prepared["mechanical_digest"], "entry order cannot stale creative work")
	var text := _texts(prepared)
	var compiled := ContentAuthoring.compile_bundle(entries, text)
	_check(compiled["ok"] and compiled["ready"], "names/flavor compile to copied resources")
	if not compiled["ok"]: quit(1); return
	_check(ContentAuthoring.prepare(compiled["entries"])["mechanical_digest"] == prepared["mechanical_digest"], "editorial changes leave all mechanical fields and references identical")
	for index: int in entries.size():
		_check(entries[index]["definition"].display_name.is_empty() and compiled["entries"][index]["definition"].display_name == "Nome de teste", "compile cannot mutate source recipe")
	_check(ContentAuthoring.compile_bundle(entries, prepared["text_template"])["error_code"] == &"incomplete_editorial_document", "blank template cannot be considered complete")
	var draft := ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)
	_check(draft["ok"] and not draft["ready"] and draft["pending"].size() == 24, "explicit incomplete draft remains marked pending")
	var bad := text.duplicate(true)
	bad["entries"]["equipment:demo_head"]["effects"] = []
	_check(ContentAuthoring.compile_bundle(entries, bad)["error_code"] == &"invalid_editorial_fields", "editorial file cannot override mechanics")
	bad = text.duplicate(true)
	bad["entries"]["equipment:unknown"] = {"name": "Invasor", "flavor": "Outro."}
	_check(ContentAuthoring.compile_bundle(entries, bad)["error_code"] == &"unknown_editorial_id", "editor cannot add ids outside producer bundle")
	bad = text.duplicate(true)
	bad["mechanical_digest"] = "obsolete"
	_check(ContentAuthoring.compile_bundle(entries, bad)["error_code"] == &"stale_editorial_document", "stale mechanic revision blocks compilation")
	bad = text.duplicate(true)
	bad["schema_version"] = true
	_check(ContentAuthoring.compile_bundle(entries, bad)["error_code"] == &"invalid_editorial_document", "boolean version cannot impersonate numeric envelope")
	for value: Variant in [3, null, "x".repeat(81), "Primeira\nSegunda", "Nome" + String.chr(127), "Primeira" + String.chr(8232) + "Segunda"]:
		bad = text.duplicate(true)
		bad["entries"]["equipment:demo_head"]["name"] = value
		_check(not ContentAuthoring.compile_bundle(entries, bad)["ok"], "malformed or unbounded editorial name rejected")
	var extra := entries.duplicate()
	extra.append(entries[0])
	_check(ContentAuthoring.prepare(extra)["error_code"] == &"duplicate_or_empty_id", "duplicated id rejected before a template is emitted")
	var fresh: Array[Dictionary] = Demo.entries()
	(fresh[0]["definition"] as EquipmentDefinition).socket_capacity = 5
	_check(not ContentAuthoring.prepare(fresh)["ok"], "actual acquisition socket validation reused by authoring")
	fresh = Demo.entries()
	for entry: Dictionary in fresh:
		if entry["definition"] is CardDefinition and entry["definition"].id == &"demo_elite_card": entry["definition"].mob_base_id = &"demo_normal_species"
	_check(ContentAuthoring.prepare(fresh)["error_code"] == &"capability_not_allowed", "normal species cannot acquire transformation through authoring")
	fresh = Demo.entries()
	for entry: Dictionary in fresh:
		if entry["definition"] is EquipmentDefinition and entry["definition"].id == &"demo_main_hand": entry["definition"].quality_id = &"uncommon"
	_check(ContentAuthoring.prepare(fresh)["error_code"] == &"capability_not_allowed", "interesting uncommon equipment rejected by canonical capability contract")
	fresh = Demo.entries()
	for entry: Dictionary in fresh:
		if entry["definition"] is MobDefinition: entry["definition"].card_id = &"unknown_card"
	_check(ContentAuthoring.prepare(fresh)["error_code"] == &"invalid_authoring_card_link", "species/card reverse link cannot dangle")
	fresh = Demo.entries()
	for entry: Dictionary in fresh:
		if entry["definition"] is EquipmentSetDefinition: entry["definition"].thresholds = {3: entry["definition"].thresholds[2]}
	_check(ContentAuthoring.prepare(fresh)["error_code"] == &"unreachable_authoring_set", "set requires enough actually declared armor positions")
	fresh = Demo.entries()
	for entry: Dictionary in fresh:
		if entry["definition"] is EquipmentDefinition and entry["definition"].set_id == &"demo_armor_set":
			entry["definition"].allowed_origins.assign([&"mage"] if entry["definition"].slot == &"torso" else [&"swordsman"])
	_check(ContentAuthoring.prepare(fresh)["error_code"] == &"unreachable_authoring_set", "set pieces on incompatible origins cannot impersonate a wearable threshold")
	var original_catalog: BuildEffectCatalog = ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)["catalog"]
	var populated_catalog: BuildEffectCatalog = compiled["catalog"]
	var snapshot := _snapshot(entries)
	var run_effects := {"augment_stacks": {&"demo_sp_growth": 3, &"demo_spear_range": 2}}
	var before := BuildEffectComposer.compose(snapshot, run_effects, [], original_catalog)
	var after := BuildEffectComposer.compose(snapshot, run_effects, [], populated_catalog)
	_check(before["ok"] and after["ok"], "complete fourteen-position demonstrative build is legal through canonical composer")
	if before["ok"] and after["ok"]:
		_check(before["breakdown"].values() == after["breakdown"].values(), "creative population changes no combat stats")
		_check(before["skill_ranks"] == after["skill_ranks"] and before["procs"] == after["procs"] and before["skill_rules"] == after["skill_rules"], "creative population changes no active grant, proc or skill rule")
		_check(int(after["skill_ranks"][&"teleport"]) == 1 and not snapshot.skill_ranks.has(&"teleport"), "demonstrative active uses real access contract without learning")
		var spell := SkillEffectResolver.capture(&"fire_spear", 1, after)
		var baseline := SkillEffectResolver.capture(&"fire_spear", 1, BuildEffectComposer.compose(snapshot, {}, [], populated_catalog))
		_check(is_equal_approx(spell["values"]["range"] - baseline["values"]["range"], 40.0), "curve facts match actual captured range at second stack")
	_check((populated_catalog.get_definition(&"augment", &"demo_spear_range") as AugmentDefinition).description.contains("+20 / +40"), "generated mechanical text includes full skill curve")
	_check((populated_catalog.get_definition(&"equipment", &"demo_main_hand") as EquipmentDefinition).description.contains("uso desta arma"), "generated proc text preserves actual weapon requirement")
	var only_text_changed := Demo.entries()
	for entry: Dictionary in only_text_changed: entry["definition"].display_name = "Outro nome"
	_check(ContentAuthoring.prepare(only_text_changed)["mechanical_digest"] == prepared["mechanical_digest"], "mechanical digest does not derive identity from displayed names")
	fresh = Demo.entries()
	(fresh[0]["definition"] as EquipmentDefinition).effects[0].magnitude += 1
	_check(ContentAuthoring.compile_bundle(fresh, text)["error_code"] == &"stale_editorial_document", "actual number change invalidates old editorial document")
	fresh = Demo.entries()
	var critical: EquipmentDefinition = fresh[0]["definition"]
	critical.effects[0].axis = &"crit_chance"
	critical.effects[0].magnitude = 0.025
	var critical_prepared := ContentAuthoring.prepare(fresh)
	var critical_compiled := ContentAuthoring.compile_bundle(fresh, _texts(critical_prepared))
	_check((critical_compiled["catalog"].get_definition(&"equipment", critical.id) as EquipmentDefinition).description.contains("+2,5 p.p."), "factual percentage points use localized decimal comma without trailing zero noise")
	var directory := "res://.godot/verification/e06_content_roundtrip_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var item := populated_catalog.get_definition(&"equipment", &"demo_main_hand")
	var path := directory.path_join("item.tres")
	_check(ResourceSaver.save(item, path) == OK, "compiled immutable resource saves in isolated preview")
	var loaded := load(path) as EquipmentDefinition
	_check(loaded != null and loaded.display_name == item.display_name and loaded.flavor_text == item.flavor_text and loaded.description == item.description and loaded.effects[0].magnitude == 3, "resource reload preserves separate prose and mechanics")
	print("E06 content authoring: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _snapshot(entries: Array[Dictionary]) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "authoring-demo"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"fire_wall": 2, &"fire_spear": 1, &"ice_spear": 1}
	snapshot.library_skill_ids = [&"fire_spear", &"ice_spear"]
	var counter := 1
	for entry: Dictionary in entries:
		if not entry["definition"] is EquipmentDefinition: continue
		var definition: EquipmentDefinition = entry["definition"]
		if definition.id in [&"demo_focus", &"demo_two_hands"]: continue
		var id := StringName("equipment_%d" % counter)
		counter += 1
		var added := EquipmentInstance.from_metadata(id, definition.id, definition.metadata())
		assert(added["ok"])
		snapshot.equipment_instances[id] = added["instance"]
		var position := StringName(String(definition.id).trim_prefix("demo_"))
		snapshot.equipped[position] = id
	return snapshot
