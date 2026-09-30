extends SceneTree

var checks := 0
var failures := 0
var controller: RunController
var base_request: DamageRequest
var captured_marked_bonus := 0.0
var captured_focus_bonus := 0.0
var marked_result: Dictionary = {}
var unmarked_result: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"spiritualist_dissipation")
	var definition := ClassCatalog.skill_definition(&"spiritualist_dissipation")
	_check(catalog.is_valid() and metadata["rank_requirements"][1]["job_level"] == 37 and definition.is_rank_catalog_valid(), "Rite unlocks at job 37 with typed ranks")
	var powers: Array[float] = [0.85, 1.00, 1.12, 1.23, 1.32]
	for index: int in range(5):
		var rank := definition.rank_definition(index + 1)
		_check(is_equal_approx(rank.power, powers[index]) and is_equal_approx(rank.secondary_power, 0.55) and is_equal_approx(rank.range, 330.0) and is_equal_approx(rank.cooldown, 14.0), "R%d stores approved direct and marked power" % (index + 1))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_dissipation": 1, &"spiritualist_channel_focus": 1}
	snapshot.active_slots = [&"spiritualist_dissipation", &"spiritualist_echo_curse", null, null, null]
	snapshot.passive_slots = [&"spiritualist_channel_focus", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("rite", snapshot))
	player.global_position = Vector2(400, 350)
	var marked := _enemy(Vector2(490, 350))
	var unmarked := _enemy(Vector2(550, 350))
	var outside := _enemy(Vector2(750, 350))
	controller = RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	controller.enemies = [marked, unmarked, outside]
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	marked.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	unmarked.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	marked.health.damage_applied.connect(_record_marked)
	unmarked.health.damage_applied.connect(_record_unmarked)
	player.spiritualist_dissipation_requested.connect(_on_request)
	player.spiritualist_focus_event.connect(controller._on_spiritualist_focus_event)
	_check(player.can_place_spiritualist_dissipation(Vector2(480, 350)) and not player.can_place_spiritualist_dissipation(Vector2(700, 350)), "point placement rejects obstacle crossings")
	_check(player.spiritualist_dissipation_center(Vector2(1000, 350)).distance_to(player.global_position) <= 330.001 and SkillGeometry.SPIRITUALIST_DISSIPATION_RADIUS == 100.0, "range clamp and shared radius are authoritative")
	marked.apply_weaken(0.15, 3.0, &"spiritualist_spectral_veil")
	controller.spiritualist_echo_state.mark(marked.get_instance_id(), 0.35)
	player.grant_spiritualist_focus()
	var magic_attack := player.spiritualist_magic_attack()
	var outside_hp := outside.health.current_hp
	var sp_before := player.current_sp
	_check(player.use_spiritualist_dissipation(Vector2(500, 350)) and player.current_sp == sp_before - 27.0 and player.skill_cooldown(&"spiritualist_dissipation") > 0.0, "commit spends ranked SP and cooldown")
	_check(base_request != null and is_equal_approx(base_request.magic_damage, magic_attack * 0.85) and is_equal_approx(captured_marked_bonus, magic_attack * 0.55) and is_equal_approx(captured_focus_bonus, magic_attack * 0.20), "base, mark and Focus components captured separately at commit")
	_check(not marked_result.is_empty() and not unmarked_result.is_empty() and float(marked_result["actual_damage"]) > 0.0 and float(unmarked_result["actual_damage"]) > 0.0 and outside.health.current_hp == outside_hp, "one root hits each visible target inside area only")
	_check(float(marked_result["magic_component"]) > float(unmarked_result["magic_component"]) and player.spiritualist_focus_remaining == 0.0, "first target gets mark and Focus in same request; later target does not get Focus")
	_check(not controller.spiritualist_echo_state.has_mark(marked.get_instance_id()) and controller.spiritualist_echo_state.pending.is_empty(), "positive Rite consumes mark without creating echo")
	_check(is_equal_approx(marked.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT), 0.20) and is_equal_approx(unmarked.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT), 0.20), "positive surviving targets receive 20 percent weakness")
	_check(outside.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0 and controller.battle_indicators.spiritualist_events[0]["kind"] == &"focus_grant", "outside target untouched and actual visual events are queued")
	controller.spiritualist_echo_state.mark(marked.get_instance_id(), 0.35)
	marked.health.grant_shield(10000.0)
	player.current_sp = player.max_sp
	player.mage_cooldowns[&"spiritualist_dissipation"] = 0.0
	var marked_hp := marked.health.current_hp
	_check(player.use_spiritualist_dissipation(Vector2(500, 350)) and marked.health.current_hp == marked_hp and controller.spiritualist_echo_state.has_mark(marked.get_instance_id()), "fully absorbed Rite preserves curse")
	_check(marked.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_dissipation") > 0.0, "earlier positive Rite debuff remains independently timed")
	var blocked_sp := player.current_sp
	player.mage_cooldowns[&"spiritualist_dissipation"] = 0.0
	_check(not player.use_spiritualist_dissipation(Vector2(700, 350)) and player.current_sp == blocked_sp, "blocked cast fails without cost or mark consumption")
	player.free()
	marked.free()
	unmarked.free()
	outside.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Dissipação: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _on_request(center: Vector2, request: DamageRequest, marked_bonus: float, focus_bonus: float) -> void:
	request.can_crit = false
	base_request = request.copy()
	captured_marked_bonus = marked_bonus
	captured_focus_bonus = focus_bonus
	controller._on_spiritualist_dissipation_requested(center, request, marked_bonus, focus_bonus)

func _record_marked(result: Dictionary) -> void:
	marked_result = result.duplicate(true)

func _record_unmarked(result: Dictionary) -> void:
	unmarked_result = result.duplicate(true)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
