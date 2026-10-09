extends SceneTree
const Fixture = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_origins_and_copies()
	_validation_and_conflicts()
	_offers()
	_combined_and_scalar()
	_snapshot_removal()
	print("E06 effects composition: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _origins_and_copies() -> void:
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		var snapshot := Fixture.snapshot()
		var effect: EffectDefinition = Fixture.count_effect()
		var registry: BuildEffectCatalog = Fixture.catalog_for(origin, [effect])
		var state: Dictionary = Fixture.state_for(origin, snapshot)
		var composed := BuildEffectComposer.compose(snapshot, state, [], registry)
		_check(composed["ok"], "%s composes" % origin)
		var preview := SkillEffectResolver.preview(&"fire_spear", 1, composed)
		var captured := SkillEffectResolver.capture(&"fire_spear", 1, composed)
		_check(preview["values"] == captured["values"] and captured["values"]["projectile_count"] == 2, "%s transformation uses identical capture" % origin)
		effect.magnitude = 90.0
		var returned := registry.get_definition(origin, &"fixture")
		returned.effects[0].magnitude = 70.0
		var again := BuildEffectComposer.compose(snapshot, state, [], registry)
		_check(SkillEffectResolver.capture(&"fire_spear", 1, again)["values"]["projectile_count"] == 2, "registry owns copied recipes")
		snapshot.skill_ranks[&"fire_spear"] = 0
		var dormant := BuildEffectComposer.compose(snapshot, state, [], registry)
		_check(dormant["ok"] and dormant["skill_rules"].is_empty() and dormant["inactive"].size() == 1, "unlearned skill dormant without deleting source")
		_check(captured["values"]["projectile_count"] == 2, "old capture survives changes")
		_check(SkillEffectResolver.capture(&"fire_spear", 1, dormant)["error_code"] == &"rank_mismatch", "caller cannot preview unlearned rank as authority")
	var snapshot := Fixture.snapshot()
	var sources: Array[Dictionary] = [{"source_id": &"a", "flat": {&"magic_attack": 3.0}}, {"source_id": &"b", "increased": {&"magic_attack": 0.5}}]
	var first := BuildEffectComposer.compose(snapshot, {}, sources)
	sources.reverse()
	var second := BuildEffectComposer.compose(snapshot, {}, sources)
	_check(first["breakdown"].values() == second["breakdown"].values(), "source order does not change calculation")
	sources.append(sources[0])
	_check(BuildEffectComposer.compose(snapshot, {}, sources)["error_code"] == &"duplicate_source", "duplicate source rejected")
	var state := RunState.new(&"mage")
	var isolated := state.composed_build()
	isolated["breakdown"].derived[&"max_hp"]["effective"] = -99.0
	_check(state.composed_build()["breakdown"].value(&"max_hp") > 0.0, "cached DTO stats are copied")
	_check(BuildEffectCatalog.pilot().ids(&"augment") == [&"battle_rhythm", &"extra_fire_spear", &"extra_ice_spear", &"keen_edge", &"vitality"], "five pilot IDs preserved")
	_check(BuildEffectCatalog.pilot().ids(&"equipment").is_empty() and BuildEffectCatalog.pilot().ids(&"card").is_empty(), "fixtures grant no production items")

func _validation_and_conflicts() -> void:
	var effect: EffectDefinition = Fixture.count_effect()
	effect.magnitude = NAN
	_check(not BuildEffectCatalog.validate_effect(effect)["ok"], "nonfinite rejected")
	effect = Fixture.count_effect()
	effect.target_skill_ids = [&"slash"]
	_check(BuildEffectCatalog.validate_effect(effect)["error_code"] == &"unsupported_skill_axis", "no silent handler for unsupported projectile skill")
	var primary := EffectDefinition.new()
	primary.id = &"bad"
	primary.family_id = &"bad"
	primary.unit = &"ratio"
	primary.channel = &"increased"
	primary.axis = &"int"
	_check(not BuildEffectCatalog.validate_effect(primary)["ok"], "primary percentages forbidden")
	var registry := BuildEffectCatalog.new()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		var exclusive: EffectDefinition = Fixture.count_effect()
		exclusive.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
		exclusive.conflict_group = &"one_transformation"
		_check(registry.register_definition(origin, Fixture.definition(origin, origin, [exclusive]))["ok"], "exclusive recipe valid")
	var snapshot := Fixture.snapshot()
	snapshot.equipped = {&"weapon": &"equipment"}
	_check(BuildEffectComposer.compose(snapshot, {"augment_stacks": {&"augment": 1}}, [], registry)["error_code"] == &"effect_conflict", "augment/equipment reject entire conflict")
	_check(BuildEffectComposer.compose(snapshot, {"card_sockets": {&"equipment": &"card"}}, [], registry)["error_code"] == &"effect_conflict", "equipment/card reject entire conflict")
	var capped: EffectDefinition = Fixture.count_effect(&"cap", 20.0)
	registry = Fixture.catalog_for(&"augment", [capped])
	snapshot = Fixture.snapshot()
	var capture := SkillEffectResolver.capture(&"fire_spear", 1, BuildEffectComposer.compose(snapshot, {"augment_stacks": {&"fixture": 1}}, [], registry))
	_check(capture["values"]["projectile_count"] == 16, "single final count cap")
	for evolution: StringName in [&"sp_mg", &"mg_sp", &"sp_ar", &"ar_sp", &"ar_mg"]:
		var identity := ProfileCatalog.pilot().evolution_definition(evolution)
		snapshot.base_class_id = identity.origin_class_id
		snapshot.evolution_id = evolution
		_check(BuildEffectComposer.compose(snapshot, {})["error_code"] == &"identity_unavailable", "future identity blocked")

func _offers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state := RunState.new(&"mage")
	state.queue_choice()
	state.queue_choice()
	var offer := state.open_offer(false, rng)
	var rng_state := rng.state
	var reopened := state.open_offer(false, rng)
	_check(offer["ids"] == reopened["ids"] and rng.state == rng_state, "reopen does not reroll")
	_check(state.has_open_offer() and state.set_effect_catalog(BuildEffectCatalog.pilot())["error_code"] == &"offer_open", "closed window retains mutation lock")
	var stale := offer.duplicate(true)
	stale["runtime_revision"] -= 1
	_check(not state.confirm_offer(stale, offer["ids"][0], false)["ok"] and state.pending_choices == 2, "stale revision atomic")
	_check(state.confirm_offer(offer, offer["ids"][0], false)["ok"] and state.pending_choices == 1, "valid confirmation one stack/pending")
	_check(not state.confirm_offer(offer, offer["ids"][0], false)["ok"] and state.pending_choices == 1, "replay rejected")
	state = RunState.new(&"mage")
	state.build_snapshot.active_slots.clear()
	state.build_snapshot.action_slots.clear()
	state.skill_levels.clear()
	state.queue_choice()
	offer = state.open_offer(false, rng)
	_check(offer["ids"].size() == 3 and &"extra_fire_spear" not in offer["ids"] and &"extra_ice_spear" not in offer["ids"], "empty bar still offers useful general stats, no unlearned skills")
	state = RunState.new()
	state.queue_choice()
	state.queue_choice()
	state.augment_stacks = {&"vitality": 3, &"keen_edge": 3, &"battle_rhythm": 3}
	offer = state.open_offer(false, rng)
	_check(offer["empty"], "exhausted pool represented")
	_check(state.consume_empty_offer(offer, false)["ok"] and state.pending_choices == 1, "empty consumes one with message")
	_check(not state.consume_empty_offer(offer, false)["ok"] and state.pending_choices == 1, "empty replay cannot eat next choice")
	var next := state.open_offer(false, rng)
	_check(next["choice_id"] != offer["choice_id"] and state.consume_empty_offer(next, false)["ok"] and state.pending_choices == 0, "sequential exhaustion terminates")
	state.reset()
	_check(not state.has_open_offer() and state.card_sockets.is_empty(), "reset drops transient effects and offers")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _combined_and_scalar() -> void:
	var registry := BuildEffectCatalog.new()
	var snapshot := Fixture.snapshot()
	var scalar := EffectDefinition.new()
	scalar.id = &"fixture_range"
	scalar.family_id = &"fixture_range"
	scalar.kind = EffectDefinition.Kind.SKILL_RULE
	scalar.handler_id = EffectDefinition.Handler.SKILL_SCALAR
	scalar.axis = &"range"
	scalar.unit = &"units"
	scalar.magnitude = 10.0
	scalar.increased = 0.1
	scalar.limit = 900.0
	scalar.target_skill_ids = [&"fire_spear"]
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		_check(registry.register_definition(origin, Fixture.definition(origin, origin, [scalar, Fixture.proc_effect()]))["ok"], "compatible scalar/proc registry")
	snapshot.equipped = {&"weapon": &"equipment"}
	var state := {"augment_stacks": {&"augment": 1}, "card_sockets": {&"equipment": &"card"}}
	var composed := BuildEffectComposer.compose(snapshot, state, [], registry)
	var captured := SkillEffectResolver.capture(&"fire_spear", 1, composed)
	var base := ClassCatalog.skill_definition(&"fire_spear").rank_definition(1).range
	_check(is_equal_approx(captured["values"]["range"], minf(900.0, (base + 30.0) * 1.3)), "three origins add flats/increased once")
	_check(composed["procs"].size() == 1 and composed["procs"][0]["flat"] == 15.0, "three compatible proc origins compose before one claim")
	scalar.axis = &"cooldown"
	_check(BuildEffectCatalog.validate_effect(scalar)["error_code"] == &"unsupported_skill_axis", "unproved axis rejected explicitly")
	for identity: Array in [[&"swordsman", &""], [&"mage", &""], [&"archer", &""], [&"swordsman", &"defender"], [&"swordsman", &"berserker"], [&"mage", &"elementalist"], [&"mage", &"spiritualist"], [&"mage", &"mg_ar"], [&"archer", &"sentinel"], [&"archer", &"hunter"]]:
		var legal := BuildSnapshot.new()
		legal.base_class_id = identity[0]
		legal.evolution_id = identity[1]
		legal.job_level = 40
		_check(BuildEffectComposer.compose(legal, {"augment_stacks": {&"vitality": 1}})["ok"], "available identity admits general effect")
	var capped := Fixture.proc_effect(&"capped", &"same_family", 100.0)
	registry = BuildEffectCatalog.new()
	registry.register_definition(&"equipment", Fixture.definition(&"equipment", &"saturated", [capped]))
	registry.register_definition(&"augment", Fixture.definition(&"augment", &"no_gain", [Fixture.proc_effect(&"extra", &"same_family")]))
	var run := RunState.new(&"mage")
	run.build_snapshot.equipped = {&"weapon": &"saturated"}
	run.set_effect_catalog(registry)
	run.queue_choice()
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	_check(run.open_offer(false, rng)["empty"], "fully capped proc filtered despite new source provenance")

func _snapshot_removal() -> void:
	var state := RunState.new(&"mage")
	var before := state.composed_build()
	var previous_revision := state.composition_revision()
	var saved := state.build_snapshot
	state.build_snapshot = null
	_check(state.composed_build()["error_code"] == &"missing_snapshot" and not state.effects_valid(), "removed snapshot cannot apply stale cached effects")
	var absent_revision := state.composition_revision()
	_check(absent_revision > previous_revision and state.composition_revision() == absent_revision, "missing snapshot invalidates once, repeated HUD queries stay stable")
	_check(state.skill_effect_capture(&"fire_spear")["error_code"] == &"invalid_composed_build", "removed snapshot does not publish cached skill capture")
	state.build_snapshot = saved
	var restored := state.composed_build()
	_check(restored["ok"] and state.composition_revision() > absent_revision and restored["breakdown"].values() == before["breakdown"].values(), "restoring same snapshot recomposes without stale failure")
