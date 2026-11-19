extends SceneTree
## E12 H1 — HUD seam (contract docs/epics/e12_contract.md §2 and §3; API
## docs/epics/e12/h1_hud_seam_api.md):
## - ClassKit.hud_state default, KitHudState.validate (every error code), the fixture kit
##   covering the whole ragrpg_kit_hud_v1 format, PlayerActor.kit_hud_state (invalid -> {}
##   with one warning per kit and code), purity (100 reads, paused tree);
## - CombatActor.cast_progress for the player (flat and world preparation, instant casts,
##   pause, cancellation) and the enemy (_mob_cast with and without cast_time, category);
## - CombatActor.overhead_bar_y equals the HP bar position of _draw.
## Fixture kits only (installed over sp_ac and mg_ac); no profile or save.
const FixtureHudKit = preload("res://scripts/classes/fixture/hud/fixture_hud_kit.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const F1Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")

const CAST_KEYS: Array[String] = ["active", "skill_id", "label", "total", "remaining", "kind", "category"]

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _close(a: float, b: float, label: String) -> void:
	_check(absf(a - b) <= 0.0001, "%s (%s vs %s)" % [label, a, b])

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	KitHudState.reset_reports()
	_check_defaults()
	_check_production_kits()
	_check(ClassKitRegistry.install_fixture(&"sp_ac", FixtureHudKit.new(&"sp_ac")) and ClassKitRegistry.install_fixture(&"mg_ac", FixtureHudKit.new(&"mg_ac")), "HUD fixture kits install over sp_ac and mg_ac")
	var player := _player(_snapshot(&"swordsman", &"sp_ac", [] as Array[StringName]))
	root.add_child(player)
	_check(player.kit != null and player.kit.get_script() == FixtureHudKit, "the player carries the HUD fixture kit")
	_check_fixture_coverage(player)
	_check_invalid_variants(player)
	_check_validator_edges(player)
	_check_player_read(player)
	_check_purity(player)
	_check_flat_cast(player)
	root.remove_child(player)
	player.free()
	_check_world_cast()
	_check_enemy_cast()
	_check_overhead_bar_y()
	_check_actor_boundaries()
	ClassKitRegistry.clear_fixtures()
	KitHudState.reset_reports()
	print("E12 HUD seam: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Builders ----------------------------------------------------------------------------

func _snapshot(origin: StringName, evolution: StringName, base_skills: Array[StringName]) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "e12-hud-" + String(evolution)
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = origin
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(origin, evolution)
	snapshot.skill_ranks = {}
	for skill: StringName in base_skills: snapshot.skill_ranks[skill] = 1
	var kit_skills := ClassKitRegistry.skill_ids(evolution)
	for skill: StringName in kit_skills: snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	var slots: Array = []
	for skill: StringName in base_skills: slots.append(skill)
	for index: int in [0, 2, 3]:
		if slots.size() < 5 and index < kit_skills.size(): slots.append(kit_skills[index])
	while slots.size() < 5: slots.append(null)
	snapshot.active_slots = slots
	return snapshot

func _player(snapshot: BuildSnapshot) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build(snapshot.character_id, snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _fixture(player: PlayerActor) -> FixtureHudKit:
	return player.kit as FixtureHudKit

## Snapshot fields of the kit, from the fragments of every script of its chain.
func _fragment_fields(kit: ClassKit, registry: SnapshotRegistry) -> Array[String]:
	var fields: Array[String] = []
	var script: Script = kit.get_script()
	while script != null:
		var schema: Dictionary = registry.schemas.get(script.resource_path, {})
		for field: String in schema.get("fields", []):
			if field not in fields: fields.append(field)
		script = script.get_base_script()
	return fields

func _field_values(kit: ClassKit, fields: Array[String]) -> Dictionary:
	var values := {}
	for field: String in fields:
		var value: Variant = kit.get(field)
		values[field] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return values

func _cast_shape_ok(progress: Dictionary) -> bool:
	if progress.size() != CAST_KEYS.size(): return false
	for key: String in CAST_KEYS:
		if not progress.has(key): return false
	return typeof(progress["skill_id"]) == TYPE_STRING_NAME and typeof(progress["label"]) == TYPE_STRING and not String(progress["label"]).is_empty() and typeof(progress["kind"]) == TYPE_STRING_NAME and typeof(progress["category"]) == TYPE_STRING_NAME and float(progress["total"]) > 0.0 and float(progress["remaining"]) >= 0.0 and float(progress["remaining"]) <= float(progress["total"])

# --- Defaults and production kits ----------------------------------------------------------

func _check_defaults() -> void:
	_check(ClassKit.new().hud_state(null).is_empty(), "ClassKit.hud_state defaults to {}")
	var base_kit := ClassKit.new()
	_check(KitHudState.validate({}, base_kit)["ok"] and KitHudState.validate({}, null)["ok"], "{} is valid (a kit without HUD), even without a kit")
	_check(KitHudState.SCHEMA == "ragrpg_kit_hud_v1" and KitHudState.ERROR_CODES.size() == 10, "schema name and the ten error codes of §2.3")
	var plain := CombatActor.new()
	_check(plain.cast_progress() == {"active": false}, "CombatActor.cast_progress defaults to no cast")
	plain.free()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var kitless := PlayerActor.new()
	kitless.configure(navigation, RunState.new(&"swordsman"))
	_check(not kitless.has_kit() and kitless.kit_hud_state().is_empty(), "a player without a kit has no HUD state")
	_check(kitless.cast_progress() == {"active": false}, "an idle player has no cast")
	kitless.free()

## The four production kits keep their H1 answer valid (H2 fills them later); the
## answer is recorded in the log, not pinned, so H2 does not edit this test.
func _check_production_kits() -> void:
	var registry := SnapshotRegistry.new()
	for id: StringName in ClassKitRegistry.ids():
		var origin: StringName = ClassKitRegistry.IDENTITIES[id]["origin"]
		var player := _player(_snapshot(origin, id, [] as Array[StringName]))
		if player.kit == null:
			_check(false, "production kit %s attaches to its player" % id)
			player.free()
			continue
		var fields := _fragment_fields(player.kit, registry)
		var before := _field_values(player.kit, fields)
		var clock := player.kit_time
		var state := player.kit.hud_state(player)
		for _index: int in 99: player.kit.hud_state(player)
		_check(KitHudState.validate(state, player.kit)["ok"], "production kit %s answers a valid HUD state" % id)
		_check(player.kit_hud_state() == state, "PlayerActor.kit_hud_state returns the production answer of %s" % id)
		_check(_field_values(player.kit, fields) == before and player.kit_time == clock, "100 reads keep the %s fragment fields and kit_time" % id)
		print("E12 H1 baseline: production kit %s hud_state keys = %s" % [id, str(state.keys())])
		player.free()

# --- Format: fixture coverage, invalid variants, validator edges ---------------------------

func _check_fixture_coverage(player: PlayerActor) -> void:
	var kit := _fixture(player)
	_check(FixtureHudKit.variants().size() == 2 + KitHudState.ERROR_CODES.size(), "one fixture variant per error code plus valid and empty")
	kit.hud_variant = FixtureHudKit.VALID
	var state := kit.hud_state(player)
	var result := KitHudState.validate(state, kit)
	_check(result["ok"], "the full fixture DTO validates: %s" % str(result))
	var top: Array = state.keys()
	top.sort()
	var expected_top: Array = KitHudState.TOP_KEYS.duplicate()
	expected_top.sort()
	_check(top == expected_top, "the fixture uses every top-level key")
	_check(_covers(state["resources"], KitHudState.RESOURCE_KEYS), "the fixture resources use every resource key")
	_check(_covers(state["zones"], KitHudState.ZONE_KEYS), "the fixture zones use every zone key")
	_check(_covers(state["target_marks"], KitHudState.MARK_KEYS), "the fixture marks use every mark key")
	_check(_covers((state["skills"] as Dictionary).values(), KitHudState.SKILL_KEYS), "the fixture skills use every skill key")
	_check(_values_of(state["resources"], "kind") == {&"pips": true, &"charges": true, &"timer": true}, "every resource kind is present")
	var unlimited := 0
	for resource: Dictionary in state["resources"]:
		if bool(resource.get("unlimited", false)): unlimited += 1
	_check(unlimited == 1, "one unlimited pips resource with its deadline")
	_check(_values_of(state["target_marks"], "kind") == {&"pips": true, &"badge": true}, "both mark kinds are present")
	_check(_values_of(state["zones"], "space") == {&"world": true, &"flat": true}, "zones in both spaces")
	var shapes := _values_of(state["zones"], "shape")
	_check(shapes.size() == SanctuaryRules.SHAPES.size() and shapes.has_all(SanctuaryRules.SHAPES), "zones in every Sanctuary shape")
	var ready := 0
	for entry: Dictionary in (state["skills"] as Dictionary).values():
		if bool(entry["ready"]): ready += 1
	_check(ready == 1 and (state["skills"] as Dictionary).size() == 2, "one ready and one refused kit skill")
	kit.hud_variant = FixtureHudKit.EMPTY
	_check(kit.hud_state(player).is_empty(), "the empty variant answers {}")
	kit.hud_variant = FixtureHudKit.VALID

func _covers(entries: Variant, keys: Array[String]) -> bool:
	var seen := {}
	for entry: Variant in entries:
		for key: Variant in (entry as Dictionary): seen[key] = true
	for key: String in keys:
		if not seen.has(key): return false
	return seen.size() == keys.size()

func _values_of(entries: Array, key: String) -> Dictionary:
	var seen := {}
	for entry: Dictionary in entries:
		if entry.has(key): seen[entry[key]] = true
	return seen

func _check_invalid_variants(player: PlayerActor) -> void:
	var kit := _fixture(player)
	for code: StringName in KitHudState.ERROR_CODES:
		kit.hud_variant = code
		var result := KitHudState.validate(kit.hud_state(player), kit)
		_check(not result["ok"] and result["error_code"] == code and not String(result["detail"]).is_empty(), "fixture variant %s fails with its own code: %s" % [code, str(result)])
	kit.hud_variant = FixtureHudKit.VALID

func _expect(state: Dictionary, kit: ClassKit, code: StringName, label: String) -> void:
	var result := KitHudState.validate(state, kit)
	if code.is_empty(): _check(result["ok"], label + ": " + str(result))
	else: _check(not result["ok"] and result["error_code"] == code, "%s: %s" % [label, str(result)])

func _check_validator_edges(player: PlayerActor) -> void:
	var kit := _fixture(player)
	var base := kit.valid_state(player)
	var copy := base.duplicate(true)
	KitHudState.validate(copy, kit)
	_check(copy == base, "validate does not change the state")
	_expect({"schema": KitHudState.SCHEMA, "kit_id": &"sp_ac"}, kit, &"", "schema and kit_id alone are valid")
	_expect({"kit_id": &"sp_ac"}, kit, KitHudState.INVALID_SCHEMA, "missing schema")
	_expect({"schema": &"ragrpg_kit_hud_v1", "kit_id": &"sp_ac"}, kit, KitHudState.INVALID_SCHEMA, "schema must be a String")
	_expect({"schema": KitHudState.SCHEMA, "kit_id": "sp_ac"}, kit, KitHudState.KIT_MISMATCH, "kit_id must be a StringName")
	_expect({"schema": KitHudState.SCHEMA, "kit_id": &"sp_ac"}, null, KitHudState.KIT_MISMATCH, "no kit to compare")
	_expect({"schema": KitHudState.SCHEMA, "kit_id": &"sp_ac", 7: true}, kit, KitHudState.UNKNOWN_KEY, "non-String top-level key")
	# Resources.
	var cases: Array = [
		["resources", func(s: Dictionary) -> void: s["resources"] = {}, KitHudState.INVALID_RESOURCE, "resources must be an Array"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["id"] = &"grace", KitHudState.INVALID_RESOURCE, "resource id without a kit or system prefix"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["id"] = &"paladin_", KitHudState.INVALID_RESOURCE, "resource id equal to the bare prefix"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["id"] = "paladin_grace", KitHudState.INVALID_RESOURCE, "resource id must be a StringName"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["color"] = Color.RED, KitHudState.INVALID_RESOURCE, "unknown resource key"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["label"] = "  ", KitHudState.INVALID_RESOURCE, "blank label"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["kind"] = &"bar", KitHudState.INVALID_RESOURCE, "unknown resource kind"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["value"] = 3.0, KitHudState.INVALID_RESOURCE, "pips value must be an int"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["max"] = 0, KitHudState.INVALID_RESOURCE, "pips max below 1"],
		["resources", func(s: Dictionary) -> void: s["resources"][0]["value"] = -1, KitHudState.INVALID_RESOURCE, "negative pips value"],
		["resources", func(s: Dictionary) -> void: s["resources"][0].erase("unlimited"), &"", "unlimited is optional"],
		["resources", func(s: Dictionary) -> void: (s["resources"][0] as Dictionary).merge({"remaining": 1.0, "total": 2.0}, true), KitHudState.INVALID_RESOURCE, "limited pips carry no deadline"],
		["resources", func(s: Dictionary) -> void: s["resources"][1]["value"] = 9, &"", "unlimited pips may exceed max"],
		["resources", func(s: Dictionary) -> void: s["resources"][1].erase("total"), KitHudState.INVALID_RESOURCE, "unlimited pips need the full deadline"],
		["resources", func(s: Dictionary) -> void: s["resources"][2]["unlimited"] = false, KitHudState.INVALID_RESOURCE, "unlimited only on pips"],
		["resources", func(s: Dictionary) -> void: s["resources"][2]["remaining"] = 7.0, KitHudState.INVALID_RESOURCE, "recharge above its total"],
		["resources", func(s: Dictionary) -> void: _erase(s["resources"][2], ["remaining", "total"]), &"", "charges without recharge (full)"],
		["resources", func(s: Dictionary) -> void: s["resources"][2]["value"] = 3, KitHudState.INVALID_RESOURCE, "charges above max"],
		["resources", func(s: Dictionary) -> void: s["resources"][3]["value"] = 1, KitHudState.INVALID_RESOURCE, "timer has no value"],
		["resources", func(s: Dictionary) -> void: s["resources"][3].erase("total"), KitHudState.INVALID_RESOURCE, "timer needs its total"],
		["resources", func(s: Dictionary) -> void: (s["resources"][3] as Dictionary).merge({"remaining": 0.0, "total": 0.0}, true), KitHudState.INVALID_RESOURCE, "timer total above zero"],
		["resources", func(s: Dictionary) -> void: (s["resources"][3] as Dictionary).merge({"remaining": 3, "total": 10}, true), &"", "integer seconds are accepted as numbers"],
		["resources", func(s: Dictionary) -> void: s["resources"][3]["element"] = &"water", KitHudState.INVALID_RESOURCE, "unknown element"],
		["resources", func(s: Dictionary) -> void: s["resources"][3]["element"] = "fire", KitHudState.INVALID_RESOURCE, "element must be a StringName"],
		["resources", func(s: Dictionary) -> void: s["resources"].append(7), KitHudState.INVALID_RESOURCE, "resource entry must be a Dictionary"],
		["resources", func(s: Dictionary) -> void: s["resources"][3]["id"] = &"paladin_grace", KitHudState.DUPLICATE_RESOURCE, "duplicate resource id across kinds"],
		# Skills.
		["skills", func(s: Dictionary) -> void: s["skills"] = [], KitHudState.INVALID_SKILL, "skills must be a Dictionary"],
		["skills", func(s: Dictionary) -> void: s["skills"]["paladin_oath_hour"] = {"ready": true}, KitHudState.UNKNOWN_SKILL, "skill keys must be StringNames (a String key not already present)"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"duelist_parry"] = {"ready": true}, KitHudState.UNKNOWN_SKILL, "skill of another kit"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": true}, &"", "reason is optional when ready"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": true, "reason": &"fixture_refused"}, KitHudState.INVALID_SKILL, "ready with a reason"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": 1}, KitHudState.INVALID_SKILL, "ready must be a bool"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": true, "charges": 1}, KitHudState.INVALID_SKILL, "charges without max_charges"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": true, "charges": 3, "max_charges": 2}, KitHudState.INVALID_SKILL, "charges above max_charges"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": true, "recharge_total": 2.0}, KitHudState.INVALID_SKILL, "recharge_total without recharge_remaining"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = {"ready": true, "cooldown": 1.0}, KitHudState.INVALID_SKILL, "unknown skill key"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_oath"] = true, KitHudState.INVALID_SKILL, "skill entry must be a Dictionary"],
		# Zones.
		["zones", func(s: Dictionary) -> void: s["zones"][0].erase("half_angle"), KitHudState.INVALID_ZONE, "cone without half_angle"],
		["zones", func(s: Dictionary) -> void: s["zones"][0].erase("facing"), KitHudState.INVALID_ZONE, "cone without facing"],
		["zones", func(s: Dictionary) -> void: s["zones"][0]["half_angle"] = 4.0, KitHudState.INVALID_ZONE, "half_angle above PI"],
		["zones", func(s: Dictionary) -> void: s["zones"][0]["facing"] = Vector3.ZERO, KitHudState.INVALID_ZONE, "zero facing"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["half_angle"] = 0.5, KitHudState.INVALID_ZONE, "half_angle only on cones"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["center"] = Vector3(1, 2, 3), KitHudState.INVALID_ZONE, "flat centre keeps z = 0"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["center"] = Vector2(1, 2), KitHudState.INVALID_ZONE, "centre must be a Vector3"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["shape"] = &"square", KitHudState.INVALID_ZONE, "unknown shape"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["space"] = &"sky", KitHudState.INVALID_ZONE, "unknown space"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["role"] = &"", KitHudState.INVALID_ZONE, "empty role"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["remaining"] = 10.0, KitHudState.INVALID_ZONE, "zone deadline above its total"],
		["zones", func(s: Dictionary) -> void: s["zones"][1]["anchor"] = &"owner", KitHudState.INVALID_ZONE, "unknown zone key"],
		# Marks.
		["target_marks", func(s: Dictionary) -> void: s["target_marks"][1]["value"] = 1, KitHudState.INVALID_MARK, "badge carries no value"],
		["target_marks", func(s: Dictionary) -> void: s["target_marks"][0]["target_id"] = 0, KitHudState.INVALID_MARK, "target_id above zero"],
		["target_marks", func(s: Dictionary) -> void: s["target_marks"][0]["kind"] = &"timer", KitHudState.INVALID_MARK, "unknown mark kind"],
		["target_marks", func(s: Dictionary) -> void: s["target_marks"][0]["max"] = 0, KitHudState.INVALID_MARK, "pips mark max below 1"],
		["target_marks", func(s: Dictionary) -> void: s["target_marks"][0]["value"] = 0, &"", "zero Sentence pips are valid"],
		["target_marks", func(s: Dictionary) -> void: s["target_marks"].append(s["target_marks"][0].duplicate()), KitHudState.INVALID_MARK, "same key twice on one target"],
		# Numbers.
		["zones", func(s: Dictionary) -> void: s["zones"][0]["center"] = Vector3(NAN, 0, 0), KitHudState.NON_FINITE, "NaN in a zone centre"],
		["skills", func(s: Dictionary) -> void: s["skills"][&"paladin_consecrated_impact"]["recharge_remaining"] = -INF, KitHudState.NON_FINITE, "infinite recharge"],
	]
	for row: Array in cases:
		var state := kit.valid_state(player)
		(row[1] as Callable).call(state)
		_expect(state, kit, row[2], "%s: %s" % [row[0], row[3]])

func _erase(entry: Dictionary, keys: Array) -> void:
	for key: Variant in keys: entry.erase(key)

func _check_player_read(player: PlayerActor) -> void:
	var kit := _fixture(player)
	KitHudState.reset_reports()
	kit.hud_variant = FixtureHudKit.VALID
	_check(player.kit_hud_state() == kit.hud_state(player), "kit_hud_state returns the validated kit answer")
	kit.hud_variant = FixtureHudKit.EMPTY
	_check(player.kit_hud_state().is_empty() and KitHudState.reported_warnings().is_empty(), "{} passes without a warning")
	var expected: Array[String] = []
	for code: StringName in KitHudState.ERROR_CODES:
		kit.hud_variant = code
		var answers := 0
		for _index: int in 5:
			if player.kit_hud_state().is_empty(): answers += 1
		_check(answers == 5, "invalid %s becomes {} on every read" % code)
		expected.append("sp_ac:" + String(code))
	expected.sort()
	_check(KitHudState.reported_warnings() == expected, "one warning per kit and code, never repeated: %s" % str(KitHudState.reported_warnings()))
	kit.hud_variant = FixtureHudKit.VALID
	_check(not player.kit_hud_state().is_empty() and KitHudState.reported_warnings() == expected, "a valid answer after invalid ones reads normally")

func _check_purity(player: PlayerActor) -> void:
	var kit := _fixture(player)
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty() and registry.schemas.has("res://scripts/classes/fixture/hud/fixture_hud_kit.gd"), "the HUD fixture fragment merges without errors")
	registry._fields(kit)
	_check(registry._error.is_empty(), "the HUD fixture kit state is fully declared: %s" % str(registry._error))
	var fields := _fragment_fields(kit, registry)
	_check("hud_variant" in fields and "calls" in fields and "evolution_id" in fields, "fragment fields cover the whole kit chain")
	var before := _field_values(kit, fields)
	var clock := player.kit_time
	var signals := [0]
	var count := func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void: signals[0] += 1
	player.resources_changed.connect(count)
	player.presentation_action.connect(count)
	var first := player.kit_hud_state()
	var stable := true
	for _index: int in 100:
		if player.kit_hud_state() != first: stable = false
	_check(stable, "100 reads give the same answer")
	_check(_field_values(kit, fields) == before, "100 reads keep every fragment field of the kit")
	_check(player.kit_time == clock and signals[0] == 0, "100 reads keep kit_time and emit nothing")
	paused = true
	_check(player.kit_hud_state() == first and player.cast_progress() == {"active": false}, "reads work while the tree is paused")
	player._process(1.0)
	_check(player.kit_time == clock and _field_values(kit, fields) == before, "a paused tick advances nothing")
	paused = false
	player.resources_changed.disconnect(count)
	player.presentation_action.disconnect(count)

# --- Cast clock ------------------------------------------------------------------------------

func _check_flat_cast(player: PlayerActor) -> void:
	var kit_skills := ClassKitRegistry.skill_ids(&"sp_ac")
	var prepared: StringName = kit_skills[3]
	var instant: StringName = kit_skills[0]
	var total := player.skill_cast_time(prepared)
	_check(total > 0.0 and player.skill_cast_time(instant) == 0.0, "fixture slot 3 has preparation and slot 0 has none")
	var actions: Array[StringName] = []
	var on_action := func(action: StringName, _direction: Vector2, _duration: float) -> void: actions.append(action)
	player.presentation_action.connect(on_action)
	# Start.
	_check(player.begin_skill_cast(prepared, player.global_position + Vector2(40, 0)), "flat preparation starts")
	var progress := player.cast_progress()
	_check(_cast_shape_ok(progress) and bool(progress["active"]), "flat cast has the full shape: %s" % str(progress))
	_check(progress["skill_id"] == prepared and progress["label"] == ClassCatalog.skill_definition(prepared).display_name and progress["kind"] == &"cast" and progress["category"] == &"player", "flat cast names the skill, kind and category")
	_close(float(progress["total"]), total, "flat total is the canonical cast time")
	_close(float(progress["remaining"]), total, "flat cast starts full")
	# Middle and pause.
	player._process(total * 0.5)
	_close(float(player.cast_progress()["remaining"]), total * 0.5, "flat cast halfway")
	var held := player.cast_progress()
	paused = true
	player._process(total)
	_check(player.cast_progress() == held, "a paused tree keeps the flat remaining time")
	paused = false
	# Esc (main.gd _cancel_casting -> cancel_active_cast).
	_check(player.cancel_active_cast() and player.cast_progress() == {"active": false} and actions.has(&"cast_cancel"), "Esc cancels: no cast and cast_cancel presented")
	# Movement (move_to cancels).
	actions.clear()
	_check(player.begin_skill_cast(prepared, player.global_position + Vector2(40, 0)) and bool(player.cast_progress()["active"]), "flat preparation starts again")
	player.move_to(player.global_position + Vector2(-80, 0))
	_check(player.cast_progress() == {"active": false} and actions.has(&"cast_cancel"), "moving cancels: no cast")
	# End.
	player.global_position = Vector2(400, 350)
	player.velocity = Vector2.ZERO
	_check(player.begin_skill_cast(prepared, player.global_position + Vector2(40, 0)), "flat preparation starts for the end")
	var ready := [0]
	var on_ready := func(_skill: StringName, _point: Vector2, _target: int) -> void: ready[0] += 1
	player.skill_cast_ready.connect(on_ready)
	player._process(total * 0.75)
	_check(bool(player.cast_progress()["active"]), "still preparing before the end")
	player._process(total)
	_check(player.cast_progress() == {"active": false} and ready[0] == 1, "the finished preparation shows no cast and fires once")
	player.skill_cast_ready.disconnect(on_ready)
	# Instant: never active, even while its own signals run.
	var seen: Array[bool] = []
	var watch := func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void: seen.append(bool(player.cast_progress()["active"]))
	player.presentation_action.connect(watch)
	player.resources_changed.connect(watch)
	_check(not player.begin_skill_cast(instant, player.global_position), "an instant skill has no preparation")
	_check(player.use_kit_skill(instant, player.global_position), "the instant kit skill resolves")
	_check(not seen.is_empty() and not seen.has(true) and player.cast_progress() == {"active": false}, "an instant cast is never active: %s" % str(seen))
	player.presentation_action.disconnect(watch)
	player.resources_changed.disconnect(watch)
	player.presentation_action.disconnect(on_action)

func _check_world_cast() -> void:
	if not F1Fixture.sources_current():
		_check(false, "F1 world fixture is current")
		return
	var input := F1Fixture.make()
	var built := ExpeditionAssembler.build(input)
	_check(built["ok"], "world fixture builds")
	if not built["ok"]: return
	var geometry := WorldGeometry.new()
	geometry.configure(built["data"]["manifest"], "sample")
	var profile := input.traversal.to_data()
	var mage := _player(_snapshot(&"mage", &"mg_ac", [&"fireball", &"teleport"] as Array[StringName]))
	root.add_child(mage)
	_check(mage.bind_world_geometry(geometry, F1Fixture.point("root", Vector3(50, 0, 150)), profile, "mage")["ok"], "mage binds the world")
	mage.set_process(false)
	# Instant world skill: never active.
	var seen: Array[bool] = []
	var watch := func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void: seen.append(bool(mage.cast_progress()["active"]))
	mage.presentation_action.connect(watch)
	mage.resources_changed.connect(watch)
	_check(mage.skill_cast_time(&"teleport") == 0.0, "teleport has no preparation")
	_check(mage.use_world_teleport(F1Fixture.point("root", Vector3(80, 0, 150)), geometry.geometry_revision), "world teleport commits")
	_check(not seen.has(true) and mage.cast_progress() == {"active": false}, "an instant world skill is never active: %s" % str(seen))
	mage.presentation_action.disconnect(watch)
	mage.resources_changed.disconnect(watch)
	# The fixture kit slot 3 always prepares (variable 0.5 s), whatever the build stats.
	var prepared: StringName = ClassKitRegistry.skill_ids(&"mg_ac")[3]
	var actors: Array[CombatActor] = []
	var total := mage.skill_cast_time(prepared)
	_check(total > 0.0, "the fixture world skill has preparation")
	var requested := mage.request_world_skill(prepared, null, Vector3.RIGHT, null, actors, geometry.geometry_revision)
	var progress := mage.cast_progress()
	_check(requested.get("ok", false) and _cast_shape_ok(progress) and bool(progress["active"]), "world preparation starts with the full shape: %s / %s" % [str(requested), str(progress)])
	_check(progress.get("skill_id") == prepared and progress.get("label") == ClassCatalog.skill_definition(prepared).display_name and progress.get("category") == &"player", "world cast names the skill and category")
	_close(float(progress.get("total", 0.0)), total, "world total is the canonical cast time")
	_close(float(progress.get("remaining", 0.0)), total, "world cast starts full")
	mage._advance_world_cast(total * 0.5)
	_close(float(mage.cast_progress().get("remaining", 0.0)), total * 0.5, "world cast halfway")
	var held := mage.cast_progress()
	paused = true
	mage._process(total)
	_check(mage.cast_progress() == held, "a paused tree keeps the world remaining time")
	paused = false
	# Esc and movement: main.gd calls cancel_active_cast for both in the world (world move
	# adopts a route after cancel_active_cast), so the actor sees one cancellation path.
	_check(mage.cancel_active_cast() and mage.cast_progress() == {"active": false}, "Esc or a world move cancels: no cast")
	requested = mage.request_world_skill(prepared, null, Vector3.RIGHT, null, actors, geometry.geometry_revision)
	_check(requested.get("ok", false) and bool(mage.cast_progress().get("active", false)), "world preparation starts again")
	mage._advance_world_cast(total * 0.75)
	_check(bool(mage.cast_progress().get("active", false)), "still preparing before the world end")
	mage._advance_world_cast(total)
	_check(mage.cast_progress() == {"active": false}, "the finished world preparation shows no cast")
	root.remove_child(mage)
	mage.free()

func _check_enemy_cast() -> void:
	var catalog := BuildContentLoader.pilot().mob_catalog()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 1000), [], 0)
	var hero := PlayerActor.new()
	hero.configure(navigation, RunState.new(&"mage"))
	hero.position = Vector2(200, 200)
	root.add_child(hero)
	hero.set_process(false)
	var skill: StringName = MobSkillAdapters.IDS[0]
	var definition := MobDefinition.new()
	definition.id = &"e12_hud_caster"
	definition.display_name = "Conjurador de teste"
	definition.fixed_level = 7
	definition.archetype = &"archer"
	definition.animation_kind = &"archer"
	definition.base_category = &"elite"
	definition.allowed_occurrence_categories = [&"elite", &"rare_elite"]
	definition.skill_ids = [skill]
	definition.skill_ranks = {skill: 3}
	for axis: StringName in StatCalculator.PRIMARY_IDS: definition.primary_attributes[axis] = 3
	_check(catalog.register_definition(definition)["ok"], "caster species registers")
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "e12_hud_caster"
	occurrence.mob_base_id = definition.id
	occurrence.category_id = &"elite"
	occurrence.origin_id = &"fixture_arena"
	var enemy := EnemyActor.new()
	_check(enemy.configure_occurrence(occurrence, catalog, navigation, hero)["ok"], "caster configures")
	enemy.position = Vector2(240, 200)
	root.add_child(enemy)
	enemy.set_process(false)
	var actions: Array[StringName] = []
	enemy.presentation_action.connect(func(action: StringName, _direction: Vector2, _duration: float) -> void: actions.append(action))
	_check(enemy.cast_progress() == {"active": false}, "an idle mob has no cast")
	_check(enemy._try_declared_skill() and not enemy._mob_cast.is_empty(), "the mob prepares its declared skill")
	var total := float(enemy._mob_cast["cast_time"])
	var progress := enemy.cast_progress()
	_check(total > 0.0 and _cast_shape_ok(progress) and bool(progress["active"]), "mob cast with cast_time has the full shape: %s" % str(progress))
	_check(progress["skill_id"] == skill and progress["label"] == ClassCatalog.skill_definition(skill).display_name and progress["kind"] == &"cast" and progress["category"] == &"elite", "mob cast names the skill and the occurrence category")
	_close(float(progress["total"]), total, "mob total is the captured cast time")
	_close(float(progress["remaining"]), total, "mob cast starts full")
	enemy._advance_mob_cast(total * 0.5)
	_close(float(enemy.cast_progress()["remaining"]), total * 0.5, "mob cast halfway")
	var held := enemy.cast_progress()
	paused = true
	enemy._process(total)
	_check(enemy.cast_progress() == held, "a paused tree keeps the mob remaining time")
	paused = false
	# Category sources (same order as the flank rules, without importing them).
	enemy.occurrence.category_id = &"rare_elite"
	_check(enemy.cast_progress()["category"] == &"rare_elite", "rare_elite occurrence")
	enemy.occurrence.category_id = &"boss"
	_check(enemy.cast_progress()["category"] == &"boss", "boss occurrence")
	enemy.occurrence.category_id = &"unknown"
	enemy.hard_controls.boss = true
	_check(enemy.cast_progress()["category"] == &"boss", "boss controls without a known category")
	enemy.hard_controls.boss = false
	_check(enemy.cast_progress()["category"] == &"normal", "otherwise normal")
	enemy.occurrence.category_id = &"elite"
	# Cancellation (clear_statuses is the death/recovery path).
	enemy.clear_statuses()
	_check(enemy.cast_progress() == {"active": false} and actions.has(&"cast_cancel"), "a cancelled mob cast is no longer active")
	# A capture without cast_time is never active.
	var captured := MobSkillAdapters.capture(skill, 3, enemy.stat_breakdown, enemy.get_instance_id(), hero.get_instance_id())
	captured["cast_time"] = 0.0
	captured["remaining"] = 0.0
	enemy._mob_cast = captured
	_check(enemy.cast_progress() == {"active": false}, "a mob cast without cast_time is never active")
	enemy._mob_cast = {"captured_target": "old"}
	_check(enemy.cast_progress() == {"active": false}, "a mob record without cast_time is never active")
	enemy._mob_cast = {}
	root.remove_child(enemy)
	enemy.free()
	root.remove_child(hero)
	hero.free()

# --- Overhead reference and boundaries --------------------------------------------------------

func _check_overhead_bar_y() -> void:
	var actor := CombatActor.new()
	_close(actor.overhead_bar_y(), -54.0, "without a sprite the HP bar sits at -54")
	actor.sprite_visual_scale = 2.0
	_close(actor.overhead_bar_y(), -108.0, "the HP bar follows the visual scale")
	var image := Image.create(16, 40, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(2, 8, 12, 30), Color.WHITE)
	actor.set_pilot_sprite(ImageTexture.create_from_image(image))
	_close(actor.overhead_bar_y(), -actor._sprite_visible_height * 2.0 - 8.0, "with a sprite the HP bar sits above the visible height")
	actor.free()

func _check_actor_boundaries() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/actors/player_actor.gd")
	var typed_reference := RegEx.create_from_string("(as|:|->)\\s*EnemyActor\\b|EnemyActor\\.")
	_check(typed_reference.search(player_source) == null, "player_actor.gd still does not reference EnemyActor (A10)")
	var flank_reference := RegEx.create_from_string("Flank(Rules|Authority)\\b|scripts/systems/flank")
	for path: String in ["res://scripts/actors/combat_actor.gd", "res://scripts/actors/player_actor.gd", "res://scripts/actors/enemy_actor.gd"]:
		_check(flank_reference.search(FileAccess.get_file_as_string(path)) == null, "%s does not import the flank system" % path)
	var draw_source := FileAccess.get_file_as_string("res://scripts/actors/combat_actor.gd")
	_check(draw_source.contains("var bar_y := overhead_bar_y()"), "_draw takes the HP bar height from overhead_bar_y")
