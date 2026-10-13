extends SceneTree
const Transform = preload("res://tools/content/transform_bundle.gd")
const Spatial = preload("res://tools/content/spatial_bundle.gd")
var checks := 0
var failures := 0
const CASES := [
	[&"spiritualist_drain_inscription", &"drain_inscription", &"mage", &"spiritualist", [&"spiritualist_soul_drain", &"spiritualist_echo_curse"]],
	[&"hunter_marked_mechanism", &"hunter_marked_mechanism", &"archer", &"hunter", [&"hunter_mark", &"hunter_thorn_trap"]],
	[&"hunter_covering_fan", &"hunter_covering_fan", &"archer", &"hunter", [&"hunter_covering_shot"]],
	[&"geometer_collapse_first_element", &"geometer_collapse_first_element", &"mage", &"mg_ar", [&"geometer_collapse", &"geometer_triangulation"]],
]
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _snapshot(row: Array) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "transform-pure"
	build.base_class_id = row[2]
	build.evolution_id = row[3]
	build.job_level = 40
	build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(build.base_class_id, build.evolution_id)
	for skill: StringName in row[4]: build.skill_ranks[skill] = 1
	return build
func _run() -> void:
	var entries: Array[Dictionary] = Transform.entries()
	var prepared := ContentAuthoring.prepare(entries)
	_check(entries.size() == 69 and prepared["ok"], "69 isolated recipes prepare")
	if not prepared["ok"]: print(prepared); quit(1); return
	var compiled := ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)
	_check(compiled["ok"], "template mechanical compilation does not require editorial")
	if not compiled["ok"]: print(compiled); quit(1); return
	var catalog: BuildEffectCatalog = compiled["catalog"]
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/spatial_texts.json"))
	_check(ContentAuthoring.compile_bundle(Spatial.entries(), old)["ok"], "65 previous recipes retain their mechanical digest")
	for row: Array in CASES:
		var id: StringName = row[0]
		var axis: StringName = row[1]
		var definition := catalog.get_definition(&"augment", id) as AugmentDefinition
		_check(definition != null, "policy recipe present %s" % id)
		if definition == null: continue
		var build := _snapshot(row)
		var baseline := BuildEffectComposer.compose(build, {}, [], catalog)
		var enabled := BuildEffectComposer.compose(build, {"augment_stacks": {id: 1}}, [], catalog)
		_check(enabled["ok"] and enabled["kit_policies"].get(axis, false), "learned required kit admits %s" % id)
		_check(enabled["breakdown"].values() == baseline["breakdown"].values() and enabled["skill_rules"].is_empty() and enabled["procs"].is_empty(), "policy changes neither statistics nor generic proc/scalar")
		var state := RunState.from_build("transform-pure", build)
		_check(state.set_effect_catalog(catalog)["ok"] and state.has_effective_gain(baseline, enabled), "useful offer includes kit transformation")
		var capture := SkillEffectResolver.capture(row[4][0], 1, enabled)
		enabled["kit_policies"].clear()
		_check(capture["kit_policies"].get(axis, false), "capture remains owned after composer mutation")
		_check(BuildEffectComposer.compose(build, {"augment_stacks": {id: 2}}, [], catalog)["error_code"] == &"stack_cap", "transform has one acquisition maximum")
		for missing: StringName in row[4]:
			build.skill_ranks.erase(missing)
			var inactive := BuildEffectComposer.compose(build, {"augment_stacks": {id: 1}}, [], catalog)
			_check(inactive["ok"] and inactive["kit_policies"].is_empty(), "required learned skill cannot be replaced by library visibility %s" % missing)
			build.skill_ranks[missing] = 1
		if axis == &"hunter_marked_mechanism":
			build.skill_ranks.erase(&"hunter_thorn_trap")
			for alternative: StringName in [&"hunter_freezing_trap", &"hunter_tar_trap"]:
				build.skill_ranks[alternative] = 1
				_check(BuildEffectComposer.compose(build, {"augment_stacks": {id: 1}}, [], catalog)["kit_policies"].get(axis, false), "any learned affected trap plus mark satisfies mechanism")
				build.skill_ranks.erase(alternative)
			build.skill_ranks[&"hunter_thorn_trap"] = 1
		build.evolution_id = &""
		_check(BuildEffectComposer.compose(build, {"augment_stacks": {id: 1}}, [], catalog)["error_code"] == &"identity_restricted", "base origin cannot inherit evolved transform")
		build = _snapshot(row)
		var effect: EffectDefinition = definition.effects[0]
		for field: String in ["axis", "unit", "handler_id", "minimum_rank", "magnitude", "conflict_group", "allowed_origins", "target_skill_ids"]:
			var broken := effect.duplicate(true) as EffectDefinition
			match field:
				"axis": broken.axis = &"unapproved_policy"
				"unit": broken.unit = &"damage"
				"handler_id": broken.handler_id = EffectDefinition.Handler.HIT_DAMAGE
				"minimum_rank": broken.minimum_rank = 2
				"magnitude": broken.magnitude = 1
				"conflict_group": broken.conflict_group = &"other"
				"allowed_origins": broken.allowed_origins = [&"warrior"]
				"target_skill_ids": broken.target_skill_ids = [&"basic_attack"]
			_check(not BuildEffectCatalog.validate_effect(broken)["ok"], "closed recipe rejects %s" % field)
		var copy := definition.duplicate(true) as AugmentDefinition
		copy.max_stacks = 3
		_check(not BuildEffectCatalog.new().register_definition(&"augment", copy)["ok"], "numeric stack extension rejected")
		copy = definition.duplicate(true) as AugmentDefinition
		copy.allowed_evolutions.clear()
		_check(not BuildEffectCatalog.new().register_definition(&"augment", copy)["ok"], "missing evolution cannot broaden recipe")
		var item := EquipmentDefinition.new()
		item.id = &"transform_item"
		item.slot = &"accessory"
		item.item_kind = &"jewelry"
		item.hand_usage = &"none"
		item.quality_id = &"rare"
		item.effects.assign([effect])
		_check(BuildEffectCatalog.new().register_definition(&"equipment", item)["error_code"] == &"capability_not_allowed", "equipment cannot acquire this augment-only policy")
		var card := catalog.get_definition(&"card", &"echo_card") as CardDefinition
		card.id = &"transform_card"
		card.effects.assign([effect])
		_check(catalog.copy_catalog().register_definition(&"card", card)["error_code"] == &"capability_not_allowed", "elite card is not implicitly approved")
		var set := EquipmentSetDefinition.new()
		set.id = &"transform_set"
		set.thresholds = {2: [effect]}
		_check(not BuildEffectCatalog.new().register_set(set)["ok"], "set cannot bypass source contract")
		copy = definition.duplicate(true) as AugmentDefinition
		copy.id = StringName(String(id) + "_alternative")
		var collision := catalog.copy_catalog()
		_check(collision.register_definition(&"augment", copy)["ok"], "same axis alternative can exist alone")
		_check(BuildEffectComposer.compose(build, {"augment_stacks": {id: 1, copy.id: 1}}, [], collision)["error_code"] == &"effect_conflict", "same axis co-acquisition rejects atomically")
		var directory := "res://.godot/content_authoring/transform_roundtrip_%d" % Time.get_ticks_usec()
		DirAccess.make_dir_recursive_absolute(directory)
		var path := directory.path_join(String(id) + ".tres")
		_check(ResourceSaver.save(definition, path) == OK, "native policy save")
		var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var native := ContentAuthoring.prepare([{"origin": &"augment", "definition": reloaded, "purpose": "reload"}])
		var original := ContentAuthoring.prepare([{"origin": &"augment", "definition": definition, "purpose": "original"}])
		_check(native["ok"] and native["mechanical_digest"] == original["mechanical_digest"], "native policy roundtrip preserves mechanical fingerprint")
	_admission()
	print("E06 transform policies: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _admission() -> void:
	for invalid: String in ["missing", "foreign", "secondary", "proc_child", "zero", "other_skill", "no_policy", "cancelled", "other_ledger"]:
		var ledger := EffectProcLedger.new("transform-admission")
		var context := ledger.new_root(101, false, "", false, {"families": [&"hunter_exploit"], "targets": [201], "carriers": []}).impact(201)
		var result := {"context": context, "source_id": 101, "target_id": 201, "actual_damage": 1.0, "can_trigger_effects": true, "skill_id": &"hunter_covering_shot", "effect_snapshot": {"kit_policies": {&"hunter_covering_fan": true}}}
		match invalid:
			"missing": result.erase("context")
			"foreign": result["source_id"] = 900
			"secondary": result["context"] = context.secondary_prototype()
			"proc_child": context.proc_child = true
			"zero": result["actual_damage"] = 0.0
			"other_skill": result["skill_id"] = &"basic_attack"
			"no_policy": result["effect_snapshot"] = {}
			"cancelled": ledger.cancel()
			"other_ledger": result["context"] = EffectProcLedger.new("foreign").new_root(101)
		_check(not ledger.admit_hunter_fan(result, 202), "closed fan producer rejects %s" % invalid)
		_check(not context._budget.targets.has(202), "invalid callback never expands causal target plan")
	var ledger := EffectProcLedger.new("transform-admission")
	var root_context := ledger.new_root(101, false, "", false, {"families": [&"hunter_exploit"], "targets": [201], "carriers": []})
	var hit := root_context.impact(201)
	_check(not ledger._admit_target(hit, 202), "generic impact admission remains closed")
	var result := {"context": hit, "source_id": 101, "target_id": 201, "actual_damage": 1.0, "can_trigger_effects": true, "skill_id": &"hunter_covering_shot", "effect_snapshot": {"kit_policies": {&"hunter_covering_fan": true}}}
	_check(ledger.admit_hunter_fan(result, 202) and hit._budget.targets.has(202), "validated fan can admit selected post-impact target")
	var claims := ledger.claim_batch(hit, [{"family_id": &"hunter_exploit", "source_id": &"hunter_opening", "target_id": 202}])
	_check(claims.size() == 1, "admitted fan target gets one bounded claim")
	if claims.is_empty(): return
	var child: CombatEventContext = claims[0]["context"]
	result["context"] = child
	_check(not ledger.admit_hunter_fan(result, 203) and not hit._budget.targets.has(203), "child can never extend fan into a cascade")
