extends SceneTree
const Spatial = preload("res://tools/content/spatial_bundle.gd")
const Pilot = preload("res://tools/content/pilot_bundle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	_check(EffectDefinition.Kind.ACTIVE_GRANT == 3 and EffectDefinition.Handler.ACTIVE_SKILL == 4, "serialized historical enum indices stable")
	var entries: Array[Dictionary] = Spatial.entries()
	var prepared := ContentAuthoring.prepare(entries)
	_check(prepared["ok"] and entries.size() == 65, "65 recipes and two closed policy declarations")
	if not prepared["ok"]: print(prepared); quit(1); return
	var compiled := ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)
	var catalog: BuildEffectCatalog = compiled["catalog"]
	for identity: String in ["spiritualist", "mg_ar"]:
		var actual_a: Dictionary = Spatial.comparison(identity, 0, catalog)
		var actual_b: Dictionary = Spatial.comparison(identity, 1, catalog)
		_check(actual_a["ok"] and actual_b["ok"] and actual_a["composed"]["kit_policies"].size() == 1 and actual_b["composed"]["kit_policies"].is_empty(), "report comparisons distinguish chosen spatial mode")
	var real_text: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/spatial_texts.json"))
	var real := ContentAuthoring.compile_bundle(entries, real_text)
	_check(real["ok"] and real["ready"], "actual two Luna entries complete the spatial bundle")
	var old_text: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/pilot_texts.json"))
	for key: String in old_text["entries"]: _check(real_text["entries"][key] == old_text["entries"][key], "old editorial cell immutable %s" % key)
	if real["ok"]:
		var directory := "res://.godot/content_authoring/spatial_roundtrip_%d" % Time.get_ticks_usec()
		DirAccess.make_dir_recursive_absolute(directory)
		for id: StringName in [&"spiritualist_echo_fixed_origin", &"geometer_ground_anchor"]:
			var definition: Resource = real["catalog"].get_definition(&"augment", id)
			var path := directory.path_join(String(id) + ".tres")
			_check(ResourceSaver.save(definition, path) == OK, "native policy save")
			var reloaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			var native := ContentAuthoring.prepare([{ "origin": &"augment", "definition": reloaded, "purpose": "reload"}])
			var original := ContentAuthoring.prepare([{ "origin": &"augment", "definition": definition, "purpose": "original"}])
			_check(native["ok"] and native["mechanical_digest"] == original["mechanical_digest"] and reloaded.display_name == definition.display_name and reloaded.flavor_text == definition.flavor_text, "native policy reload preserves enums/axis/editorial")
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/pilot_texts.json"))
	_check(ContentAuthoring.compile_bundle(Pilot.entries(), previous)["ok"], "old editorial digest remains compatible")
	for pair: Array in [[&"spiritualist_echo_fixed_origin", &"spiritualist", &"spiritualist_echo_curse", &"echo_origin_fixed"], [&"geometer_ground_anchor", &"mg_ar", &"geometer_trace", &"geometer_ground_anchor"]]:
		var id: StringName = pair[0]
		var definition := catalog.get_definition(&"augment", id) as AugmentDefinition
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "spatial-pure"
		snapshot.base_class_id = &"mage"
		snapshot.evolution_id = pair[1]
		snapshot.job_level = 40
		snapshot.library_skill_ids = snapshot._skill_catalog.skill_ids_for_identity(&"mage", snapshot.evolution_id)
		snapshot.skill_ranks[StringName(pair[2])] = 1
		var baseline := BuildEffectComposer.compose(snapshot, {}, [], catalog)
		var result := BuildEffectComposer.compose(snapshot, {"augment_stacks": {id: 1}}, [], catalog)
		_check(result["ok"] and result["kit_policies"].get(pair[3], false) and result["procs"].is_empty() and result["skill_rules"].is_empty(), "policy is neither proc nor numeric scalar")
		_check(result["breakdown"].values() == baseline["breakdown"].values(), "policy adds no stats or damage multiplier")
		var state := RunState.from_build("spatial-pure", snapshot)
		_check(state.set_effect_catalog(catalog)["ok"] and state.has_effective_gain(baseline, result), "policy is a useful offer")
		var captured := SkillEffectResolver.capture(pair[2], 1, result)
		result["kit_policies"].clear()
		_check(captured["kit_policies"].get(pair[3], false), "capture owns policy copy")
		_check(BuildEffectComposer.compose(snapshot, {"augment_stacks": {id: 2}}, [], catalog)["error_code"] == &"stack_cap", "one acquisition only")
		snapshot.skill_ranks.clear()
		var inactive := BuildEffectComposer.compose(snapshot, {"augment_stacks": {id: 1}}, [], catalog)
		_check(inactive["ok"] and inactive["kit_policies"].is_empty() and not state.has_effective_gain(BuildEffectComposer.compose(snapshot, {}, [], catalog), inactive), "unlearned kit cannot activate policy or useful offer")
		snapshot.evolution_id = &""
		_check(BuildEffectComposer.compose(snapshot, {"augment_stacks": {id: 1}}, [], catalog)["error_code"] == &"identity_restricted", "origin does not inherit evolution policy")
		var effect: EffectDefinition = definition.effects[0]
		for field: String in ["axis", "unit", "handler_id", "minimum_rank", "magnitude", "conflict_group"]:
			var broken := effect.duplicate(true) as EffectDefinition
			match field:
				"axis": broken.axis = &"arbitrary_policy"
				"unit": broken.unit = &"damage"
				"handler_id": broken.handler_id = EffectDefinition.Handler.HIT_DAMAGE
				"minimum_rank": broken.minimum_rank = 2
				"magnitude": broken.magnitude = 1
				"conflict_group": broken.conflict_group = &"other"
			_check(not BuildEffectCatalog.validate_effect(broken)["ok"], "closed policy rejects changed %s" % field)
		var excessive := definition.duplicate(true) as AugmentDefinition
		excessive.max_stacks = 3
		_check(not BuildEffectCatalog.new().register_definition(&"augment", excessive)["ok"], "policy recipe cannot acquire numeric curves")
		var missing_restriction := definition.duplicate(true) as AugmentDefinition
		missing_restriction.allowed_evolutions.clear()
		_check(not BuildEffectCatalog.new().register_definition(&"augment", missing_restriction)["ok"], "recipe restriction cannot omit required evolution")
		var item := EquipmentDefinition.new()
		item.id = &"policy_item"
		item.slot = &"accessory"
		item.item_kind = &"jewelry"
		item.hand_usage = &"none"
		item.quality_id = &"rare"
		item.effects.assign([effect])
		_check(BuildEffectCatalog.new().register_definition(&"equipment", item)["error_code"] == &"capability_not_allowed", "new policy is not implicitly authorized for equipment")
		var set := EquipmentSetDefinition.new()
		set.id = &"policy_set"
		set.thresholds = {2: [effect]}
		_check(not BuildEffectCatalog.new().register_set(set)["ok"], "sets cannot bypass closed recipe source")
		var card := catalog.get_definition(&"card", &"echo_card") as CardDefinition
		card.id = &"policy_card"
		card.effects.assign([effect])
		_check(catalog.copy_catalog().register_definition(&"card", card)["error_code"] == &"capability_not_allowed", "elite card does not bypass augment-only policy authorization")
		var collision := definition.duplicate(true) as AugmentDefinition
		collision.id = StringName(String(id) + "_alternative")
		var conflicted := catalog.copy_catalog()
		_check(conflicted.register_definition(&"augment", collision)["ok"], "same-axis alternative recipe structurally valid")
		snapshot.evolution_id = pair[1]
		snapshot.skill_ranks[StringName(pair[2])] = 1
		_check(BuildEffectComposer.compose(snapshot, {"augment_stacks": {id: 1, collision.id: 1}}, [], conflicted)["error_code"] == &"effect_conflict", "same policy axis rejects co-acquisition atomically")
		var description := ContentAuthoring.describe(&"augment", definition)
		_check(description.contains("rank 1") and not description.contains("dano físico"), "description separates policy from numeric proc")
	# Ordered confirmed impacts stay at impact ground while awaiting older tickets.
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1600, 1000), [], 0)
	for fixed: bool in [false, true]:
		var construction := GeometerConstructionState.new()
		var first := construction.reserve_shot(Vector2(200, 200), 1, false, 1, nav, 8, 6, &"fire", fixed)
		var second := construction.reserve_shot(Vector2(500, 200), 2, false, 1, nav, 8, 6, &"ice", fixed)
		_check(construction.resolve_shot(second, true, Vector2(500, 200), {1: Vector2(200, 200), 2: Vector2(500, 200)}, nav).is_empty(), "FIFO waits for earlier shot")
		construction.advance(0.5, {1: Vector2(200, 200), 2: Vector2(550, 200)}, nav)
		var committed := construction.resolve_shot(first, true, Vector2(200, 200), {1: Vector2(200, 200), 2: Vector2(550, 200)}, nav)
		_check(committed.size() == 2 and construction.vertices.size() == 2, "same finite ordered construction")
		_check(construction.vertices[1].actor_id == (0 if fixed else 2) and construction.vertices[1].position == Vector2(500 if fixed else 550, 200), "fixed policy preserves real confirmed impact while original follows carrier")
		_check(is_equal_approx(construction.vertices[1].remaining, 7.5), "waiting time still spends captured vertex lifetime")
	print("E06 spatial policies: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
