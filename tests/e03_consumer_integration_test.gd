extends SceneTree

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e03_consumers")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	await _test_preview_snapshot_runtime_hud()
	_test_combat_contract()
	_test_dot_offense_capture()
	_cleanup_directory(root_directory)
	print("E03 consumidores: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_preview_snapshot_runtime_hud() -> void:
	var facade := ProfileFacade.new(ProfileStore.new(root_directory))
	var created := facade.create_character("create-mage", 0, "Lina", &"mage")
	_check(created["ok"], "fixture character is created through the profile boundary")
	var character_id: String = created["character_id"]
	var preview := facade.build_preview(character_id)
	_check(preview["ok"], "menu preview is produced by ProfileFacade")
	var preview_stats: StatBreakdown = preview["stat_breakdown"]
	var snapshot: BuildSnapshot = preview["snapshot"]
	var snapshot_stats := snapshot.stat_breakdown()
	_check(_same_values(preview_stats, snapshot_stats), "preview and its value snapshot have identical canonical stats")
	_check(ClassCatalog.skill_definition(&"fireball").accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and ClassCatalog.skill_definition(&"fire_spear").accuracy_mode == DamageRequest.AccuracyMode.CONTESTED, "skill catalog distinguishes geometry effects from targeted shots")

	var menu_scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var summary := menu.build_summary_label.text
	_check(summary.contains("Vida %d" % int(preview_stats.value(&"max_hp"))) and summary.contains("SP %d" % int(preview_stats.value(&"max_sp"))) and summary.contains("ATQ mágico %d" % int(preview_stats.value(&"magic_attack"))), "character menu renders values from the canonical preview")

	var started := facade.start_run("start-run", facade.current_profile().revision)
	_check(started["ok"], "run starts from the previewed persistent build")
	var state: RunState = started["run_state"]
	menu.queue_free()
	await process_frame
	RunController.pending_run_state = state
	RunController.pending_run_facade = facade
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await process_frame
	var controller := current_scene as RunController
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	var run_snapshot_stats := state.build_snapshot.stat_breakdown()
	_check(_same_values(preview_stats, run_snapshot_stats), "run snapshot retains the exact previewed stat values")
	_check(_same_values(run_snapshot_stats, controller.player.stat_breakdown), "runtime actor consumes the same snapshot values")
	controller._update_hud()
	_check(controller.health_label.text == "VIDA  %d / %d" % [ceili(controller.player.health.current_hp), ceili(preview_stats.value(&"max_hp"))] and controller.sp_label.text == "SP  %d / %d" % [floori(controller.player.current_sp), floori(preview_stats.value(&"max_sp"))], "HUD reads HP and SP from the runtime canonical state")

	controller.player.health.current_hp -= 25.0
	controller.player.current_sp -= 17.0
	controller.player.attack_cooldown = 0.75
	controller.player.mage_cooldowns[&"fireball"] = 1.25
	state.augment_stacks[&"vitality"] = 1
	controller.player.apply_run_modifiers(state)
	var expected_after := state.build_snapshot.stat_breakdown(state.stat_modifier_sources())
	_check(_same_values(expected_after, controller.player.stat_breakdown), "runtime recalculation still delegates every stat to StatCalculator")
	_check(controller.player.health.current_hp == controller.player.health.max_hp - 25.0 and controller.player.current_sp == controller.player.max_sp - 17.0, "recalculation preserves missing HP and SP instead of healing")
	_check(controller.player.attack_cooldown == 0.75 and controller.player.mage_cooldowns[&"fireball"] == 1.25, "recalculation preserves active attack and skill cooldowns")

	var hp_regen := controller.player.stat_breakdown.value(&"hp_regen")
	controller.encounter_active = true
	var hp_before := controller.player.health.current_hp
	controller._process(10.0)
	_check(controller.player.health.current_hp == hp_before, "HP does not regenerate during an active encounter")
	controller.encounter_active = false
	paused = true
	controller._process(10.0)
	paused = false
	_check(controller.player.health.current_hp == hp_before, "tree pause freezes out-of-encounter HP regeneration")
	controller.player.health.current_hp = 0.0
	controller._process(10.0)
	_check(controller.player.health.current_hp == 0.0, "dead player does not regenerate HP")
	controller.player.health.current_hp = controller.player.health.max_hp - 10.0
	controller._process(2.0)
	_check(is_equal_approx(controller.player.health.current_hp, controller.player.health.max_hp - 10.0 + hp_regen * 2.0), "living player consumes canonical hp_regen outside encounters")
	controller.player.health.current_hp = controller.player.health.max_hp - 0.1
	controller._process(10.0)
	_check(controller.player.health.current_hp == controller.player.health.max_hp, "HP regeneration clamps at the current maximum")
	controller.queue_free()
	await process_frame

func _test_combat_contract() -> void:
	var mixed := DamageRequest.new()
	mixed.physical_damage = 100.0
	mixed.magic_damage = 100.0
	mixed.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	mixed.can_crit = false
	var mixed_result := CombatMath.resolve(mixed, 100.0, 300.0, 999.0, 0.5, 0.999, 0.0)
	_check(mixed_result["landed"] and mixed_result["damage"] == 75, "geometry hit mitigates physical and magic components separately and rounds once")
	mixed.damage_dealt_multiplier = 0.0
	var zero_factor := CombatMath.resolve(mixed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
	_check(zero_factor["landed"] and zero_factor["damage"] == 0, "zero offensive factor does not manufacture minimum damage")
	mixed.damage_dealt_multiplier = 1.0

	var contested := DamageRequest.new()
	contested.physical_damage = 100.0
	contested.hit_rating = 100.0
	contested.crit_chance = 0.50
	contested.crit_multiplier = 2.0
	contested.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	var miss := CombatMath.resolve(contested, 0.0, 0.0, 100.0, 0.20, 0.91, 0.0)
	var critical := CombatMath.resolve(contested, 0.0, 0.0, 100.0, 0.20, 0.89, 0.29)
	var normal := CombatMath.resolve(contested, 0.0, 0.0, 100.0, 0.20, 0.89, 0.31)
	_check(is_equal_approx(float(miss["hit_chance"]), 0.90) and not miss["landed"], "contested attacks resolve HIT against current FLEE")
	_check(is_equal_approx(float(critical["effective_crit_chance"]), 0.30) and critical["critical"] and critical["damage"] == 200, "critical resistance and the captured critical multiplier govern critical damage")
	_check(not normal["critical"] and normal["damage"] == 100, "roll above effective critical chance remains a normal landed hit")

	var target_sources: Array[Dictionary] = [{
		"source_id": &"combat_target",
		"flat": {&"max_hp": 900.0, &"physical_defense": 100.0, &"magic_defense": 300.0},
	}]
	var target_stats := StatCalculator.calculate({}, {}, 1, target_sources)
	var health := HealthState.new(77, target_stats)
	mixed.target_id = 77
	var applied := health.apply(mixed, 0.999, 0.999)
	_check(applied["actual_damage"] == 75.0 and health.current_hp == 925.0, "HealthState applies the canonical mixed result exactly once")

func _test_dot_offense_capture() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 600, 300), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.new(&"mage"))
	player.position = Vector2(100, 120)
	root.add_child(player)
	player.set_process(false)
	var doubled_sources: Array[Dictionary] = [{"source_id": &"dot_offense", "increased": {&"damage_dealt_multiplier": 1.0}}]
	player._apply_derived_stats(player.run_state.build_snapshot.stat_breakdown(doubled_sources))
	var emitted: Array[DamageRequest] = []
	player.fire_wall_requested.connect(func(_direction: Vector2, request: DamageRequest) -> void: emitted.append(request))
	_check(player.use_fire_wall(Vector2.RIGHT) and emitted.size() == 1 and emitted[0].damage_dealt_multiplier == 2.0, "fire wall emission captures the canonical offensive multiplier")

	var target_sources: Array[Dictionary] = [{"source_id": &"dot_target", "flat": {&"max_hp": 900.0}}]
	var target := CombatActor.new()
	target.setup("Alvo DoT", Color.WHITE, StatCalculator.calculate({}, {}, 1, target_sources))
	target.position = player.position + Vector2(180, -27)
	root.add_child(target)
	target.set_process(false)
	var tick_results: Array[Dictionary] = []
	target.status_damage_requested.connect(func(request: DamageRequest, actor: CombatActor) -> void:
		tick_results.append(actor.health.apply(request, 0.0, 0.0))
	)
	var captured := emitted[0].copy()
	var wall := FireWall.new()
	wall.configure(player, Vector2.RIGHT, emitted[0], [target])
	root.add_child(wall)
	wall.set_process(false)
	wall._process(0.01)
	_check(target.is_burning(), "fire wall transfers its captured request into one burn stream")
	emitted[0].magic_damage = 999.0
	emitted[0].damage_dealt_multiplier = 4.0
	var later_sources: Array[Dictionary] = [{"source_id": &"later_offense", "increased": {&"damage_dealt_multiplier": 3.0}}]
	player._apply_derived_stats(player.run_state.build_snapshot.stat_breakdown(later_sources))
	var expected_first := CombatMath.resolve(captured, target.health.physical_defense, target.health.magic_defense, target.health.flee_rating, target.health.crit_resistance, 0.0, 0.0)
	target.advance_statuses(1.0)
	_check(tick_results.size() == 1 and tick_results[0]["damage"] == expected_first["damage"], "burn keeps launch offense immutable and applies its multiplier exactly once")

	var defended_sources: Array[Dictionary] = [{"source_id": &"dot_target_defense", "flat": {&"max_hp": 900.0, &"magic_defense": 100.0}}]
	target.health.set_stats_preserving_missing(StatCalculator.calculate({}, {}, 1, defended_sources))
	var expected_second := CombatMath.resolve(captured, target.health.physical_defense, target.health.magic_defense, target.health.flee_rating, target.health.crit_resistance, 0.0, 0.0)
	target.advance_statuses(1.0)
	_check(tick_results.size() == 2 and tick_results[1]["damage"] == expected_second["damage"] and int(expected_second["damage"]) < int(expected_first["damage"]), "burn consults the target's current magic defense on every tick")

	var zero_multiplier := captured.copy()
	zero_multiplier.damage_dealt_multiplier = 0.0
	target.apply_burn(zero_multiplier, 1.0)
	target.advance_statuses(1.0)
	_check(tick_results.size() == 3 and tick_results[2]["damage"] == 0, "captured zero damage multiplier produces no DoT minimum damage")
	wall.free()
	player.free()
	target.free()

func _same_values(left: StatBreakdown, right: StatBreakdown) -> bool:
	if left == null or right == null:
		return false
	var left_values := left.values()
	var right_values := right.values()
	if left_values.keys() != right_values.keys():
		return false
	for stat_id: StringName in left_values:
		if not is_equal_approx(left_values[stat_id], right_values[stat_id]):
			return false
	return true

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
