extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW9 Vigor: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"vigor")
	var meta := ProfileCatalog.pilot().skill_metadata(&"vigor")
	_check(skill != null and skill.display_name == "Vigor" and skill.category == SkillDefinition.Category.PASSIVE and skill.handler_id == SkillDefinition.Handler.VIGOR and skill.is_rank_catalog_valid(), "catálogo publica passiva Vigor")
	_check(meta.get("category") == ProfileCatalog.PASSIVE and meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 3, "biblioteca R0 vende R1–R3")
	var bonuses: Array[float] = [0.50, 0.80, 1.10]
	for index: int in 3:
		var rank := skill.rank_definition(index + 1)
		var source := ClassCatalog.passive_modifier_source(&"vigor", index + 1)
		_check(rank.power == bonuses[index] and rank.effect_ids == [&"hp_regeneration_increase"] and source["increased"][&"hp_regen"] == bonuses[index], "R%d fornece fonte identificada" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(4) == null and ClassCatalog.passive_modifier_source(&"vigor", 0).is_empty(), "ranks inválidos não geram fonte")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 3, 4]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "vigor-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.job_level = 20
		snapshot.skill_ranks = {&"vigor": rank}
		snapshot.passive_slots = [null, null] # Learned Vigor operates automatically.
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		root.add_child(player)
		player.set_process(false)
		var base_regen := StatCalculator.calculate(IdentityIds.initial_attributes(&"swordsman")).value(&"hp_regen")
		var expected := base_regen * (1.0 + (0.50 if rank == 1 else 1.10 if rank == 3 else 0.0))
		_check(is_equal_approx(player.stat_breakdown.value(&"hp_regen"), expected), "R%d usa StatCalculator sem fórmula no ator" % rank)
		player.health.current_hp -= 20.0
		var before_hp := player.health.current_hp
		_check(not player.regenerate_hp(1.0, true, false) and player.health.current_hp == before_hp, "R%d não regenera durante encontro" % rank)
		_check(not player.regenerate_hp(1.0, false, true) and player.health.current_hp == before_hp, "R%d pausa congela regeneração" % rank)
		_check(player.regenerate_hp(1.0, false, false) and is_equal_approx(player.health.current_hp, before_hp + expected), "R%d regenera fora de combate por stat derivado" % rank)
		var copy := snapshot.copy_snapshot()
		_check(copy.passive_slots == snapshot.passive_slots and copy.skill_ranks == snapshot.skill_ranks, "R%d snapshot preserva ranks e arrays legados, não exige equipagem" % rank)
		player.queue_free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW9: %s" % label)
