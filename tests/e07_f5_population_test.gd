extends SceneTree
const F = preload("res://tests/fixtures/e07/f5/campaign_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	var generated := ExpeditionAssembler.build(F.input())
	check(generated["ok"], "real four-stage manifest is generated")
	if not generated["ok"]: print(generated); quit(1); return
	var manifest: ExpeditionManifest = generated["data"]["manifest"]
	var loaded := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(), true)
	check(loaded["ok"], "canonical gameplay catalog")
	if not loaded["ok"]: quit(1); return
	var made := ExpeditionCampaignState.create("fixture_expedition", "fixture_character", manifest, loaded["catalog"].mob_catalog(), F.rules(manifest))
	check(made["ok"], "planner consumes real catalog, origin and F1 support")
	if not made["ok"]: print(made); quit(1); return
	var state: ExpeditionCampaignState = made["state"]
	var oversized: MobCatalog = loaded["catalog"].mob_catalog().copy_catalog()
	var huge := oversized.get_definition(&"test_beast_master")
	huge.collision_radius = 500.0
	oversized._definitions[huge.id] = huge # explicit malformed fixture; getters return defensive copies
	check(ExpeditionPopulationPlanner.build(manifest, oversized, F.rules(manifest)).get("error_code") == &"population_unreachable", "real mob radius is checked beyond the manifest traversal witness")
	check(loaded["catalog"].mob_catalog().get_definition(&"test_beast_master").collision_radius != 500.0, "negative fixture never mutates immutable original catalog")
	check(state.visit("entry").size() == 2 and state.visit("entry").is_empty(), "two distinct first claims, revisit empty")
	check(state.valid(), "realized campaign invariants hold after first entry")
	state.stages["entry"]["cleared_once"] = true
	check(not state.valid(), "serialized portal flags cannot bypass a living mandatory memorable")
	state.stages["entry"]["cleared_once"] = false
	check(not state.portal_view("entry_to_left")["open"], "advance initially closed")
	check(state.record_death("entry_field", 0, "field0")["ok"] and not state.stages["entry"]["cleared_once"], "unloaded mandatory boss still blocks clear")
	check(not state.clock.started, "partial clear does not arm clock")
	check(state.record_death("entry_boss", 0, "boss0")["ok"] and state.clock.started, "first complete clear arms one phase clock")
	check(state.portal_view("entry_to_left")["open"], "clear opens travel")
	state.advance(899.0)
	check(state.slots["entry_field"]["life_state"] == "dead", "long interval not early")
	check(state.advance(1.0), "exact boundary wave")
	check(state.slots["entry_field"]["life_state"] == "respawn_pending" and state.slots["entry_boss"]["life_state"] == "dead", "trash pending, boss never respawns")
	check(state.slots["left_field"]["generation"] == 0, "uncleared unloaded stage untouched")
	state.advance(2700.0)
	check(state.slots["entry_field"]["generation"] == 0 and state.slots["entry_field"]["pending_wave"] == 1, "blocked arrival keeps exactly one intent across several waves")
	check(state.admit_respawn("entry_field")["generation"] == 1, "only actual admission increments generation")
	state.advance(900.0)
	check(state.slots["entry_field"]["generation"] == 1 and state.slots["entry_field"]["life_state"] == "alive", "live generation not duplicated")
	check(state.reward_terms("entry_field")["base_xp"] == 7 and state.reward_terms("entry_field")["job_xp"] == 5 and state.reward_terms("entry_field")["equipment_factor"] == 0.5, "independent approved factors before roll and integer floor")
	check(state.record_death("entry_field", 0, "field0").get("already_applied", false), "old identical death replay does not kill generation one")
	check(state.record_death("entry_field", 0, "other").get("error_code") == &"request_conflict", "changed old death event rejected")
	check(state.record_death("entry_field", 4, "future").get("error_code") == &"stale_entity_generation", "future death rejected")
	state.clock.remaining = 100.0
	state.player_died("player1")
	check(state.revive("player1")["ok"] and state.clock.remaining == 900.0, "penalty reaching zero produces one wave and rearms")
	var wave_index := state.clock.wave_index
	check(state.revive("player1").get("already_applied", false) and state.clock.wave_index == wave_index, "same revive cannot repeat penalty")
	state.lifecycle = "suspended"
	var before := state.clock.remaining
	state.advance(6000.0)
	check(state.clock.remaining == before, "suspension has no offline advancement")
	var first := ExpeditionWaveClock.new()
	var split := ExpeditionWaveClock.new()
	first.arm(); split.arm()
	first.advance(4500.25)
	for index: int in 18001: split.advance(0.25)
	check(first.wave_index == split.wave_index and first.remaining == split.remaining, "large delta matches chronological partitioned clock")
	var combat := CombatParticipation.new()
	var boundary := ExpeditionService.new(null)
	check(boundary.campaign_command(null, null, {"kind": "revive", "event_id": {}}, "bad", 0).get("error_code") == &"invalid_payload", "malformed command fails before mutation or actor access")
	check(boundary.campaign_command(null, null, {"kind": "events", "events": [{"kind": "unknown"}]}, "bad", 0).get("error_code") == &"invalid_payload", "unknown event rejected")
	check(boundary.enter(null, null, "fixture", null, {}, "bad", 0).get("error_code") == &"invalid_manifest", "missing manifest is an explicit failure")
	check(ExpeditionRewardPolicy.scale_integer(100, 2, 7) == 49, "EXP exact rational floor, no binary underflow at integer boundary")
	check(ExpeditionRewardPolicy.scale_integer(17, 2, 7) == 8, "floor once after the generation factor, not at every intermediate generation")
	check(ExpeditionRewardPolicy.scale_integer(9007199254740991, 1, 7) == 6305039478318693, "exact integer reward limit")
	check(ExpeditionRewardPolicy.scale_integer(9007199254740991, 10000, 7) == 0, "very late generation has no positive reward floor or integer overflow")
	combat.hostile_damage(); combat.observe({}, 0.0)
	combat.observe({}, 4.75)
	check(combat.active(), "local damage keeps combat for approved grace")
	combat.observe({}, 20.0, true)
	check(combat.active(), "pause freezes combat grace")
	combat.observe({}, 0.25)
	check(not combat.active(), "exit exactly at five seconds without links")
	combat.observe({"hostile": true}, 100.0)
	check(combat.active(), "real aggro link keeps combat irrespective of clear")
	combat = CombatParticipation.new()
	combat.hostile_damage(); combat.observe({}, 5.0)
	check(not combat.active(), "damage timestamp does not add an extra tick to the five-second exit")
	print("E07 F5 population: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
