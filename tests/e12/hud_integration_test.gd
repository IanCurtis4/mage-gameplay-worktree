extends SceneTree
## E12 H4 — combat HUD wiring (contract docs/epics/e12_contract.md §6, C5). The real
## `scenes/main.tscn` controller is mounted with the four hybrids of E09 (review builds of
## `scripts/classes/<id>/review_builds.json`), in the flat arena and in the expedition world
## (F1 fixture, `tools/verify.ps1 -F1Fixture`):
## - the resource panel exists only for a player with a kit, and shows the DTO rows;
## - the kit DTO is read once per HUD update and shared by the panel and both overlays;
## - the overlays follow the DTO (zone on the ground, marks over living enemies, a dead or
##   unknown target id ignored: A7);
## - the Refração slot without charge says why, shows the kit recharge, and the real cast is
##   still refused by the rule; priority canonical recharge > kit recharge > ready;
## - the player's cast bar covers the whole preparation and flashes on cancel and release;
##   the "Conjurando" line and the "CONJURANDO" slot state are gone, the help line stays;
## - a mob cast draws the thin bar under the HP bar, the name only for elite and above;
## - damage, SP, recharges and the exact snapshot are identical with and without the HUD.
## With a real renderer and one user argument (`-- <directory>`), also saves the native
## captures docs/epics/e12/h4_*.png into that directory.
## Fixture profiles only; the personal controls file and saves are never touched.
const FixtureHudKit = preload("res://scripts/classes/fixture/hud/fixture_hud_kit.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const F1Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")

const IDENTITIES: Array[StringName] = [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"]
const ORIGINS := {&"sp_ac": &"swordsman", &"mg_ac": &"mage", &"sp_la": &"swordsman", &"mg_la": &"mage"}
const REFRACTION := &"arcane_blade_refraction"
const OATH := &"paladin_oath"
const HOUR := &"paladin_oath_hour"
const CIRCLE := &"thaumaturge_votive_circle"
const SPECTER_MARK := &"arcane_blade_specter"
const CONTROLS_PATH := "res://.godot/e12_h4_fixture/controls.cfg"
const STEP := 0.05

class CountingKit extends FixtureHudKit:
	var reads := 0
	func hud_state(player: PlayerActor) -> Dictionary:
		reads += 1
		return super.hud_state(player)

var checks := 0
var failures := 0
var capture_directory := ""
var _world_available := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _close(a: float, b: float, label: String, tolerance: float = 0.0001) -> void:
	_check(absf(a - b) <= tolerance, "%s (%s vs %s)" % [label, a, b])

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	KitHudState.reset_reports()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		capture_directory = String(args[0])
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/e12_h4_fixture"))
	_world_available = F1Fixture.sources_current()
	# H4_SKIP_WORLD=1 is only for quick local iterations of the flat checks.
	if OS.get_environment("H4_SKIP_WORLD") != "1":
		_check(_world_available, "F1 world fixture is current (run with -F1Fixture)")
	await _check_no_kit_player()
	await _check_single_read()
	await _check_overlays_and_panel()
	await _check_refraction_slot()
	await _check_player_cast_bar()
	await _check_mob_cast_bar()
	await _check_specter_badges()
	await _check_no_rule_change()
	if _world_available:
		await _check_world()
	if not capture_directory.is_empty() and DisplayServer.get_name() != "headless":
		await _captures()
	_check(KitHudState.reported_warnings().is_empty(), "no invalid HUD DTO was reported: %s" % str(KitHudState.reported_warnings()))
	paused = false
	print("E12 H4 HUD integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Builders ---------------------------------------------------------------------------

func _build(identity: StringName, index: int = 0) -> Dictionary:
	var file := FileAccess.open("res://scripts/classes/%s/review_builds.json" % identity, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	return (parsed["builds"] as Array)[index] if parsed is Dictionary else {}

func _snapshot(identity: StringName, build: Dictionary) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "e12_h4_" + String(identity)
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_level = ProgressionRules.MAX_BASE_LEVEL
	snapshot.base_class_id = ORIGINS[identity]
	var attributes: Dictionary[StringName, int] = {&"int": 50, &"dex": 36, &"agi": 20, &"vit": 8}
	if ORIGINS[identity] != &"mage":
		attributes = {&"str": 50, &"vit": 30, &"dex": 20, &"agi": 20}
	snapshot.attribute_allocations = attributes
	snapshot.evolution_id = identity
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(ORIGINS[identity], identity)
	snapshot.skill_ranks = {}
	if not build.is_empty():
		for skill: Variant in build["base_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["base_ranks"][skill])
		for skill: Variant in build["evolution_ranks"]: snapshot.skill_ranks[StringName(skill)] = int(build["evolution_ranks"][skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	var slots := ActionBarLayout.empty()
	var actives: Array[Variant] = []
	var shortcuts: Array = build.get("shortcuts", [])
	for index: int in mini(shortcuts.size(), 12):
		slots[index] = StringName(shortcuts[index])
		if actives.size() < 5: actives.append(StringName(shortcuts[index]))
	snapshot.action_slots = slots
	snapshot.active_slots = actives
	return snapshot

## Mounts the real main scene. Processing stays off: the test drives the actors and the
## HUD update by hand, so every check is deterministic.
func _mount(run: RunState) -> RunController:
	RunController.pending_run_state = run
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var controller := load("res://scenes/main.tscn").instantiate() as RunController
	controller.control_preferences.path = CONTROLS_PATH
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.rng.seed = 53
	return controller

func _mount_hybrid(identity: StringName, build_index: int = 0) -> RunController:
	var build := _build(identity, build_index)
	var snapshot := _snapshot(identity, build)
	var controller := _mount(RunState.from_build("e12-h4-%s-%d" % [identity, build_index], snapshot))
	controller.navigation.configure(Rect2(0, 0, 1500, 1000), [], 22.0)
	controller.player.position = Vector2(400, 420)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.position = Vector2(650, 420)
		enemy.health.max_hp = 100000.0
		enemy.health.current_hp = 100000.0
	controller.player.current_sp = controller.player.max_sp
	controller._update_hud()
	return controller

func _discard(controller: RunController) -> void:
	paused = false
	root.remove_child(controller)
	controller.free()
	await process_frame

func _caster(controller: RunController, position: Vector2, category: StringName = &"elite") -> EnemyActor:
	var catalog := BuildContentLoader.pilot().mob_catalog()
	var skill: StringName = MobSkillAdapters.IDS[0]
	var definition := MobDefinition.new()
	definition.id = StringName("e12_h4_caster_" + String(category))
	definition.display_name = "Conjurador de teste"
	definition.fixed_level = 7
	definition.archetype = &"archer"
	definition.animation_kind = &"archer"
	definition.base_category = &"elite" if category != &"normal" else &"normal"
	definition.allowed_occurrence_categories = [&"normal", &"elite", &"rare_elite"]
	definition.skill_ids = [skill]
	definition.skill_ranks = {skill: 3}
	for axis: StringName in StatCalculator.PRIMARY_IDS: definition.primary_attributes[axis] = 3
	if catalog.get_definition(definition.id) == null: catalog.register_definition(definition)
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "e12_h4_caster_" + String(category)
	occurrence.mob_base_id = definition.id
	occurrence.category_id = category
	occurrence.origin_id = &"fixture_arena"
	var enemy := EnemyActor.new()
	var configured := enemy.configure_occurrence(occurrence, catalog, controller.navigation, controller.player)
	_check(configured.get("ok", false), "caster %s configures: %s" % [category, str(configured)])
	enemy.position = position
	controller.add_child(enemy)
	controller.enemies.append(enemy)
	enemy.set_process(false)
	enemy.health.max_hp = 100000.0
	enemy.health.current_hp = 100000.0
	return enemy

func _victim(controller: RunController) -> CombatActor:
	return controller.training_boss if controller.training_boss != null else controller.enemies[0]

## Puts a rich, real state in the kit of `identity` through its own authorities (the same
## ones the H2 tests use), so the HUD has something to show.
func _enrich(controller: RunController, identity: StringName) -> void:
	var player := controller.player
	var kit := player.kit
	var victim := _victim(controller)
	var cast := {"skill_id": OATH, "rank": 5, "element": &"light", "world": false, "anchor": null, "point": player.global_position, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [victim]}
	player.kit_time = 9.0
	match identity:
		&"sp_ac":
			var authority: SanctuaryAuthority = kit.get("sanctuary")
			_check(kit.resolve_cast(player, cast), "the Oath opens")
			authority.grace.charges = 3
			authority.grant_aegis(player, 50.0)
			authority.seal(player, victim, &"paladin_seal", 4.0, 2)
		&"mg_ac":
			var authority: SanctuaryAuthority = kit.get("sanctuary")
			cast["skill_id"] = CIRCLE
			cast["point"] = player.global_position + Vector2(120, 0)
			_check(kit.resolve_cast(player, cast), "the Círculo Votivo opens")
			kit.set("circle_element", &"ice")
			kit.call(&"_apply_zone_element", player)
			authority.grace.charges = 4
		&"sp_la":
			var flank: FlankAuthority = kit.get("flank")
			flank.mark_victim(player, victim)
			flank.gain(player, victim, FlankRules.SOURCE_COMBO, "h4_a")
			flank.gain(player, victim, FlankRules.SOURCE_DIRECT, "h4_b")
			kit.set("duel_remaining", 6.0)
			kit.set("auto_parry_remaining", 5.0)
		&"mg_la":
			var flank: FlankAuthority = kit.get("flank")
			flank.mark_victim(player, victim)
			flank.gain(player, victim, FlankRules.SOURCE_COMBO, "h4_a")
			flank.gain(player, victim, FlankRules.SOURCE_DIRECT, "h4_b")
			kit.set("refraction_charges", 0)
			kit.set("refraction_recharge", 6.5)
			kit.set("specter_serial", 2)
			kit.set("specter_pending", 1)
			victim.marks.set_mark(SPECTER_MARK, player.get_instance_id(), {"serial": 2, "order": 0, "due": 12.0, "element": "ice"}, 3.0)

func _marks_of(dto: Dictionary) -> Array:
	return dto.get("target_marks", [])

# --- Checks -----------------------------------------------------------------------------

func _check_no_kit_player() -> void:
	var controller := _mount(RunState.new(&"mage"))
	controller.player.current_sp = controller.player.max_sp
	controller._update_hud()
	_check(not controller.player.has_kit(), "a plain mage has no kit")
	_check(controller.kit_resource_panel == null, "the resource panel is not created for a player without a kit")
	_check(controller.kit_ground_overlay == null and controller.kit_overhead_overlay == null, "no world overlay is created for a player without a kit")
	_check(controller._hud_kit_state.is_empty(), "the shared DTO of a player without a kit is empty")
	_check(controller.cast_bar != null and not controller.cast_bar.visible, "the cast bar exists for every player and starts hidden")
	_check(controller.cast_bar.get_parent() == controller.ui_root, "the cast bar lives in the HUD root")
	await _discard(controller)

func _check_single_read() -> void:
	_check(ClassKitRegistry.install_fixture(&"sp_ac", CountingKit.new(&"sp_ac")), "the counting fixture kit installs over sp_ac")
	var controller := _mount(RunState.from_build("e12-h4-count", _snapshot(&"sp_ac", {})))
	var kit := controller.player.kit as CountingKit
	_check(kit != null, "the player carries the counting kit")
	if kit != null:
		var first := _caster(controller, Vector2(700, 420))
		var second := _caster(controller, Vector2(760, 420), &"rare_elite")
		kit.victim_id = first.get_instance_id()
		controller.player.current_sp = controller.player.max_sp
		var before := kit.reads
		controller._update_hud()
		_check(kit.reads - before == 1, "one HUD update reads the kit DTO exactly once (reads: %d) with %d enemies and marks" % [kit.reads - before, controller.enemies.size()])
		before = kit.reads
		for _index: int in 5: controller._update_hud()
		_check(kit.reads - before == 5, "five HUD updates read it five times, never per actor (%d)" % (kit.reads - before))
		var dto := controller._hud_kit_state
		_check(not dto.is_empty() and KitHudState.validate(dto, kit)["ok"], "the shared DTO is the validated one")
		_check(controller.kit_resource_panel != null and controller.kit_resource_panel.plan().size() == KitResourcePanel.rows_for(dto).size() and controller.kit_resource_panel.visible, "the panel draws the same DTO")
		var overhead_plan := controller.kit_overhead_overlay.plan()
		var expected := 0
		for mark: Dictionary in _marks_of(dto):
			if mark["target_id"] == first.get_instance_id(): expected += 1
		_check(expected == 2 and overhead_plan.size() == expected, "the overhead overlay draws the marks of the living target the DTO names (%d of %d)" % [overhead_plan.size(), expected])
		_check(controller.kit_ground_overlay.plan().size() == (dto["zones"] as Array).size(), "the ground overlay draws the zones of the same DTO")
		first.health.current_hp = 0.0
		controller.enemies.erase(first)
		controller._update_hud()
		_check(controller.kit_overhead_overlay.plan().is_empty(), "a dead or removed target id is ignored (A7)")
	ClassKitRegistry.clear_fixtures()
	await _discard(controller)

func _zones_of(dto: Dictionary, space: StringName) -> Array:
	var result: Array = []
	for zone: Dictionary in dto.get("zones", []):
		if zone["space"] == space: result.append(zone)
	return result

func _check_overlays_and_panel() -> void:
	for identity: StringName in IDENTITIES:
		var controller := _mount_hybrid(identity)
		_enrich(controller, identity)
		controller._update_hud()
		var dto := controller._hud_kit_state
		var kit := controller.player.kit
		_check(not dto.is_empty() and KitHudState.validate(dto, kit)["ok"], "%s: the shared DTO validates" % identity)
		_check(controller.kit_resource_panel != null, "%s: the resource panel exists for a kit" % identity)
		var rows := KitResourcePanel.rows_for(dto)
		_check(controller.kit_resource_panel.visible == (not rows.is_empty()) and controller.kit_resource_panel.plan().size() == rows.size(), "%s: the panel shows the %d DTO rows" % [identity, rows.size()])
		_check(controller.kit_resource_panel.get_parent() == controller.sp_label.get_parent() and controller.kit_resource_panel.get_index() == controller.sp_label.get_index() + 1, "%s: the panel sits right under VIDA and SP" % identity)
		var zones := _zones_of(dto, &"flat")
		_check(controller.kit_ground_overlay.plan().size() == zones.size(), "%s: the ground overlay draws the %d zone(s) of the DTO" % [identity, zones.size()])
		var marks := _marks_of(dto)
		_check(controller.kit_overhead_overlay.plan().size() == marks.size(), "%s: the overhead overlay draws the %d mark(s) over the living victim" % [identity, marks.size()])
		_check(controller.kit_ground_overlay.get_parent() == controller.arena_view and controller.kit_ground_overlay.z_index == -1 and controller.kit_overhead_overlay.z_index > 0, "%s: ground overlay under the actors, overhead above (flat)" % identity)
		match identity:
			&"sp_ac": _check(zones.size() == 1 and zones[0]["shape"] == &"cone" and marks.size() == 1 and marks[0]["kind"] == &"badge", "sp_ac: the Oath cone and the Seal badge reach the overlays")
			&"mg_ac": _check(zones.size() == 1 and zones[0]["shape"] == &"circle" and zones[0]["element"] == &"ice", "mg_ac: the Círculo Votivo in the current element reaches the ground overlay")
			&"sp_la": _check(zones.is_empty() and marks.size() == 1 and marks[0]["key"] == &"flank_victim" and marks[0]["kind"] == &"pips", "sp_la: the Sentença pips reach the overhead overlay")
			&"mg_la": _check(marks.size() >= 1 and marks[0]["key"] == &"flank_victim", "mg_la: the Sentença pips reach the overhead overlay")
		# The victim dies: the same DTO stops marking it.
		var victim := _victim(controller)
		victim.health.current_hp = 0.0
		controller._update_hud()
		_check(controller.kit_overhead_overlay.plan().is_empty(), "%s: a dead victim keeps no marker (A7)" % identity)
		await _discard(controller)

func _check_refraction_slot() -> void:
	var controller := _mount_hybrid(&"mg_la")
	_enrich(controller, &"mg_la")
	var player := controller.player
	var kit := player.kit
	var button := controller.battle_controls.skill_buttons.get(REFRACTION) as ActionBarSlot
	_check(button != null, "the Refração has a slot on the action bar")
	if button == null:
		await _discard(controller)
		return
	player.mage_cooldowns[REFRACTION] = 0.0
	controller._update_hud()
	var state: Dictionary = controller._hud_kit_state["skills"][REFRACTION]
	_check(not bool(state["ready"]) and state["reason"] == &"arcane_blade_refraction_recharging" and int(state["charges"]) == 0, "the DTO says the Refração has no charge")
	_check(button.blocked_hint.text == "SEM CARGA" and button.combat_blocked, "the slot says SEM CARGA and is marked blocked")
	_check(button.cooldown_hint.text == "6.5" and absf(button.cooldown_remaining - 6.5) < 0.001, "the slot shows the kit's own recharge (6.5 s)")
	_check(button.tooltip_text.contains("SEM CARGA") and button.tooltip_text.contains("Cargas 0/1") and button.tooltip_text.contains("recarga própria 6.5s"), "the tooltip says the charges and the kit recharge")
	_check(controller._skill_state(0.0, player.skill_cost(REFRACTION), REFRACTION) == "SEM CARGA", "the shared state word is SEM CARGA")
	# The rule still refuses: the HUD only informs.
	var sp_before := player.current_sp
	_check(player.skill_cooldown(REFRACTION) <= 0.0 and player.current_sp >= player.skill_cost(REFRACTION) and player.use_kit_skill(REFRACTION, player.global_position) == false, "the real cast path still refuses the Refração with SP and no canonical recharge")
	_close(player.current_sp, sp_before, "the refused cast spends no SP")
	# Priority: canonical recharge first.
	player.mage_cooldowns[REFRACTION] = 3.0
	controller._update_hud()
	_check(button.cooldown_hint.text == "3.0" and controller._skill_state(3.0, 0.0, REFRACTION).begins_with("RECARGA"), "the canonical recharge wins over the kit recharge")
	_check(button.blocked_hint.text != "SEM CARGA", "the kit word is not shown while the canonical recharge is the status")
	player.mage_cooldowns[REFRACTION] = 0.0
	# Ready: no word, no recharge.
	kit.set("refraction_charges", 1)
	kit.set("refraction_recharge", 0.0)
	controller._update_hud()
	_check(button.blocked_hint.text.is_empty() and button.cooldown_hint.text.is_empty() and not button.combat_blocked, "ready: no word and no recharge on the slot")
	_check(controller._skill_state(0.0, 0.0, REFRACTION) == "PRONTO", "ready: the state word is PRONTO")
	# Another kit reason in pt-BR.
	_check(BattleControls.kit_status_text({"ready": false, "reason": &"paladin_hour_active"}) == "HORA ATIVA" and BattleControls.kit_status_text({"ready": false, "reason": &"unknown_future_code"}) == "INDISPONÍVEL" and BattleControls.kit_status_text({"ready": true, "reason": &""}) == "" and BattleControls.kit_status_text(null) == "", "kit status words: known reason, unknown reason, ready, garbage")
	await _discard(controller)

func _check_player_cast_bar() -> void:
	var controller := _mount_hybrid(&"mg_la")
	var player := controller.player
	var bar := controller.cast_bar
	var victim := _victim(controller)
	player.mage_cooldowns.clear()
	controller._update_hud()
	_check(not bar.visible and bar.plan().is_empty(), "no cast, no bar")
	_close(bar.offset_top, -218.0, "flat: the cast bar sits right above the help line")
	controller._commit_skill(&"fireball", victim.global_position)
	_check(player.has_active_cast(), "the fireball starts its preparation")
	var total := player.active_cast_total
	_check(total > 0.0, "the preparation has a time (%.2fs)" % total)
	controller._update_hud()
	var plan := bar.plan()
	_check(bar.visible and not plan.is_empty() and plan["label"] == ClassCatalog.skill_definition(&"fireball").display_name, "the bar shows the skill name")
	_close(float(plan["ratio"]), 0.0, "the bar starts empty")
	_check(str(plan["time_text"]) == "%.1fs" % total, "the bar shows the remaining time")
	# Whole preparation: the fill follows 1 - remaining / total at every step and reaches the end.
	var actions: Array[StringName] = []
	player.presentation_action.connect(func(action: StringName, _d: Vector2, _t: float) -> void: actions.append(action))
	var last_ratio := -1.0
	var covered_half := false
	var steps := 0
	while player.has_active_cast() and steps < 200:
		player._advance_active_cast(STEP) if player.has_method("_advance_active_cast") else player._process(STEP)
		steps += 1
		controller._update_hud()
		if not player.has_active_cast(): break
		var current := bar.plan()
		var expected := 1.0 - player.active_cast_remaining / player.active_cast_total
		_close(float(current["ratio"]), expected, "the fill follows 1 - remaining/total")
		_check(float(current["ratio"]) >= last_ratio, "the fill never goes back")
		last_ratio = float(current["ratio"])
		covered_half = covered_half or last_ratio >= 0.5
	_check(covered_half and last_ratio > 0.5, "the bar covers the preparation up to its end (last fill %.2f)" % last_ratio)
	_check(not player.has_active_cast(), "the preparation completes")
	# The flash follows the existing presentation actions: a completed cast that emits
	# cast_release flashes the release color; one that does not simply ends the bar.
	if actions.has(&"cast_release"):
		_check(bar.is_flashing() and bar.plan()["color"] == HudPalette.flash_color(&"release"), "the release flashes the bar in the release color")
	bar._process(0.5)
	_check(not bar.visible, "the bar is gone after the flash")
	# The wiring of cast_release itself: an actor that emits it while a cast is on screen.
	player.mage_cooldowns.clear()
	player.current_sp = player.max_sp
	controller._commit_skill(&"fireball", victim.global_position)
	controller._update_hud()
	player.presentation_action.emit(&"cast_release", Vector2.RIGHT, 0.15)
	_check(bar.is_flashing() and bar.plan()["color"] == HudPalette.flash_color(&"release") and float(bar.plan()["ratio"]) == 1.0, "cast_release flashes the bar full in the release color")
	player.cancel_active_cast()
	bar._process(0.5)
	controller._update_hud()
	# The help line replaces the old text during a cast; the slot no longer says CONJURANDO.
	player.mage_cooldowns.clear()
	player.current_sp = player.max_sp
	controller._commit_skill(&"fireball", victim.global_position)
	controller._update_hud()
	controller._update_aim(victim.global_position)
	_check(player.has_active_cast() and controller.battle_controls.aim_label.text == "mover / Direito / Esc cancela", "during the cast the help line stays and the 'Conjurando' text is gone: '%s'" % controller.battle_controls.aim_label.text)
	var texts: PackedStringArray = []
	for slot: Button in controller.battle_controls.slot_buttons: texts.append(slot.tooltip_text)
	_check(not "\n".join(texts).contains("CONJURANDO") and not controller._display_skill_state(&"fireball", 0.0).contains("CONJURANDO"), "the CONJURANDO slot state is gone")
	# Cancel by movement/Esc: the bar flashes in the cancel color and disappears.
	controller._cancel_casting()
	controller._update_hud()
	_check(not player.has_active_cast() and bar.is_flashing() and bar.plan()["color"] == HudPalette.flash_color(&"cancel"), "cancelling flashes the bar in the cancel color")
	bar._process(0.5)
	controller._update_hud()
	_check(not bar.visible, "the cancelled bar disappears")
	# An instant action that also emits cast_release never lights a stale bar.
	player.presentation_action.emit(&"cast_release", Vector2.RIGHT, 0.1)
	_check(not bar.is_flashing(), "a release without a cast on screen does not flash the bar")
	await _discard(controller)
	# Swordsman hybrids have no preparation: no bar, ever.
	var duelist := _mount_hybrid(&"sp_la")
	duelist._update_hud()
	_check(not duelist.cast_bar.visible and duelist.player.cast_progress() == {"active": false}, "a hybrid without preparation skills never shows a bar")
	await _discard(duelist)

func _check_mob_cast_bar() -> void:
	var controller := _mount_hybrid(&"mg_ac")
	var player := controller.player
	for category: StringName in [&"normal", &"elite", &"boss"]:
		var enemy := _caster(controller, Vector2(700, 420), &"elite" if category == &"elite" else &"normal")
		enemy.occurrence.category_id = category
		_check(enemy.cast_progress() == {"active": false}, "%s: an idle mob draws no bar" % category)
		enemy._advance_cast_bar(0.0)
		_check(enemy._cast_last.is_empty() and not enemy._cast_bar_drawn, "%s: nothing to draw while idle" % category)
		_check(enemy._try_declared_skill() and not enemy._mob_cast.is_empty(), "%s: the mob prepares its skill" % category)
		var total := float(enemy._mob_cast["cast_time"])
		enemy._advance_cast_bar(0.0)
		_check(not enemy._cast_last.is_empty() and enemy._cast_last["category"] == category, "%s: the mob cast is sampled with its category" % category)
		var plan := ActorCastBar.plan_overhead(enemy._cast_last, enemy.overhead_bar_y() + 7.0, 52.0, &"", enemy._cast_last["category"] in enemy.CAST_LABEL_CATEGORIES)
		_check(not plan.is_empty() and (plan["back"] as Rect2).position.y == enemy.overhead_bar_y() + 7.0, "%s: the thin bar sits right under the HP bar" % category)
		_check((String(plan["label"]) != "") == (category != &"normal"), "%s: the name shows only for elite, rare elite and boss" % category)
		enemy._advance_mob_cast(total * 0.5)
		enemy._advance_cast_bar(0.016)
		_close(float(ActorCastBar.plan_overhead(enemy._cast_last, 0.0, 52.0)["ratio"]), 0.5, "%s: the bar is at half" % category, 0.02)
		if category == &"elite":
			var actions: Array[StringName] = []
			enemy.presentation_action.connect(func(action: StringName, _d: Vector2, _t: float) -> void: actions.append(action))
			enemy._advance_mob_cast(total)
			_check(actions.has(&"cast_cancel") or actions.has(&"cast_release"), "the finished mob cast emits a presentation action")
			enemy._advance_cast_bar(0.016)
			var flashing := enemy._cast_flash_time > 0.0
			_check(flashing and enemy._cast_flash_kind in [&"cancel", &"release"], "the end of the mob cast flashes (%s)" % enemy._cast_flash_kind)
			enemy._advance_cast_bar(1.0)
			_check(enemy._cast_last.is_empty() and enemy._cast_flash_kind == &"", "after the flash nothing is left to draw")
		else:
			enemy._cancel_mob_cast_presentation()
			enemy._mob_cast = {}
			enemy._advance_cast_bar(0.016)
			_check(enemy._cast_flash_kind == &"cancel" and enemy._cast_flash_time > 0.0, "%s: a cancelled mob cast flashes the cancel color" % category)
			enemy._advance_cast_bar(1.0)
			_check(enemy._cast_last.is_empty(), "%s: the cancel flash ends" % category)
		controller.enemies.erase(enemy)
		enemy.free()
	# The player's own cast never draws the thin bar over the player (the HUD bar owns it).
	player.mage_cooldowns.clear()
	controller._commit_skill(&"fireball", _victim(controller).global_position)
	player._advance_cast_bar(0.016)
	_check(player.has_active_cast() and player._cast_last.get("category") == &"player", "the player's cast is sampled as category player")
	await _discard(controller)

## The Espectro badges (H2 limitation 3): the reflections are staggered by SPECTER_STAGGER, so
## with one enemy the single reflection strikes in the cast tick (never on screen), and with
## more enemies the pending ones show as a badge for their stagger. Measured, rule untouched.
func _check_specter_badges() -> void:
	var controller := _mount_hybrid(&"mg_la")
	var player := controller.player
	var victim := _victim(controller)
	victim.position = Vector2(480, 420)
	_caster(controller, Vector2(520, 380), &"normal")
	_caster(controller, Vector2(520, 460), &"normal")
	player.current_sp = player.max_sp
	player.mage_cooldowns.clear()
	_check(player.use_kit_skill(&"arcane_blade_prism_specter", player.global_position), "the Espectro casts against three enemies")
	var seen_seconds := 0.0
	var seen_frames := 0
	var elapsed := 0.0
	while elapsed < 1.0:
		var badges := 0
		controller._update_hud()
		for mark: Dictionary in controller.kit_overhead_overlay.plan() if controller.kit_overhead_overlay != null else []:
			if mark["key"] == SPECTER_MARK: badges += 1
		if badges > 0:
			seen_seconds += 0.02
			seen_frames += 1
		player._process(0.02)
		elapsed += 0.02
	print("Espectro badge on screen: %.2fs of the first second (%d updates of 20 ms, three enemies)" % [seen_seconds, seen_frames])
	_check(seen_seconds >= 0.15, "with three enemies the Espectro badges stay on screen long enough to read (%.2fs)" % seen_seconds)
	await _discard(controller)
	var alone := _mount_hybrid(&"mg_la")
	alone.player.current_sp = alone.player.max_sp
	_victim(alone).position = Vector2(480, 420)
	_check(alone.player.use_kit_skill(&"arcane_blade_prism_specter", alone.player.global_position), "the Espectro casts against one enemy")
	alone._update_hud()
	var alone_badges := 0
	for mark: Dictionary in alone.kit_overhead_overlay.plan() if alone.kit_overhead_overlay != null else []:
		if mark["key"] == SPECTER_MARK: alone_badges += 1
	_check(alone_badges == 0, "against one enemy the single reflection strikes in the cast tick: no badge is ever on screen")
	await _discard(alone)

func _check_no_rule_change() -> void:
	# The same scripted fight with the HUD update off and on: identical damage, SP, recharges
	# and exact snapshot. The HUD reads only.
	for identity: StringName in [&"mg_la", &"mg_ac"]:
		var first := await _scripted_fight(identity, false)
		var second := await _scripted_fight(identity, false)
		var with_hud := await _scripted_fight(identity, true)
		_check(first["damage"] > 0.0, "%s: the scripted fight deals damage (%s)" % [identity, first["damage"]])
		for key: String in ["damage", "sp", "cooldowns", "kit"]:
			_check(first[key] == second[key], "%s: the scripted fight is deterministic in %s" % [identity, key])
			_check(first[key] == with_hud[key], "%s: the HUD changes nothing in %s" % [identity, key])
		_check(first["snapshot_before"] == first["snapshot_after"] and with_hud["snapshot_before"] == with_hud["snapshot_after"], "%s: the exact snapshot is identical before and after the HUD updates" % identity)
		_check(first["snapshot_before"] != "capture failed" and with_hud["snapshot_before"] != "capture failed", "%s: the snapshots were captured" % identity)

func _scripted_fight(identity: StringName, hud: bool) -> Dictionary:
	var controller := _mount_hybrid(identity)
	_enrich(controller, identity)
	var player := controller.player
	var victim := _victim(controller)
	victim.set_process(false)
	var rotation: Array[StringName] = [&"fireball", &"ice_spear", &"lightning"]
	var step := 0
	while step < 120:
		step += 1
		if step % 20 == 1 and not player.has_active_cast():
			var skill := rotation[(step / 20) % rotation.size()]
			player.mage_cooldowns[skill] = 0.0
			controller._commit_skill(skill, victim.global_position)
		player._process(STEP)
		victim._process(STEP)
		controller._advance_runtime(STEP)
		if hud:
			controller._update_hud()
		await process_frame
	var cooldowns := {}
	for skill: StringName in player.available_skill_ids():
		cooldowns[skill] = snappedf(player.skill_cooldown(skill), 0.0001)
	var summary := {"damage": snappedf(victim.health.max_hp - victim.health.current_hp, 0.0001), "sp": snappedf(player.current_sp, 0.0001), "cooldowns": cooldowns, "kit": _authority_summary(player, identity)}
	# Exact snapshot of the whole controller before and after many HUD updates (cast bar,
	# panel, overlays, slot states): identical bytes. The registry accepts the HUD nodes and
	# variables only because they are declared presentation (runtime_manifest omitted).
	summary["snapshot_before"] = await _controller_snapshot(controller, identity)
	for _index: int in 30:
		controller._update_hud()
	summary["snapshot_after"] = await _controller_snapshot(controller, identity)
	await _discard(controller)
	return summary

func _controller_snapshot(controller: RunController, identity: StringName) -> String:
	var barrier := SnapshotTickBarrier.new()
	paused = true
	var acquired := barrier.acquire(controller)
	var digest := "no barrier"
	if acquired["ok"]:
		var result := SnapshotRegistry.new().capture(controller, barrier)
		_check(result.get("ok", false), "%s: the exact snapshot of the controller captures (%s)" % [identity, str(result.get("detail", result.get("error_code", "")))])
		digest = var_to_bytes(result["snapshot"]).hex_encode().sha256_text() if result.get("ok", false) else "capture failed"
		barrier.release()
	else:
		_check(false, "%s: the tick barrier was acquired (%s)" % [identity, str(acquired)])
	paused = false
	return digest

## The kit authority state without instance ids (they differ from mount to mount).
func _authority_summary(player: PlayerActor, identity: StringName) -> String:
	var described: Dictionary = player.kit.get("flank").describe(player) if identity == &"mg_la" else player.kit.get("sanctuary").describe()
	var clean := {}
	for key: Variant in described:
		if not String(key).ends_with("_id") and not String(key).ends_with("_serial"): clean[key] = described[key]
	return var_to_str(clean)

# --- World --------------------------------------------------------------------------------

func _mount_world(identity: StringName) -> Dictionary:
	var build := _build(identity)
	var snapshot := _snapshot(identity, build)
	RunController.pending_run_state = RunState.from_build("e12-h4-world-" + String(identity), snapshot)
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var controller := load("res://scenes/main.tscn").instantiate() as RunController
	controller.control_preferences.path = CONTROLS_PATH
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.rng.seed = 53
	var input := F1Fixture.make()
	input.traversal.radius *= 3
	input.traversal.height *= 3
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size(): surface.vertices[index] *= 3
			surface.headroom *= 3
		for connector: ExpeditionConnectorDefinition in part.connectors:
			connector.position *= 3
			connector.width *= 3
			connector.headroom *= 3
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position *= 3
		for index: int in part.solid_volumes.size():
			var volume := part.solid_volumes[index]
			part.solid_volumes[index] = AABB(volume.position * 3, volume.size * 3)
	var profile := input.traversal.to_data()
	var world := WorldGeometry.new()
	var assembled := ExpeditionAssembler.build(input)
	_check(assembled["ok"] and world.configure(assembled["data"]["manifest"], "sample")["ok"], "the world fixture builds")
	_check(controller.player.bind_world_geometry(world, F1Fixture.point("root", Vector3(90, 0, 150)), profile, "h4_player")["ok"], "the hybrid binds the world")
	var victim := controller.training_boss
	victim.set_process(false)
	_check(victim.bind_world_geometry(world, F1Fixture.point("root", Vector3(260, 0, 150)), profile, "h4_victim")["ok"], "the victim binds the world")
	victim.health.max_hp = 100000.0
	victim.health.current_hp = 100000.0
	# Binding to the world turns processing on again; the test drives the clocks by hand.
	controller.player.set_process(false)
	victim.set_process(false)
	var view := ExpeditionGeometryView.new()
	controller.add_child(view)
	_check(view.configure(world)["ok"], "the expedition view configures")
	_check(controller.attach_expedition_view(view, 36)["ok"], "the view attaches")
	controller.arena_view.hide()
	for obstacle: Node2D in controller._world_obstacle_views: obstacle.hide()
	controller.route_camera.limit_left = -2000
	controller.route_camera.limit_top = -2000
	controller.route_camera.limit_right = 3000
	controller.route_camera.limit_bottom = 3000
	controller.route_camera.position = Vector2(120, 80)
	controller.route_camera.reset_smoothing()
	controller.player.current_sp = controller.player.max_sp
	controller._update_hud()
	return {"controller": controller, "view": view, "world": world, "profile": profile}

func _check_world() -> void:
	for identity: StringName in [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"]:
		var mounted := _mount_world(identity)
		var controller: RunController = mounted["controller"]
		var player := controller.player
		var victim := controller.training_boss
		_check(player.world_motion != null and controller.expedition_view == mounted["view"], "%s: the controller runs in the expedition world" % identity)
		match identity:
			&"sp_ac":
				var authority: SanctuaryAuthority = player.kit.get("sanctuary")
				var cast := {"skill_id": OATH, "rank": 5, "element": &"light", "world": true, "anchor": player.world_point(), "point": Vector2.ZERO, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [victim]}
				_check(player.kit.resolve_cast(player, cast), "the Oath opens in the world")
				authority.grace.charges = 3
				authority.seal(player, victim, &"paladin_seal", 4.0, 2)
			&"mg_ac":
				_check(player.kit.resolve_cast(player, {"skill_id": CIRCLE, "rank": 5, "element": &"light", "world": true, "anchor": player.world_point(), "point": Vector2.ZERO, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [victim]}), "the Círculo Votivo opens in the world")
				player.kit.set("circle_element", &"fire")
				player.kit.call(&"_apply_zone_element", player)
				(player.kit.get("sanctuary") as SanctuaryAuthority).grace.charges = 2
			&"sp_la", &"mg_la":
				var flank: FlankAuthority = player.kit.get("flank")
				flank.mark_victim(player, victim)
				flank.gain(player, victim, FlankRules.SOURCE_COMBO, "h4_a")
				flank.gain(player, victim, FlankRules.SOURCE_DIRECT, "h4_b")
				if identity == &"mg_la":
					player.kit.set("refraction_charges", 0)
					player.kit.set("refraction_recharge", 5.0)
				else:
					player.kit.set("duel_remaining", 6.0)
		controller._update_hud()
		var dto := controller._hud_kit_state
		_check(not dto.is_empty() and KitHudState.validate(dto, player.kit)["ok"], "%s world: the shared DTO validates" % identity)
		var view: ExpeditionGeometryView = mounted["view"]
		var host_ok: bool = controller.kit_ground_overlay != null and controller.kit_ground_overlay.get_parent() == view and controller.kit_overhead_overlay.get_parent() == view
		_check(host_ok, "%s world: the overlays live in the expedition view (the snapshot never scans it)" % identity)
		if identity == &"sp_ac" or identity == &"mg_ac":
			var zones := _zones_of(dto, &"world")
			_check(zones.size() == 1 and controller.kit_ground_overlay.plan().size() == 1, "%s world: the zone is drawn on the world ground" % identity)
			var polygon: PackedVector2Array = controller.kit_ground_overlay.plan()[0]["polygon"]
			_check(polygon.size() >= 24, "%s world: the zone is projected point by point (%d points)" % [identity, polygon.size()])
			var expected_z := clampi(floori((zones[0]["center"] as Vector3).y * 4.0) + 1, -4000, 4000)
			_check(controller.kit_ground_overlay.z_index == expected_z and controller.kit_ground_overlay.z_index < player.z_index, "%s world: the zone sits between the deck and the actors (z %d < player %d)" % [identity, controller.kit_ground_overlay.z_index, player.z_index])
		_check(controller.kit_overhead_overlay.z_index > 4000, "%s world: the markers are above every actor" % identity)
		var marks := _marks_of(dto)
		_check(controller.kit_overhead_overlay.plan().size() == marks.size(), "%s world: the %d mark(s) follow the living victim" % [identity, marks.size()])
		# The world snapshot ignores the overlays and the HUD nodes.
		var barrier := SnapshotTickBarrier.new()
		paused = true
		var acquired := barrier.acquire(controller)
		if acquired["ok"]:
			var result := SnapshotRegistry.new().capture(controller, barrier)
			_check(result.get("ok", false), "%s world: the exact snapshot still captures with the HUD wired (%s)" % [identity, str(result.get("detail", result.get("error_code", "")))])
			barrier.release()
		else:
			_check(false, "%s world: the tick barrier was acquired" % identity)
		paused = false
		if identity == &"mg_la":
			var button := controller.battle_controls.skill_buttons.get(REFRACTION) as ActionBarSlot
			_check(button != null and button.blocked_hint.text == "SEM CARGA" and button.cooldown_hint.text == "5.0", "mg_la world: the Refração slot says SEM CARGA and the kit recharge")
			_check(player.world_motion != null and not controller.player.kit_owns_skill(&"nothing"), "mg_la world: the real kit still owns its skills")
			_check_world_cast_bar(controller, victim)
		await _discard(controller)

## The player's cast bar in the expedition world: the whole preparation, then cancellation.
func _check_world_cast_bar(controller: RunController, victim: CombatActor) -> void:
	var player := controller.player
	var bar := controller.cast_bar
	player.mage_cooldowns.clear()
	player.current_sp = player.max_sp
	controller._commit_skill(&"fireball", victim.global_position)
	_check(player.has_active_cast(), "world: the fireball starts its preparation")
	controller._update_hud()
	var total := player.active_cast_total
	_check(total > 0.0 and bar.visible and bar.plan()["label"] == ClassCatalog.skill_definition(&"fireball").display_name, "world: the cast bar shows the skill (%.2fs)" % total)
	_close(float(bar.plan()["ratio"]), 0.0, "world: the bar starts empty")
	_close(bar.offset_top, -258.0, "world: the cast bar sits above the status line the world keeps during a cast")
	player._advance_world_cast(total * 0.5)
	controller._update_hud()
	_close(float(bar.plan()["ratio"]), 0.5, "world: the bar is at half", 0.02)
	_check(controller.battle_controls.aim_label.text.is_empty() or controller.battle_controls.aim_label.text == "mover / Direito / Esc cancela", "world: no 'Conjurando' text")
	player._advance_world_cast(total * 0.45)
	controller._update_hud()
	_check(float(bar.plan()["ratio"]) > 0.9, "world: the bar covers the preparation up to its end")
	_check(player.cancel_active_cast(), "world: Esc cancels the preparation")
	controller._update_hud()
	_check(bar.is_flashing() and bar.plan()["color"] == HudPalette.flash_color(&"cancel"), "world: cancelling flashes the bar in the cancel color")
	bar._process(0.5)
	_check(not bar.visible, "world: the cancelled bar disappears")

# --- Native captures ------------------------------------------------------------------------

func _save(path_name: String, region: Rect2i = Rect2i()) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if region.size.x > 0: image = image.get_region(region)
	var path := capture_directory.path_join(path_name)
	_check(not image.is_empty() and image.save_png(path) == OK, "native capture " + path_name)

func _live(controller: RunController, frames: int = 3) -> void:
	for _index: int in frames:
		controller._update_hud()
		controller.player.queue_redraw()
		for enemy: CombatActor in controller.enemies: enemy.queue_redraw()
		await process_frame

func _captures() -> void:
	# Flat: each hybrid in combat with its resource, zone and mark.
	for identity: StringName in IDENTITIES:
		var controller := _mount_hybrid(identity)
		_enrich(controller, identity)
		controller.player.global_position = Vector2(560, 420)
		controller.camera_for_capture() if controller.has_method("camera_for_capture") else null
		controller.set_process(false)
		await _live(controller)
		await _save("h4_flat_%s.png" % identity)
		await _discard(controller)
	# Player cast bar (flat, mid preparation) and a mob cast.
	var caster := _mount_hybrid(&"mg_la")
	caster.player.global_position = Vector2(560, 420)
	_victim(caster).global_position = Vector2(820, 420)
	caster.player.mage_cooldowns.clear()
	caster._commit_skill(&"fireball", _victim(caster).global_position)
	caster.player._process(caster.player.active_cast_total * 0.5)
	await _live(caster)
	caster._update_aim(_victim(caster).global_position)
	await _live(caster)
	await _save("h4_flat_player_cast.png")
	await _discard(caster)
	for category: StringName in [&"normal", &"elite"]:
		var mob := _mount_hybrid(&"mg_ac")
		mob.player.global_position = Vector2(560, 420)
		_victim(mob).global_position = Vector2(1100, 800)
		var enemy := _caster(mob, Vector2(840, 420), category)
		_check(enemy._try_declared_skill(), "the capture mob prepares its skill")
		enemy._advance_mob_cast(float(enemy._mob_cast["cast_time"]) * 0.45)
		enemy._advance_cast_bar(0.0)
		await _live(mob)
		await _save("h4_flat_mob_cast_%s.png" % category)
		await _discard(mob)
	# World.
	if _world_available:
		for identity: StringName in [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"]:
			var mounted := _mount_world(identity)
			var controller: RunController = mounted["controller"]
			var player := controller.player
			var victim := controller.training_boss
			match identity:
				&"sp_ac":
					var authority: SanctuaryAuthority = player.kit.get("sanctuary")
					player.kit.resolve_cast(player, {"skill_id": OATH, "rank": 5, "element": &"light", "world": true, "anchor": player.world_point(), "point": Vector2.ZERO, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [victim]})
					authority.grace.charges = 3
					authority.seal(player, victim, &"paladin_seal", 4.0, 2)
				&"mg_ac":
					player.kit.resolve_cast(player, {"skill_id": CIRCLE, "rank": 5, "element": &"light", "world": true, "anchor": player.world_point(), "point": Vector2.ZERO, "facing": Vector3.RIGHT, "facing_2d": Vector2.RIGHT, "target": null, "actors": [victim]})
					player.kit.set("circle_element", &"fire")
					player.kit.call(&"_apply_zone_element", player)
					(player.kit.get("sanctuary") as SanctuaryAuthority).grace.charges = 2
				&"sp_la", &"mg_la":
					var flank: FlankAuthority = player.kit.get("flank")
					flank.mark_victim(player, victim)
					for index: int in 4: flank.gain(player, victim, FlankRules.SOURCE_COMBO if index % 2 == 0 else FlankRules.SOURCE_DIRECT, "h4_%d" % index)
					if identity == &"mg_la":
						player.kit.set("refraction_charges", 0)
						player.kit.set("refraction_recharge", 5.0)
					else:
						player.kit.set("duel_remaining", 6.0)
			player.kit_time = 9.0
			await _live(controller)
			await _save("h4_world_%s.png" % identity)
			await _discard(controller)

		var cast_world := _mount_world(&"mg_la")
		var cast_controller: RunController = cast_world["controller"]
		cast_controller.player.mage_cooldowns.clear()
		var cast_victim := cast_controller.training_boss
		cast_controller._commit_skill(&"fireball", cast_victim.global_position)
		cast_controller.player._advance_world_cast(cast_controller.player.active_cast_total * 0.5)
		await _live(cast_controller)
		await _save("h4_world_player_cast.png")
		await _discard(cast_controller)
