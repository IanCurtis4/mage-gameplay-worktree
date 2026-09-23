extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW10 Sede de Sangue: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"blood_thirst")
	var meta := ProfileCatalog.pilot().skill_metadata(&"blood_thirst")
	_check(skill != null and skill.display_name == "Sede de Sangue" and skill.category == SkillDefinition.Category.PASSIVE and skill.handler_id == SkillDefinition.Handler.BLOOD_THIRST and skill.is_rank_catalog_valid(), "catálogo publica passiva")
	_check(meta.get("category") == ProfileCatalog.PASSIVE and meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 3, "R0 vende R1–R3")
	var ratios: Array[float] = [0.60, 0.90, 1.20]
	for index: int in 3:
		var rank := skill.rank_definition(index + 1)
		var source := ClassCatalog.passive_modifier_source(&"blood_thirst", index + 1, 10.0)
		_check(rank.power == ratios[index] and source["flat"][&"melee_attack"] == 10.0 * ratios[index], "R%d converte VIT investida sem consumi-la" % [index + 1])
		_check(is_equal_approx(ClassCatalog.blood_thirst_heal_fraction(index + 1), 0.02 + float(index) * 0.01), "R%d cura pequena por abate" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(4) == null and ClassCatalog.blood_thirst_heal_fraction(4) == 0.0, "ranks inválidos sem efeito")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 3, 4]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "blood-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.attribute_allocations = {&"vit": 10}
		snapshot.skill_ranks = {&"blood_thirst": rank}
		snapshot.passive_slots = [&"blood_thirst", null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		root.add_child(player)
		player.set_process(false)
		var base_stats := StatCalculator.calculate(IdentityIds.initial_attributes(&"swordsman"), {&"vit": 10})
		var ratio := 0.60 if rank == 1 else 1.20 if rank == 3 else 0.0
		_check(is_equal_approx(player.stat_breakdown.value(&"melee_attack"), base_stats.value(&"melee_attack") + 10.0 * ratio) and player.stat_breakdown.primary_value(&"vit") == base_stats.primary_value(&"vit"), "R%d bônus não consome VIT nem depende de adds" % rank)
		player.health.current_hp = player.health.max_hp - 100.0
		var before_hp := player.health.current_hp
		var controller := RunController.new()
		controller.player = player
		var first := _target()
		first.health.damage_applied.connect(controller._on_enemy_damage_resolved)
		var recorded: Array[Dictionary] = []
		first.health.damage_applied.connect(func(result: Dictionary) -> void: recorded.append(result))
		var request := _lethal_request(player, first)
		first.apply_damage(request, RandomNumberGenerator.new())
		var expected_heal := player.health.max_hp * ClassCatalog.blood_thirst_heal_fraction(rank)
		_check(is_equal_approx(player.health.current_hp, before_hp + expected_heal), "R%d abate atribuído cura uma vez" % rank)
		controller._on_enemy_damage_resolved(recorded[0])
		_check(is_equal_approx(player.health.current_hp, before_hp + expected_heal), "R%d callback duplicado não cura novamente" % rank)
		var second := _target()
		second.health.damage_applied.connect(controller._on_enemy_damage_resolved)
		var secondary := _lethal_request(player, second)
		secondary.is_secondary = true
		second.apply_damage(secondary, RandomNumberGenerator.new())
		_check(is_equal_approx(player.health.current_hp, before_hp + expected_heal * 2.0), "R%d DoT/efeito secundário atribuído cura apenas por outro abate" % rank)
		first.queue_free()
		second.queue_free()
		player.queue_free()
		controller.free()
		await process_frame

func _target() -> CombatActor:
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 1}), 18.0)
	root.add_child(target)
	target.set_process(false)
	return target

func _lethal_request(player: PlayerActor, target: CombatActor) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = player.get_instance_id()
	request.target_id = target.get_instance_id()
	request.physical_damage = 1000.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW10: %s" % label)
