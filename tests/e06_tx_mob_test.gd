extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	var catalog := BuildContentLoader.pilot().mob_catalog()
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0)
	var state := RunState.new(&"mage")
	var hero := PlayerActor.new()
	hero.configure(nav, state)
	hero.position = Vector2(200, 200)
	root.add_child(hero)
	hero.set_process(false)
	for row: Array in [[&"demo_chaser", {"str": 5, "agi": 3, "vit": 3, "int": 1, "dex": 4, "luk": 1}, &"enemy_warrior_tuning", -62.0, -25.0], [&"demo_archer", {"str": 4, "agi": 5, "vit": 2, "int": 1, "dex": 7, "luk": 1}, &"enemy_archer_tuning", -68.0, -45.0]]:
		var original := StatCalculator.calculate(row[1], {}, 1, [{"source_id": row[2], "flat": {&"max_hp": row[3], &"move_speed": row[4]}}])
		var actual: StatBreakdown = catalog.stats(row[0])["breakdown"]
		_check(actual.values() == original.values(), "current demo stats are exactly preserved " + String(row[0]))
		var occurrence := MobOccurrence.new()
		occurrence.occurrence_id = "fixed_" + String(row[0])
		occurrence.mob_base_id = row[0]
		occurrence.category_id = &"normal"
		occurrence.origin_id = &"demo_arena"
		var actor := EnemyActor.new()
		_check(actor.configure_occurrence(occurrence, catalog, nav, hero)["ok"], "fixed species config succeeds")
		state.build_snapshot.base_level = 30
		hero.apply_run_modifiers(state)
		var second := EnemyActor.new()
		second.configure_occurrence(occurrence, catalog, nav, hero)
		_check(actor.stat_breakdown.values() == second.stat_breakdown.values() and second.stat_breakdown.base_level == 1, "mob never scales with player level")
		occurrence.category_id = &"elite"
		_check(actor.configure_occurrence(occurrence, catalog, nav, hero)["error_code"] == &"invalid_mob_category" and actor.occurrence.category_id == &"normal", "forbidden occurrence rejected without changing actor")
		var exposed := catalog.get_definition(row[0])
		exposed.fixed_level = 30
		_check(catalog.get_definition(row[0]).fixed_level == 1, "catalog getter returns copied species")
		actor.free()
		second.free()
	for skill: StringName in MobSkillAdapters.IDS:
		var definition := MobDefinition.new()
		definition.id = StringName("caster_" + String(skill))
		definition.display_name = "Conjurador de teste"
		definition.fixed_level = 7
		definition.archetype = &"archer"
		definition.animation_kind = &"archer"
		definition.base_category = &"elite"
		definition.allowed_occurrence_categories = [&"elite", &"rare_elite"]
		definition.skill_ids = [skill]
		definition.skill_ranks = {skill: 3}
		for axis: StringName in StatCalculator.PRIMARY_IDS: definition.primary_attributes[axis] = 3
		_check(catalog.register_definition(definition)["ok"], "concrete skill adapter registered")
		var occurrence := MobOccurrence.new()
		occurrence.occurrence_id = String(definition.id)
		occurrence.mob_base_id = definition.id
		occurrence.category_id = &"elite"
		occurrence.origin_id = &"fixture_arena"
		var actor := EnemyActor.new()
		actor.configure_occurrence(occurrence, catalog, nav, hero)
		actor.position = Vector2(240, 200)
		root.add_child(actor)
		actor.set_process(false)
		var emitted: Array[DamageRequest] = []
		actor.mob_skill_requested.connect(func(request: DamageRequest, _target: CombatActor, _speed: float, _range: float) -> void: emitted.append(request.copy()))
		var sp := actor._mob_sp
		_check(actor._try_declared_skill(), "mob prepares real declared class skill")
		var rank := ClassCatalog.skill_definition(skill).rank_definition(3)
		_check(actor._mob_sp == sp and emitted.is_empty(), "preparation does not spend or emit")
		actor._advance_mob_cast(10.0)
		_check(emitted.size() == 1 and emitted[0].skill_id == skill and emitted[0].magic_damage == actor.stat_breakdown.value(&"magic_attack") * rank.power, "mob emits actual canonical rank power")
		_check(actor._mob_sp == sp - rank.sp_cost and actor._mob_cooldowns[skill] == StatCalculator.effective_cooldown(rank.cooldown, actor.stat_breakdown), "one canonical SP cost and cooldown")
		_check(not actor._try_declared_skill(), "shared cooldown prevents repeat launch")
		var cast := emitted[0].copy()
		actor._mob_definition.fixed_level = 30
		_check(cast.magic_damage == emitted[0].magic_damage and catalog.get_definition(definition.id).fixed_level == 7, "emission and catalog preserved against runtime changes")
		actor._mob_cooldowns[skill] = 0.0
		actor._mob_sp = sp
		actor._try_declared_skill()
		actor.apply_stun(1.0)
		actor._advance_mob_cast(10.0)
		_check(emitted.size() == 1 and actor._mob_sp == sp, "stun cancels unlaunched preparation without payment")
		actor.free()
	var invalid := MobDefinition.new()
	invalid.id = &"invalid_kit"
	for axis: StringName in StatCalculator.PRIMARY_IDS: invalid.primary_attributes[axis] = 3
	invalid.skill_ids = [&"sentinel_headshot"]
	invalid.skill_ranks = {&"sentinel_headshot": 1}
	_check(catalog.register_definition(invalid)["error_code"] == &"invalid_mob_skill", "metadata cannot grant an unimplemented mob kit")
	hero.free()
	print("E06 TX3 mobs: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
