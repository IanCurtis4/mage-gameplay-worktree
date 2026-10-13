extends SceneTree
const Pilot = preload("res://tools/content/pilot_bundle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var entries: Array[Dictionary] = Pilot.entries()
	var prepared := ContentAuthoring.prepare(entries)
	_check(prepared["ok"], "pilot canonical recipe validation")
	if not prepared["ok"]: print(prepared); quit(1); return
	var compiled := ContentAuthoring.compile_bundle(entries, prepared["text_template"], false)
	_check(compiled["ok"] and not compiled["ready"], "draft does not fake editorial completion")
	var catalog: BuildEffectCatalog = compiled["catalog"]
	_check(catalog.ids(&"equipment").size() == 25 and catalog.ids(&"augment").size() == 25 and catalog.ids(&"card").size() == 6, "pilot counts explicit: 25 equipment, 25 augments, 6 cards")
	var slots: Dictionary = {}
	var capacities: Dictionary = {}
	for id: StringName in catalog.ids(&"equipment"):
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		_check(item.item_level == 1 and item.origin_id == &"demo_arena", "equipment origin and ilvl explicit %s" % id)
		for slot: StringName in IdentityIds.equipment_slots():
			if EquipmentRules.slot_matches(item.slot, slot): slots[slot] = true
		capacities[item.socket_capacity] = true
	_check(slots.size() == 14 and capacities.size() == 5, "all 14 positions and 0-4 capacities")
	for item: Resource in BuildContentLoader.definitions(&"equipment"):
		if item.id not in Pilot.LEGACY_EQUIPMENT_IDS: continue
		var pilot := catalog.get_definition(&"equipment", item.id) as EquipmentDefinition
		_check(pilot.metadata() == item.metadata(), "12 legacy metadata stable %s" % item.id)
	var historical := BuildEffectCatalog.pilot()
	for id: StringName in historical.ids(&"augment"):
		var old := ContentAuthoring.prepare([{ "origin": &"augment", "definition": historical.get_definition(&"augment", id), "purpose": "history"}])
		var current := ContentAuthoring.prepare([{ "origin": &"augment", "definition": catalog.get_definition(&"augment", id), "purpose": "pilot"}])
		_check(old["mechanical_digest"] == current["mechanical_digest"], "historical augment mechanics %s" % id)
	var composition_count := 0
	var state := RunState.new()
	for identity: String in Pilot.ROUTES:
		var candidates: Array[Dictionary] = []
		for branch: int in 2:
			var comparison: Dictionary = Pilot.comparison(identity, branch, catalog)
			_check(comparison["ok"], "comparison composes %s/%d" % [identity, branch])
			if not comparison["ok"]: print(comparison); continue
			composition_count += 1
			var snapshot: BuildSnapshot = comparison["snapshot"]
			var composed: Dictionary = comparison["composed"]
			_check(snapshot.equipped.values().size() == 14 and snapshot.equipped.values().count(null) == (1 if catalog.get_definition(&"equipment", snapshot.equipment_instances[snapshot.equipped[&"main_hand"]].definition_id).hand_usage == &"two_hands" else 0), "full legal equipment comparison %s/%d" % [identity, branch])
			var xp := ProgressionRules.UNEVOLVED_MAX_JOB_XP if snapshot.evolution_id.is_empty() else ProgressionRules.MAX_JOB_XP
			_check(snapshot._skill_catalog.skill_points_spent(comparison["purchased_ranks"], ProfileCatalog.BASE_WALLET) <= ProgressionRules.base_skill_points_granted(xp, not snapshot.evolution_id.is_empty()) and snapshot._skill_catalog.skill_points_spent(comparison["purchased_ranks"], ProfileCatalog.EVOLUTION_WALLET) <= ProgressionRules.evolution_skill_points_granted(xp, not snapshot.evolution_id.is_empty()), "comparison respects both skill wallets")
			_check(ActionBarLayout.valid(snapshot.action_slots, snapshot.learned_skill_ids(ProfileCatalog.ACTIVE)), "action slots reference learned skills")
			_check(composed["inactive"].is_empty(), "no dead chosen recipe %s/%d" % [identity, branch])
			_check(not comparison["tactical_validated"], "composition is not tactical certification")
			for skill: StringName in snapshot.skill_ranks:
				_check(SkillEffectResolver.capture(skill, snapshot.skill_ranks[skill], composed)["ok"], "canonical capture %s" % skill)
			if not snapshot.evolution_id.is_empty():
				var chosen := Pilot.exclusive_id(identity, branch)
				var baseline: Dictionary = comparison["run_effects"].duplicate(true)
				baseline["augment_stacks"].erase(chosen)
				var before := BuildEffectComposer.compose(snapshot, baseline, [], catalog)
				_check(state.has_effective_gain(before, composed), "exclusive is useful %s" % chosen)
				var foreign := snapshot.copy_snapshot()
				foreign.evolution_id = &""
				_check(BuildEffectComposer.compose(foreign, comparison["run_effects"], [], catalog)["error_code"] == &"identity_restricted", "exclusive does not leak to origin")
				var at_cap: Dictionary = comparison["run_effects"].duplicate(true)
				at_cap["augment_stacks"][chosen] = 3
				_check(BuildEffectComposer.compose(snapshot, at_cap, [], catalog)["ok"], "exclusive full curve valid")
				at_cap["augment_stacks"][chosen] = 4
				_check(BuildEffectComposer.compose(snapshot, at_cap, [], catalog)["error_code"] == &"stack_cap", "exclusive overflow rejected")
			_offer_checks(comparison, catalog)
			candidates.append(comparison)
		if candidates.size() == 2:
			_check(state.has_effective_gain(candidates[0]["composed"], candidates[1]["composed"]), "A/B have actual composed difference %s" % identity)
	_check(composition_count == 20, "twenty composed comparisons across ten available identities")
	for blocked: StringName in [&"sp_mg", &"mg_sp", &"sp_ar", &"ar_sp", &"ar_mg"]:
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = IdentityIds.evolution_origin(blocked)
		snapshot.evolution_id = blocked
		_check(BuildEffectComposer.compose(snapshot, {}, [], catalog)["error_code"] == &"identity_unavailable", "blocked hybrid remains unavailable %s" % blocked)
	var explicit := catalog.get_definition(&"augment", &"pilot_defender_a") as AugmentDefinition
	var text := ContentAuthoring.describe(&"augment", explicit)
	_check(text.contains("Contraforte") and text.contains("+6 / +12 / +18"), "targeted proc description names exact skill and curve")
	var mechanical_digest: String = prepared["mechanical_digest"]
	var changed := Pilot.entries()
	for entry: Dictionary in changed:
		if entry["origin"] == &"augment" and entry["definition"].id == &"pilot_defender_a": entry["definition"].effects[0].target_skill_ids.assign([&"defender_line_lock"])
	_check(ContentAuthoring.prepare(changed)["mechanical_digest"] != mechanical_digest, "target edit invalidates Luna text")
	_check(BuildContentLoader.pilot().get_definition(&"equipment", &"starter_blade").effects.is_empty() and not BuildContentLoader.pilot().get_definition(&"equipment", &"arena_starter_blade").effects.is_empty(), "publication preserves historical definition and maps recipe to new ID")
	print("E06 content pilot: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _offer_checks(comparison: Dictionary, catalog: BuildEffectCatalog) -> void:
	var snapshot: BuildSnapshot = comparison["snapshot"]
	var state := RunState.from_build("pilot-offers", snapshot)
	state.augment_stacks.assign(comparison["run_effects"]["augment_stacks"])
	state.card_instances = comparison["run_effects"]["card_instances"].duplicate()
	state.card_sockets = comparison["run_effects"]["card_sockets"].duplicate(true)
	_check(state.set_effect_catalog(catalog)["ok"], "actual pilot offer catalog injection")
	state.queue_choice()
	var rng := RandomNumberGenerator.new()
	rng.seed = 341
	var offer := state.open_offer(false, rng)
	_check(offer["ok"] and offer["ids"].size() == 3, "three useful choices available for comparison")
	for id: StringName in offer["ids"]:
		var before := state.composed_build()
		_check(state._augment_candidate(id, before)["ok"], "each offered recipe has actual uncapped gain")
	if not offer["ids"].is_empty():
		var selected: StringName = offer["ids"][0]
		var previous := int(state.augment_stacks.get(selected, 0))
		_check(state.confirm_offer(offer, selected, false)["ok"] and state.augment_stacks[selected] == previous + 1, "confirm applies one real pilot stack")
	var exhausted := RunState.from_build("pilot-exhausted", snapshot)
	for id: StringName in catalog.ids(&"augment"):
		var definition := catalog.get_definition(&"augment", id) as AugmentDefinition
		if BuildEffectCatalog.definition_allowed(definition, snapshot): exhausted.augment_stacks[id] = definition.max_stacks
	_check(exhausted.set_effect_catalog(catalog)["ok"], "full legal identity pool at declared caps composes")
	exhausted.queue_choice()
	var empty := exhausted.open_offer(false, rng)
	_check(empty["ok"] and empty["empty"], "exhausted pool yields explicit empty offer")
	_check(exhausted.consume_empty_offer(empty, false)["ok"] and exhausted.pending_choices == 0, "empty choice consumed once")
