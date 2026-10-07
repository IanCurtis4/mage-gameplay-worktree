extends SceneTree

var checks := 0
var failures := 0
var controller: RunController
var curse_requests: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"spiritualist_channel_focus")
	var definition := ClassCatalog.skill_definition(&"spiritualist_channel_focus")
	_check(catalog.is_valid() and metadata["rank_requirements"][1]["job_level"] == 31 and definition.is_rank_catalog_valid() and definition.category == SkillDefinition.Category.PASSIVE, "Focus unlocks at job 31 as three-rank passive")
	for index: int in range(3):
		_check(is_equal_approx(definition.rank_definition(index + 1).power, 0.20 + float(index) * 0.10), "R%d stores approved root bonus" % (index + 1))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.job_level = 31
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_soul_drain": 1, &"spiritualist_channel_focus": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", &"spiritualist_soul_drain", null, null, null]
	snapshot.passive_slots = [&"spiritualist_channel_focus", null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("focus", snapshot))
	player.global_position = Vector2(400, 350)
	var enemy := _enemy(Vector2(500, 350))
	controller = RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	player.spiritualist_drain_requested.connect(_on_drain_request)
	player.spiritualist_channel_interrupt_requested.connect(controller._cancel_spiritualist_drain)
	player.spiritualist_focus_event.connect(controller._on_spiritualist_focus_event)
	player.spiritualist_echo_curse_requested.connect(_on_curse_request)
	_check(player.use_spiritualist_soul_drain(enemy), "drain commit starts channel for learned automatic Focus")
	for index: int in range(3):
		controller._advance_spiritualist_drain(0.5)
	_check(player.spiritualist_focus_remaining == 0.0, "three ticks never grant charge")
	controller._advance_spiritualist_drain(0.5)
	_check(player.spiritualist_focus_remaining == 5.0 and player.spiritualist_focus_power == 0.20, "four valid ticks grant one five-second charge")
	_check(_has_event(&"focus_grant"), "charge formation uses caster sigil")
	var magic_attack := player.spiritualist_magic_attack()
	_check(not player.use_spiritualist_echo_curse(null) and player.spiritualist_focus_remaining == 5.0, "invalid curse does not consume charge")
	_check(player.use_spiritualist_echo_curse(enemy) and curse_requests.size() == 1, "valid curse commits with charge")
	_check(is_equal_approx(curse_requests[0].magic_damage, magic_attack * (0.85 + 0.20)) and player.spiritualist_focus_remaining == 0.0, "only root direct damage gains captured bonus")
	_check(controller.battle_indicators.spiritualist_events[-1]["kind"] == &"focus_consume", "real consumption uses separate brief feedback")
	_check(player.consume_spiritualist_focus() == 0.0, "charge cannot be consumed twice")
	player.grant_spiritualist_focus()
	player._process(5.1)
	_check(player.spiritualist_focus_remaining == 0.0 and player.consume_spiritualist_focus() == 0.0, "charge expires after five simulated seconds")
	player.grant_spiritualist_focus()
	player.clear_spiritualist_state()
	_check(player.spiritualist_focus_remaining == 0.0 and player.spiritualist_focus_power == 0.0, "encounter cleanup removes charge")
	var inactive_snapshot := snapshot.copy_snapshot()
	inactive_snapshot.passive_slots = [null, null]
	inactive_snapshot.skill_ranks.erase(&"spiritualist_channel_focus")
	var inactive := PlayerActor.new()
	inactive.configure(nav, RunState.from_build("inactive", inactive_snapshot))
	_check(not inactive.grant_spiritualist_focus() and inactive.spiritualist_focus_remaining == 0.0, "unlearned Focus never charges")
	var high_snapshot := snapshot.copy_snapshot()
	high_snapshot.skill_ranks[&"spiritualist_channel_focus"] = 3
	high_snapshot.passive_slots = [null, null]
	var high := PlayerActor.new()
	high.configure(nav, RunState.from_build("rank3", high_snapshot))
	_check(high.grant_spiritualist_focus() and is_equal_approx(high.consume_spiritualist_focus(), high.spiritualist_magic_attack() * 0.40), "learned automatic R3 uses forty percent of current ATQM without legacy equip")
	player.free()
	inactive.free()
	high.free()
	enemy.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Foco do Além: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _on_drain_request(request: DamageRequest, enemy: CombatActor) -> void:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	controller._on_spiritualist_drain_requested(request, enemy)

func _on_curse_request(request: DamageRequest, _enemy: CombatActor, _power: float) -> void:
	curse_requests.append(request.copy())

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

func _has_event(kind: StringName) -> bool:
	for event: Dictionary in controller.battle_indicators.spiritualist_events:
		if event["kind"] == kind:
			return true
	return false
