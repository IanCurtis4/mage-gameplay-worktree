extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1400, 1000), [], 0)
	var hero := PlayerActor.new()
	hero.configure(nav, RunState.new(&"mage"))
	hero.position = Vector2(300, 300)
	root.add_child(hero)
	hero.set_process(false)
	var catalog := MobCatalog.new()
	var definition := MobDefinition.new()
	definition.id = &"rx_spear_archer"
	definition.archetype = &"archer"
	definition.animation_kind = &"archer"
	definition.skill_ids = [&"fire_spear"]
	definition.skill_ranks = {&"fire_spear": 1}
	for axis: StringName in StatCalculator.PRIMARY_IDS:
		definition.primary_attributes[axis] = 3
	_check(catalog.register_definition(definition)["ok"], "legal archer species with supported spear")
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "rx_spear_archer_1"
	occurrence.mob_base_id = definition.id
	occurrence.category_id = &"normal"
	occurrence.origin_id = &"rx_arena"
	var actor := EnemyActor.new()
	_check(actor.configure_occurrence(occurrence, catalog, nav, hero)["ok"], "configure legal occurrence")
	var rank := ClassCatalog.skill_definition(&"fire_spear").rank_definition(1)
	var distance := (rank.range + 390.0) / 2.0
	actor.position = hero.position + Vector2(distance, 0)
	root.add_child(actor)
	actor.set_process(false)
	var emissions: Array[DamageRequest] = []
	actor.mob_skill_requested.connect(func(request: DamageRequest, _target: CombatActor, _speed: float, _range: float) -> void: emissions.append(request.copy()))
	var original := actor.position
	for frame: int in 300:
		actor._process(1.0 / 60.0)
	print("RX REPRO mob AI: distance=", distance, " skill_range=", rank.range, " move_distance=", original.distance_to(actor.position), " emissions=", emissions.size())
	_check(not emissions.is_empty() or actor.position.distance_to(hero.position) < distance - 1.0, "normal AI approaches actual spell range or emits instead of freezing inside old bow range")
	actor.position = hero.position + Vector2(rank.range - 20.0, 0)
	for frame: int in 120:
		actor._process(1.0 / 60.0)
	_check(not emissions.is_empty(), "same species emits through normal process once placed inside spell range")
	actor.free()
	hero.free()
	print("E06 RX mob AI boundary: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
