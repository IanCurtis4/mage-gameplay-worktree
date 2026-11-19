extends SceneTree
## E10a T12 (C9, A18) — the HUD of the Acólito family on the E12 seam (`ragrpg_kit_hud_v1`).
## The real `scenes/main.tscn` controller is mounted with the production base and kits:
## - the Acólito without an evolution publishes the Loucura (degrees and Delírio badge) as
##   target marks, validated against the base itself, and reaches the overlay;
## - the Sacerdote shows Graça, Santuário, Égide, Hora Santa and the Selo de Luz over the base's
##   Loucura; the Cultista shows the Êxtase and the Ídolo; the Loucura is published by the base only;
## - the two modules compose into one v1 state (origin first, then the evolution) whose
##   kit_id is the active identity; a repeated key keeps the first and warns once;
## - an invalid state of one module zeroes only that module;
## - the four hybrids of E09 and a fixture kit keep their state byte for byte;
## - Êxtase, Graça, Santuário and Loucura are visible in combat, with one DTO read per update;
## - the HUD never changes damage, SP or the exact snapshot.
## With a real renderer and one user argument (`-- <directory>`), also saves the native captures
## t12_*.png into that directory. Fixture profiles only; saves and controls are never touched.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const CONTROLS_PATH := "res://.godot/e10a_t12_fixture/controls.cfg"
const GRACE := &"sanctuary_grace"
const CULTIST_ECSTASY := &"cultist_ecstasy"
const CULTIST_IDOL := &"cultist_impossible_idol"
const PRIEST_SANCTUARY := &"priest_sanctuary"
const PRIEST_AEGIS := &"priest_aegis"
const PRIEST_SEAL := &"priest_light_seal"
const PRIEST_HOUR := &"priest_holy_hour"
const PRIEST_JUDGMENT := &"priest_judgment"
const HYBRIDS: Array[StringName] = [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"]
const HYBRID_ORIGINS := {&"sp_ac": &"swordsman", &"mg_ac": &"mage", &"sp_la": &"swordsman", &"mg_la": &"mage"}

## A module that publishes a fixed answer, to prove composition rules without a real kit.
class StubKit extends ClassKit:
	var identity: StringName
	var answer: Dictionary = {}
	var skills: Array[SkillDefinition] = []
	var reads := 0
	func _init(identity_id: StringName = &"") -> void:
		identity = identity_id
	func kit_id() -> StringName:
		return identity
	func skill_definitions() -> Array[SkillDefinition]:
		return skills
	func hud_state(_player: PlayerActor) -> Dictionary:
		reads += 1
		return answer

class CountingPriest extends "res://scripts/classes/priest/priest_kit.gd":
	var reads := 0
	func hud_state(player: PlayerActor) -> Dictionary:
		reads += 1
		return super.hud_state(player)

var checks := 0
var failures := 0
var capture_directory := ""

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	KitHudState.reset_reports()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): capture_directory = String(args[0])
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/e10a_t12_fixture"))
	_check_validator_lists()
	await _check_acolyte_alone()
	await _check_priest()
	await _check_cultist()
	await _check_collision()
	await _check_invalid_module()
	await _check_hybrids_unchanged()
	await _check_single_read_and_no_rule_change()
	if not capture_directory.is_empty() and DisplayServer.get_name() != "headless":
		await _captures()
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	paused = false
	print("E10a T12 family HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Builders ---------------------------------------------------------------------------

func _build(identity: StringName, index: int) -> Dictionary:
	var file := FileAccess.open("res://scripts/classes/%s/review_builds.json" % identity, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	return (parsed["builds"] as Array)[index] if parsed is Dictionary else {}

## Snapshot of a character of `origin` with the evolution `evolution` (empty: no evolution).
func _snapshot(origin: StringName, evolution: StringName, build: Dictionary) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "e10a_t12_%s_%s" % [origin, evolution]
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL if not evolution.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL
	snapshot.base_level = ProgressionRules.MAX_BASE_LEVEL
	snapshot.base_class_id = origin
	var attributes: Dictionary[StringName, int] = {&"int": 50, &"dex": 36, &"agi": 20, &"vit": 8}
	if origin == &"swordsman": attributes = {&"str": 50, &"vit": 30, &"dex": 20, &"agi": 20}
	snapshot.attribute_allocations = attributes
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(origin, evolution)
	snapshot.skill_ranks = {}
	if build.is_empty():
		if origin == &"acolyte":
			for skill: StringName in ClassBaseRegistry.skill_ids(&"acolyte"): snapshot.skill_ranks[skill] = 1
	else:
		for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
		for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var slots := ActionBarLayout.empty()
	var actives: Array[Variant] = []
	var shortcuts: Array = build.get("shortcuts", [])
	for index: int in mini(shortcuts.size(), 12):
		slots[index] = StringName(shortcuts[index])
		if actives.size() < 5: actives.append(StringName(shortcuts[index]))
	if shortcuts.is_empty():
		slots[0] = &"acolyte_punishing_light"
		actives = [&"acolyte_punishing_light"]
	snapshot.action_slots = slots
	snapshot.active_slots = actives
	return snapshot

## Mounts the real main scene. Processing stays off: the test drives the actors and the HUD
## update by hand, so every check is deterministic.
func _mount(run: RunState) -> RunController:
	RunController.pending_run_state = run
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var controller := load("res://scenes/main.tscn").instantiate() as RunController
	controller.control_preferences.path = CONTROLS_PATH
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.rng.seed = 61
	return controller

func _mount_family(evolution: StringName, build_index: int = 0) -> RunController:
	var build := _build(evolution, build_index) if not evolution.is_empty() else {}
	# The Inquisição build has no Égide; the HUD test needs every Sacerdote resource.
	if evolution == &"priest": build["evolution_ranks"]["priest_aegis"] = 5
	var controller := _mount(RunState.from_build("e10a-t12-%s-%d" % [evolution, build_index], _snapshot(&"acolyte", evolution, build)))
	_arena(controller)
	return controller

func _arena(controller: RunController) -> void:
	controller.navigation.configure(Rect2(0, 0, 1500, 1000), [], 22.0)
	controller.player.position = Vector2(400, 420)
	var slot := 0
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.position = Vector2(700 + 90 * slot, 420 + 60 * (slot % 2))
		enemy.health.max_hp = 100000.0
		enemy.health.current_hp = 100000.0
		slot += 1
	_mob(controller, Vector2(640, 380))
	_mob(controller, Vector2(640, 470), &"forest_boar")
	controller.player.current_sp = controller.player.max_sp
	controller._update_hud()

func _discard(controller: RunController) -> void:
	paused = false
	root.remove_child(controller)
	controller.free()
	await process_frame

var mob_serial := 0

## A real catalog mob wired to the controller, like the game does (E10a T15 pattern).
func _mob(controller: RunController, at: Vector2, mob_id: StringName = &"forest_wolf") -> EnemyActor:
	mob_serial += 1
	var hostile := EnemyActor.new()
	hostile.global_position = at
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t12_%s_%03d" % [mob_id, mob_serial]
	spawn.mob_base_id = mob_id
	spawn.category_id = &"normal"
	spawn.origin_id = &"trial_stage_1"
	var configured := hostile.configure_occurrence(spawn, BuildContentLoader.pilot().mob_catalog(), controller.navigation, controller.player)
	_check(configured.get("ok", false), "real mob %s configured: %s" % [mob_id, str(configured)])
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.health.max_hp = 100000.0
	hostile.health.current_hp = 100000.0
	controller.enemies.append(hostile)
	return hostile

func _victims(controller: RunController) -> Array[CombatActor]:
	var found: Array[CombatActor] = []
	for enemy: CombatActor in controller.enemies:
		if MadnessHelpers.is_enemy(enemy) and MadnessHelpers.is_live(enemy): found.append(enemy)
	return found

func _cast(controller: RunController, skill: StringName, point: Vector2, enemy: CombatActor = null) -> bool:
	var player := controller.player
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	player.kit_time += 0.001
	return player.use_kit_skill(skill, point, enemy)

func _live(controller: RunController, frames: int = 3) -> void:
	for _index: int in frames:
		controller._update_hud()
		controller.player.queue_redraw()
		for enemy: CombatActor in controller.enemies: enemy.queue_redraw()
		await process_frame

func _find(list: Array, key: String, value: Variant) -> Dictionary:
	for entry: Variant in list:
		if entry is Dictionary and entry.get(key) == value: return entry
	return {}

func _ids(list: Array, key: String) -> Array:
	var ids: Array = []
	for entry: Variant in list: ids.append(entry.get(key))
	return ids

## The state of every attached module, each valid against itself (what kit_hud_state composes).
func _module_states(player: PlayerActor) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for module: ClassKit in player.kit_modules():
		var state := module.hud_state(player)
		_check(bool(KitHudState.validate(state, module)["ok"]), "%s: its own state is valid v1 (%s)" % [module.kit_id(), str(KitHudState.validate(state, module))])
		states.append(state)
	return states

func _check_validator_lists() -> void:
	_check(&"shadow" in KitHudState.ELEMENTS and &"light" in KitHudState.ELEMENTS, "shadow and light are elements of the closed list")
	_check("madness_" in KitHudState.SYSTEM_PREFIXES and "sanctuary_" in KitHudState.SYSTEM_PREFIXES and "flank_" in KitHudState.SYSTEM_PREFIXES, "madness_ joins the system prefixes; the others stay")

# --- Acólito without an evolution -----------------------------------------------------------

func _check_acolyte_alone() -> void:
	var controller := _mount_family(&"")
	var player := controller.player
	_check(player.kit == null and player.origin_kit != null and player.kit_modules().size() == 1, "the Acólito alone has the base module only")
	_check(player.kit_hud_state().is_empty(), "no Madness on the field: the base publishes nothing")
	var victims := _victims(controller)
	_check(victims.size() >= 2, "the training arena has enemies (%d)" % victims.size())
	if victims.size() < 2:
		await _discard(controller)
		return
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	_check(authority != null, "the base owns the Madness authority")
	authority.add(victims[0], 40.0, "t12:a", player)
	authority.add(victims[1], 100.0, "t12:b", player)
	var dto := player.kit_hud_state()
	_check(not dto.is_empty() and dto["schema"] == KitHudState.SCHEMA and dto["kit_id"] == &"acolyte", "the Acólito without evolution has a HUD with its own identity")
	_check(bool(KitHudState.validate(dto, player.origin_kit)["ok"]), "the HUD is valid against the base")
	_check(not dto.has("resources") and not dto.has("zones") and not dto.has("skills"), "the base publishes target marks only")
	var marks: Array = dto.get("target_marks", [])
	_check(marks.size() == 2, "one mark per enemy with Madness (%d)" % marks.size())
	var first := _find(marks, "target_id", victims[0].get_instance_id())
	_check(first.get("kind") == &"pips" and first.get("value") == 2 and first.get("max") == 5 and first.get("element") == &"shadow" and first.get("key") == &"madness", "40/100 Madness is 2 of 5 degrees, shadow: %s" % str(first))
	var delirium := _find(marks, "target_id", victims[1].get_instance_id())
	_check(MadnessAuthority.state_of(victims[1]) == MadnessRules.STATE_DELIRIUM and delirium.get("kind") == &"badge" and delirium.get("key") == &"madness_delirium" and delirium.get("element") == &"shadow", "an enemy in Delírio carries the Delírio badge: %s" % str(delirium))
	await _live(controller)
	_check(controller.kit_overhead_overlay != null and controller.kit_overhead_overlay.plan().size() == 2, "the overhead overlay draws both marks over the living enemies")
	_check(controller.kit_resource_panel == null or not controller.kit_resource_panel.visible, "no resource row: the panel stays hidden for the base alone")
	_check(KitHudState.reported_warnings().is_empty(), "no invalid HUD state was reported: %s" % str(KitHudState.reported_warnings()))
	await _discard(controller)

# --- Sacerdote ------------------------------------------------------------------------------

func _enrich_priest(controller: RunController) -> Array[CombatActor]:
	var player := controller.player
	var victims := _victims(controller)
	var kit := player.kit
	_check(_cast(controller, PRIEST_SANCTUARY, player.global_position + Vector2(120, 0)), "the Santuário opens")
	_check(_cast(controller, PRIEST_AEGIS, player.global_position), "the Égide opens")
	_check(_cast(controller, PRIEST_SEAL, victims[0].global_position, victims[0]), "the Selo de Luz lands")
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	authority.add(victims[1], 60.0, "t12:p", player)
	(kit.get("sanctuary") as SanctuaryAuthority).grace.charges = 3
	return victims

func _check_priest() -> void:
	var controller := _mount_family(&"priest", 1)
	var player := controller.player
	_check(player.origin_kit != null and player.kit != null and player.kit_modules().size() == 2 and player.kit_modules()[0] == player.origin_kit and player.kit_modules()[1] == player.kit, "origin first, evolution second")
	var victims := _enrich_priest(controller)
	var states := _module_states(player)
	var dto := player.kit_hud_state()
	_check(bool(KitHudState.validate(states[1], player.kit)["ok"]) and not states[1].has("skills"), "the Sacerdote state is v1 and carries no skills")
	_check(dto.get("schema") == KitHudState.SCHEMA and dto.get("kit_id") == &"priest", "one v1 state with the evolution identity")
	var resources: Array = dto.get("resources", [])
	var grace := _find(resources, "id", GRACE)
	_check(grace.get("kind") == &"pips" and grace.get("value") == 3 and grace.get("element") == &"light" and grace.get("label") == "Graça", "Graça in pips, light: %s" % str(grace))
	var aegis := _find(resources, "id", PRIEST_AEGIS)
	_check(aegis.get("kind") == &"timer" and aegis.get("label") == "Égide" and float(aegis.get("remaining", 0.0)) > 0.0, "the Égide is a timer: %s" % str(aegis))
	var zones: Array = dto.get("zones", [])
	_check(zones.size() == 1 and zones[0]["role"] == &"sanctuary" and zones[0]["shape"] == &"circle", "the Santuário zone is published: %s" % str(zones))
	var marks: Array = dto.get("target_marks", [])
	var seal := _find(marks, "key", PRIEST_SEAL)
	_check(seal.get("kind") == &"badge" and seal.get("target_id") == victims[0].get_instance_id() and seal.get("element") == &"light", "the Selo de Luz badge sits on the sealed enemy: %s" % str(seal))
	var madness := _find(marks, "key", &"madness")
	_check(madness.get("target_id") == victims[1].get_instance_id() and madness.get("value") == 3 and madness.get("element") == &"shadow", "the base's Loucura (60 is 3 of 5) is in the composition: %s" % str(madness))
	_check(marks.size() >= 2 and marks[0].get("key") != PRIEST_SEAL, "marks: the base's come before the evolution's")
	_check(_find(resources, "id", &"madness_ecstasy").is_empty() and _ids(resources, "id").count(GRACE) == 1, "the Sacerdote publishes no Madness resource, and Graça once")
	# Hora Santa: the resource becomes unlimited with the deadline and the Hora timer appears.
	_check(_cast(controller, PRIEST_HOUR, player.global_position), "the Hora Santa opens")
	dto = player.kit_hud_state()
	resources = dto.get("resources", [])
	grace = _find(resources, "id", GRACE)
	var hour := _find(resources, "id", PRIEST_HOUR)
	_check(bool(grace.get("unlimited", false)) and float(grace.get("remaining", 0.0)) > 0.0 and hour.get("kind") == &"timer" and hour.get("label") == "Hora Santa", "the Hora Santa: Graça unlimited with its deadline and the Hora timer: %s / %s" % [str(grace), str(hour)])
	# The composition is exactly the modules' states, in order.
	var base_state := _module_states(player)[0]
	var kit_state := _module_states(player)[1]
	var expected_marks: Array = []
	expected_marks.append_array(base_state.get("target_marks", []))
	expected_marks.append_array(kit_state.get("target_marks", []))
	_check(str(dto.get("target_marks", [])) == str(expected_marks), "target_marks are the base's then the Sacerdote's, unchanged")
	_check(str(dto.get("resources", [])) == str(kit_state.get("resources", [])), "resources are the Sacerdote's (the base has none)")
	await _live(controller)
	_check(controller.kit_resource_panel != null and controller.kit_resource_panel.visible and _find(controller.kit_resource_panel.plan(), "id", GRACE).size() > 0, "Graça is visible in the combat panel")
	_check(controller.kit_ground_overlay.plan().size() == dto["zones"].size() and dto["zones"].size() >= 1, "the Santuário is drawn on the ground")
	_check(controller.kit_overhead_overlay.plan().size() == dto["target_marks"].size(), "the Selo and the Loucura are drawn over the enemies")
	_check(KitHudState.reported_warnings().is_empty(), "no invalid HUD state was reported: %s" % str(KitHudState.reported_warnings()))
	await _discard(controller)

# --- Cultista -------------------------------------------------------------------------------

func _enrich_cultist(controller: RunController) -> Array[CombatActor]:
	var player := controller.player
	var victims := _victims(controller)
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	authority.add(victims[0], 40.0, "t12:c0", player)
	authority.add(victims[1], 100.0, "t12:c1", player)
	authority.ecstasy.charges = 3
	_check(_cast(controller, CULTIST_IDOL, player.global_position + Vector2(160, 0)), "the Ídolo Impossível is placed")
	return victims

func _check_cultist() -> void:
	var controller := _mount_family(&"cultist", 0)
	var player := controller.player
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	_check(authority != null and authority.ecstasy.enabled, "the Êxtase passive is on in the review build")
	var victims := _enrich_cultist(controller)
	var states := _module_states(player)
	_check(not states[0].has("resources") and not states[1].has("target_marks") and not states[1].has("skills"), "the base publishes the Loucura marks; the Cultista publishes resources and zones only (A18)")
	var dto := player.kit_hud_state()
	_check(dto.get("schema") == KitHudState.SCHEMA and dto.get("kit_id") == &"cultist", "one v1 state with the Cultista identity")
	var resources: Array = dto.get("resources", [])
	var ecstasy := _find(resources, "id", CULTIST_ECSTASY)
	_check(ecstasy.get("kind") == &"pips" and ecstasy.get("value") == 3 and ecstasy.get("max") == MadnessRules.ECSTASY_CAP and ecstasy.get("element") == &"shadow" and ecstasy.get("label") == "Êxtase", "Êxtase in pips 0..5, shadow: %s" % str(ecstasy))
	var idol := _find(resources, "id", CULTIST_IDOL)
	_check(idol.get("kind") == &"timer" and float(idol.get("remaining", 0.0)) > 0.0 and float(idol["remaining"]) <= float(idol["total"]), "the Ídolo is a timer: %s" % str(idol))
	var zones: Array = dto.get("zones", [])
	_check(zones.size() == 1 and zones[0]["role"] == &"idol" and zones[0]["shape"] == &"circle" and zones[0]["space"] == &"flat" and zones[0]["element"] == &"shadow", "the Ídolo is a flat ground zone: %s" % str(zones))
	var marks: Array = dto.get("target_marks", [])
	_check(marks.size() == 2 and _find(marks, "target_id", victims[0].get_instance_id()).get("value") == 2 and _find(marks, "target_id", victims[1].get_instance_id()).get("key") == &"madness_delirium", "the Loucura marks come from the base: %s" % str(marks))
	for resource: Dictionary in resources: _check(not String(resource["id"]).begins_with("madness_"), "the Cultista publishes no Madness resource (%s)" % resource["id"])
	_check(str(marks) == str(states[0]["target_marks"]) and str(resources) == str(states[1]["resources"]), "the composition keeps each module's entries unchanged")
	await _live(controller)
	_check(controller.kit_resource_panel != null and controller.kit_resource_panel.visible and _find(controller.kit_resource_panel.plan(), "id", CULTIST_ECSTASY).size() > 0, "Êxtase is visible in the combat panel")
	_check(controller.kit_overhead_overlay.plan().size() == 2 and controller.kit_ground_overlay.plan().size() == 1, "the Loucura marks and the Ídolo zone are drawn")
	# Without the passive learned: no Êxtase row.
	authority.set_ecstasy_enabled(player, false)
	_check(_find(player.kit_hud_state().get("resources", []), "id", CULTIST_ECSTASY).is_empty(), "Êxtase off: no row")
	_check(KitHudState.reported_warnings().is_empty(), "no invalid HUD state was reported: %s" % str(KitHudState.reported_warnings()))
	await _discard(controller)

# --- Composition rules ----------------------------------------------------------------------

func _resource(id: StringName, label: String, value: int = 1) -> Dictionary:
	return {"id": id, "label": label, "kind": &"pips", "value": value, "max": 5, "element": &"light"}

func _zone(role: StringName, radius: float) -> Dictionary:
	return {"role": role, "space": &"flat", "center": Vector3(100, 100, 0), "shape": &"circle", "radius": radius, "element": &"light"}

func _mark(target: int, key: StringName) -> Dictionary:
	return {"target_id": target, "key": key, "kind": &"badge", "element": &"shadow"}

func _skill_state(ready: bool = true) -> Dictionary:
	return {"ready": ready, "reason": &"" if ready else &"insufficient_sp"}

func _stubs(controller: RunController, origin_answer: Dictionary, kit_answer: Dictionary) -> Array[StubKit]:
	var definition := ClassKitRegistry.skill_definition(PRIEST_JUDGMENT)
	var origin := StubKit.new(&"acolyte")
	var evolution := StubKit.new(&"priest")
	origin.answer = origin_answer
	evolution.answer = kit_answer
	origin.skills = [definition]
	evolution.skills = [definition]
	controller.player.origin_kit = origin
	controller.player.kit = evolution
	return [origin, evolution]

func _state(identity: StringName, resources: Array, zones: Array, marks: Array, skills: Dictionary) -> Dictionary:
	var state := {"schema": KitHudState.SCHEMA, "kit_id": identity}
	if not resources.is_empty(): state["resources"] = resources
	if not zones.is_empty(): state["zones"] = zones
	if not marks.is_empty(): state["target_marks"] = marks
	if not skills.is_empty(): state["skills"] = skills
	return state

func _check_collision() -> void:
	var controller := _mount_family(&"priest", 1)
	var player := controller.player
	var target := _victims(controller)[0].get_instance_id()
	var judgment := {PRIEST_JUDGMENT: _skill_state(true)}
	var rivals := {PRIEST_JUDGMENT: _skill_state(false)}
	var first := _state(&"acolyte", [_resource(&"madness_a", "Primeiro", 1), _resource(&"sanctuary_grace", "Graça A", 2)], [_zone(&"shared", 30.0)], [_mark(target, &"madness_delirium")], judgment)
	var second := _state(&"priest", [_resource(&"sanctuary_grace", "Graça B", 4), _resource(&"priest_extra", "Extra", 5)], [_zone(&"shared", 99.0), _zone(&"only_second", 40.0)], [_mark(target, &"madness_delirium"), _mark(target, &"priest_light_seal")], rivals)
	var stubs := _stubs(controller, first, second)
	KitHudState.reset_reports()
	var dto := player.kit_hud_state()
	_check(stubs[0].reads == 1 and stubs[1].reads == 1, "each module is read once")
	_check(dto.get("kit_id") == &"priest" and dto.get("schema") == KitHudState.SCHEMA, "kit_id is the active identity (the evolution)")
	var resources: Array = dto.get("resources", [])
	_check(_ids(resources, "id") == [&"madness_a", &"sanctuary_grace", &"priest_extra"], "resources: origin then evolution, the duplicate id kept from the first: %s" % str(_ids(resources, "id")))
	_check(_find(resources, "id", &"sanctuary_grace").get("label") == "Graça A", "the first module wins the id collision")
	var zones: Array = dto.get("zones", [])
	_check(_ids(zones, "role") == [&"shared", &"only_second"] and zones[0]["radius"] == 30.0, "zones: concatenated in order, the repeated role kept from the first")
	var marks: Array = dto.get("target_marks", [])
	_check(marks.size() == 2 and marks[0]["key"] == &"madness_delirium" and marks[1]["key"] == &"priest_light_seal", "marks: the repeated (target, key) kept once, the rest appended")
	var skills: Dictionary = dto.get("skills", {})
	_check(skills.size() == 1 and skills[PRIEST_JUDGMENT]["ready"] == true, "skills are united; a repeated skill keeps the first")
	_check(dto.get("kit_id") == &"priest", "the composed state is not revalidated against a single kit")
	# Non-colliding skills of different modules are united.
	var warnings := _composition_warning_count()
	_check(warnings == 4, "one warning per repeated key (resource, zone, mark, skill): %d" % warnings)
	player.kit_hud_state()
	_check(_composition_warning_count() == warnings, "the warnings are not repeated on later reads")
	await _discard(controller)

func _composition_warning_count() -> int:
	var count := 0
	for report: String in KitHudState.reported_warnings():
		if report.begins_with("composition:"): count += 1
	return count

func _check_invalid_module() -> void:
	var controller := _mount_family(&"priest", 1)
	var player := controller.player
	var target := _victims(controller)[0].get_instance_id()
	var good := _state(&"priest", [_resource(&"priest_extra", "Extra", 2)], [], [], {})
	var bad := _state(&"acolyte", [_resource(&"madness_a", "Ruim", 1)], [], [_mark(target, &"madness_delirium")], {})
	bad["unknown_key"] = true
	KitHudState.reset_reports()
	_stubs(controller, bad, good)
	var dto := player.kit_hud_state()
	_check(var_to_bytes(dto) == var_to_bytes(good), "an invalid origin state zeroes only the origin: the evolution's state comes back unchanged")
	_check(KitHudState.reported_warnings() == ["acolyte:kit_hud_unknown_key"], "one warning for the invalid module: %s" % str(KitHudState.reported_warnings()))
	var bad_kit := _state(&"priest", [_resource(&"other_prefix", "Ruim")], [], [], {})
	var good_origin := _state(&"acolyte", [_resource(&"madness_ok", "Origem", 1)], [], [], {})
	_stubs(controller, good_origin, bad_kit)
	dto = player.kit_hud_state()
	_check(var_to_bytes(dto) == var_to_bytes(good_origin), "an invalid evolution state zeroes only the evolution: the origin's state comes back unchanged")
	_stubs(controller, bad, bad_kit)
	_check(player.kit_hud_state().is_empty(), "both invalid: empty")
	_stubs(controller, {}, {})
	_check(player.kit_hud_state().is_empty(), "both empty: empty, with no warning for a valid {}")
	await _discard(controller)

# --- E09 hybrids and fixtures ---------------------------------------------------------------

func _check_hybrids_unchanged() -> void:
	for identity: StringName in HYBRIDS:
		var controller := _mount(RunState.from_build("e10a-t12-hybrid-%s" % identity, _snapshot(HYBRID_ORIGINS[identity], identity, _build(identity, 0))))
		_arena(controller)
		var player := controller.player
		_check(player.kit != null and player.origin_kit == null and player.kit_modules().size() == 1, "%s: a single module" % identity)
		var direct := player.kit.hud_state(player)
		var through := player.kit_hud_state()
		_check(not direct.is_empty() and var_to_bytes(through) == var_to_bytes(direct), "%s: kit_hud_state is the kit's own state, byte for byte" % identity)
		_check(through.get("kit_id") == identity, "%s: kit_id is the hybrid" % identity)
		await _discard(controller)
	var plain := _mount(RunState.new(&"mage"))
	_check(plain.player.kit_hud_state().is_empty(), "a player with no module has no HUD")
	await _discard(plain)

# --- One read per update; no rule change -----------------------------------------------------

func _check_single_read_and_no_rule_change() -> void:
	ClassKitRegistry.clear_fixtures()
	var counting := CountingPriest.new()
	_check(ClassKitRegistry.install_fixture(&"priest", counting), "the counting Sacerdote installs")
	var controller := _mount_family(&"priest", 1)
	var player := controller.player
	var kit := player.kit as CountingPriest
	_check(kit != null, "the player carries the counting Sacerdote")
	if kit != null:
		var before := kit.reads
		controller._update_hud()
		_check(kit.reads - before == 1, "one HUD update reads the Sacerdote once (%d), with %d enemies" % [kit.reads - before, controller.enemies.size()])
		before = kit.reads
		for _index: int in 5: controller._update_hud()
		_check(kit.reads - before == 5, "five updates, five reads")
	await _discard(controller)
	ClassKitRegistry.clear_fixtures()
	# The HUD changes nothing: the exact snapshot of a Cultista with Madness, Êxtase and an Ídolo
	# is identical before and after many HUD updates, and the rule state is untouched.
	var cultist := _mount_family(&"cultist", 0)
	var victims := _enrich_cultist(cultist)
	var hp := victims[0].health.current_hp
	var madness := MadnessAuthority.madness_of(victims[0])
	var sp := cultist.player.current_sp
	var before := await _controller_snapshot(cultist)
	for _index: int in 30: cultist._update_hud()
	var after := await _controller_snapshot(cultist)
	_check(before == after and before != "no barrier" and before != "capture failed", "the exact snapshot is identical after 30 HUD updates")
	_check(victims[0].health.current_hp == hp and MadnessAuthority.madness_of(victims[0]) == madness and cultist.player.current_sp == sp, "damage, Madness and SP are untouched by the HUD reads")
	await _discard(cultist)

func _controller_snapshot(controller: RunController) -> String:
	var barrier := SnapshotTickBarrier.new()
	paused = true
	var acquired := barrier.acquire(controller)
	var digest := "no barrier"
	if acquired["ok"]:
		var result := SnapshotRegistry.new().capture(controller, barrier)
		_check(result.get("ok", false), "the exact snapshot of the controller captures (%s)" % str(result.get("detail", result.get("error_code", ""))))
		digest = var_to_bytes(result["snapshot"]).hex_encode().sha256_text() if result.get("ok", false) else "capture failed"
		barrier.release()
	else:
		_check(false, "the tick barrier was acquired (%s)" % str(acquired))
	paused = false
	return digest

# --- Native captures ------------------------------------------------------------------------

func _save(path_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := capture_directory.path_join(path_name)
	_check(not image.is_empty() and image.save_png(path) == OK, "native capture " + path_name)

func _captures() -> void:
	var controller := _mount_family(&"")
	controller.player.global_position = Vector2(560, 420)
	var victims := _victims(controller)
	var authority := MadnessAuthority.of(controller.player) as MadnessAuthority
	authority.add(victims[0], 40.0, "cap:a", controller.player)
	authority.add(victims[1], 70.0, "cap:b", controller.player)
	await _live(controller)
	await _save("t12_acolyte.png")
	await _discard(controller)
	controller = _mount_family(&"priest", 1)
	controller.player.global_position = Vector2(560, 420)
	_enrich_priest(controller)
	await _live(controller)
	await _save("t12_priest.png")
	await _discard(controller)
	controller = _mount_family(&"cultist", 0)
	controller.player.global_position = Vector2(560, 420)
	_enrich_cultist(controller)
	await _live(controller)
	await _save("t12_cultist.png")
	await _discard(controller)
