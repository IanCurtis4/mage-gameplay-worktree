extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_test_health_application()
	_test_augment_flow()
	_test_navigation()
	_test_resource_recalculation()
	_test_projectiles()
	_test_fluid_movement()
	_test_basic_attack_tolerance()
	print("Marco 1: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_health_application() -> void:
	var health := HealthState.new(22, 50.0, 0.0)
	var death_count := [0]
	health.actor_died.connect(func(_id: int) -> void: death_count[0] += 1)
	var request := DamageRequest.new()
	request.source_id = 10
	request.target_id = 22
	request.base_damage = 80.0
	request.hit_chance = 1.0
	request.can_crit = false
	var result := health.apply(request, 0.0, 0.0)
	_check(result["actual_damage"] == 50 and result["killed"], "lethal damage is capped to remaining HP")
	_check(death_count[0] == 1, "death is emitted once")
	_check(health.apply(request, 0.0, 0.0).is_empty() and death_count[0] == 1, "dead target rejects repeated application")
	health.reset(100.0, 10.0)
	_check(health.is_alive() and health.current_hp == 100.0 and death_count[0] == 1, "health reset restores state without emitting death")
	health.current_hp = 60.0
	health.set_max_preserving_missing(150.0)
	_check(health.current_hp == 110.0, "maximum HP changes preserve missing HP")
	health.reset(10.0, 0.0)
	health.current_hp = 0.4
	var fractional := health.apply(request, 0.0, 0.0)
	_check(is_equal_approx(fractional["actual_damage"], 0.4) and fractional["killed"], "fractional remaining HP cannot make a target immortal")
	_check(death_count[0] == 2, "fractional lethal damage emits one new death after reset")

func _test_augment_flow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var state := RunState.new()
	state.queue_choice()
	_check(not state.can_open_choice(true), "choice cannot open during encounter")
	_check(state.build_offer(true, rng).is_empty(), "offer is blocked during encounter")
	var offer := state.build_offer(false, rng)
	_check(offer.size() == 3, "three distinct eligible augments are offered")
	var ids: Dictionary[StringName, bool] = {}
	for definition: AugmentDefinition in offer:
		ids[definition.id] = true
	_check(ids.size() == offer.size(), "offer has no replacement")
	var stable := state.build_offer(false, rng)
	_check(stable[0].id == offer[0].id and stable[1].id == offer[1].id and stable[2].id == offer[2].id, "offer remains stable until confirmation")
	var chosen_id: StringName = offer[0].id
	_check(state.confirm(chosen_id, false), "eligible choice confirms")
	_check(state.pending_choices == 0 and state.augment_stacks[chosen_id] == 1, "confirmation consumes exactly one pending choice")
	_check(not state.confirm(chosen_id, false), "same offer cannot confirm twice")
	for expected_stack: int in [2, 3]:
		state.queue_choice()
		var next_offer := state.build_offer(false, rng)
		var selected: AugmentDefinition
		for definition: AugmentDefinition in next_offer:
			if definition.id == chosen_id:
				selected = definition
				break
		_check(selected != null and state.confirm(chosen_id, false), "numeric augment stacks to %d" % expected_stack)
	state.queue_choice()
	var capped_offer := state.build_offer(false, rng)
	var capped_present := false
	for definition: AugmentDefinition in capped_offer:
		capped_present = capped_present or definition.id == chosen_id
	_check(not capped_present, "augment is ineligible at maximum stacks")
	var fresh := RunState.new()
	_check(fresh.augment_stacks.is_empty() and fresh.pending_choices == 0, "new run has no leaked augment state")
	state.reset()
	_check(state.augment_stacks.is_empty() and state.current_offer.is_empty() and state.pending_choices == 0, "explicit reset clears all run state")
	var hp_state := RunState.new()
	hp_state.queue_choice()
	var hp_offer := hp_state.build_offer(false, rng)
	var hp_available := false
	for definition: AugmentDefinition in hp_offer:
		if definition.id == &"vitality":
			hp_available = hp_state.confirm(definition.id, false)
			break
	var hp_modifiers := hp_state.get_modifiers()
	_check(hp_available and is_equal_approx(hp_modifiers["increased"]["max_hp"], 0.20), "HP augment feeds shared stat modifiers")

func _test_navigation() -> void:
	var navigation := ArenaNavigation.new()
	var obstacle := Rect2(120, 60, 80, 100)
	navigation.configure(Rect2(0, 0, 320, 240), [obstacle], 16.0)
	_check(not navigation.is_walkable(Vector2(110, 100)), "navigation inflates obstacles by actor radius")
	var path := navigation.get_path(Vector2(48, 48), Vector2(272, 192))
	_check(not path.is_empty(), "navigation produces a route around an obstacle")
	_check(_path_is_densely_clear(navigation, Vector2(48, 48), path), "every path segment clears inflated geometry")
	var corner_path := navigation.get_path(Vector2(48, 48), Vector2(224, 176))
	_check(not corner_path.is_empty() and _path_is_densely_clear(navigation, Vector2(48, 48), corner_path), "route near obstacle corner does not cut diagonally")
	var inside_path := navigation.get_path(Vector2(48, 48), obstacle.get_center())
	_check(not inside_path.is_empty() and _path_is_densely_clear(navigation, Vector2(48, 48), inside_path) and navigation.is_walkable(inside_path[-1]), "click inside obstacle resolves to reachable safe point")
	var outside_path := navigation.get_path(Vector2(48, 48), Vector2(900, 900))
	_check(not outside_path.is_empty() and _path_is_densely_clear(navigation, Vector2(48, 48), outside_path) and navigation.is_walkable(outside_path[-1]), "click outside arena resolves inside walkable bounds")
	var reproduced_navigation := ArenaNavigation.new()
	reproduced_navigation.configure(RunController.ARENA_BOUNDS, RunController.ARENA_OBSTACLES, 22.0)
	_check(not reproduced_navigation.is_segment_walkable(Vector2(992, 544), Vector2(978.6676, 557.6087)), "reproduced corner-cut segment is rejected")
	var reproduced_target := Vector2(978.6676, 557.6087)
	var reproduced_path := reproduced_navigation.get_path(Vector2(900, 500), reproduced_target)
	_check(not reproduced_path.is_empty() and reproduced_path[-1].is_equal_approx(reproduced_target) and _path_is_densely_clear(reproduced_navigation, Vector2(900, 500), reproduced_path), "valid target near reproduced corner is reached without crossing obstacle")
	var dash_end := navigation.move_until_blocked(Vector2(48, 100), Vector2(280, 100))
	_check(dash_end.x < obstacle.position.x - 15.0, "dash stops before inflated obstacle")
	_check(navigation.is_segment_walkable(Vector2(48, 100), dash_end), "clamped dash segment remains fully walkable")

func _test_resource_recalculation() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 400, 300), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.new())
	root.add_child(player)
	player.health.current_hp = 140.0
	player.mana = 30.0
	var no_enemies: Array[CombatActor] = []
	var derived: Dictionary = player.stats.duplicate(true)
	derived["max_hp"] = 220.0
	derived["max_mana"] = 70.0
	player._apply_derived_stats(derived)
	_check(player.health.current_hp == 180.0, "player recalculation preserves missing HP")
	_check(player.mana == 50.0 and player.max_mana == 70.0, "player recalculation preserves missing mana")
	player.mana = 50.0
	for _cast: int in range(3):
		player.slash_cooldown = 0.0
		_check(player.use_slash(Vector2.RIGHT, no_enemies), "slash spends mana while available")
	player.slash_cooldown = 0.0
	_check(player.mana == 5.0 and not player.use_slash(Vector2.RIGHT, no_enemies), "slash blocks when mana is exhausted")
	player._process(2.0)
	player.slash_cooldown = 0.0
	_check(player.mana >= PlayerActor.SLASH_MANA_COST and player.use_slash(Vector2.RIGHT, no_enemies), "living player regenerates and can reuse blocked skill")
	player.mana = player.max_mana - 1.0
	player._process(10.0)
	_check(player.mana == player.max_mana, "mana regeneration clamps at maximum")
	player.mana = 0.0
	player._regenerate_mana(1.0, true)
	_check(player.mana == 0.0, "paused player does not regenerate mana")
	player.health.current_hp = 0.0
	player._regenerate_mana(1.0, false)
	_check(player.mana == 0.0, "dead player does not regenerate mana")
	player.queue_free()

func _test_projectiles() -> void:
	var open_navigation := ArenaNavigation.new()
	open_navigation.configure(Rect2(0, 0, 760, 320), [], 4.0)
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, RpgStats.derive({"vit": 1}))
	target.global_position = Vector2(250, 118)
	root.add_child(target)
	var request := DamageRequest.new()
	request.target_id = target.get_instance_id()
	request.base_damage = 10.0
	var hit_count := [0]
	var hit_projectile := ArrowProjectile.new()
	hit_projectile.configure(request, target, Vector2(40, 100), open_navigation)
	hit_projectile.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: hit_count[0] += 1)
	root.add_child(hit_projectile)
	hit_projectile._process(0.5)
	_check(hit_count[0] == 1 and hit_projectile.is_queued_for_deletion(), "fixed projectile hits a target crossing its segment")

	var dodge_projectile := ArrowProjectile.new()
	target.global_position = Vector2(250, 118)
	dodge_projectile.configure(request, target, Vector2(40, 100), open_navigation)
	dodge_projectile.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: hit_count[0] += 1)
	root.add_child(dodge_projectile)
	var fired_direction := dodge_projectile.direction
	target.global_position = Vector2(250, 250)
	dodge_projectile._process(0.5)
	_check(hit_count[0] == 1 and dodge_projectile.direction == fired_direction, "moving target can dodge and projectile does not home")
	dodge_projectile._process(2.0)
	_check(dodge_projectile.is_queued_for_deletion(), "missed projectile expires at arena geometry or range")

	var blocked_navigation := ArenaNavigation.new()
	blocked_navigation.configure(Rect2(0, 0, 420, 260), [Rect2(120, 60, 80, 100)], 4.0)
	target.global_position = Vector2(300, 118)
	var blocked_projectile := ArrowProjectile.new()
	blocked_projectile.configure(request, target, Vector2(40, 100), blocked_navigation)
	blocked_projectile.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: hit_count[0] += 1)
	root.add_child(blocked_projectile)
	blocked_projectile._process(0.5)
	_check(hit_count[0] == 1 and blocked_projectile.is_queued_for_deletion(), "obstacle blocks projectile before target")
	target.queue_free()

func _test_fluid_movement() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(RunController.ARENA_BOUNDS, RunController.ARENA_OBSTACLES, 22.0)
	var open_start := Vector2(300, 520)
	var open_target := Vector2(500, 610)
	var direct_path := navigation.get_path(open_start, open_target)
	_check(direct_path.size() == 1 and direct_path[0].is_equal_approx(open_target), "open segment uses real destination without grid detour")
	var detour_path := navigation.get_path(Vector2(500, 300), Vector2(900, 350))
	_check(not detour_path.is_empty() and detour_path[-1].is_equal_approx(Vector2(900, 350)) and _path_is_densely_clear(navigation, Vector2(500, 300), detour_path), "simplified detour reaches real destination with clear segments")

	var open_navigation := ArenaNavigation.new()
	open_navigation.configure(Rect2(0, 0, 700, 300), [], 20.0)
	var fine_player := PlayerActor.new()
	fine_player.configure(open_navigation, RunState.new())
	fine_player.global_position = Vector2(80, 100)
	root.add_child(fine_player)
	fine_player.move_to(Vector2(500, 100))
	for _step: int in range(10):
		fine_player._process(0.1)
	var coarse_player := PlayerActor.new()
	coarse_player.configure(open_navigation, RunState.new())
	coarse_player.global_position = Vector2(80, 100)
	root.add_child(coarse_player)
	coarse_player.move_to(Vector2(500, 100))
	coarse_player._process(1.0)
	_check(fine_player.global_position.is_equal_approx(coarse_player.global_position), "player movement consumes distance uniformly across delta sizes")

	var moving_target := CombatActor.new()
	moving_target.setup("Alvo móvel", Color.WHITE, RpgStats.derive({"vit": 1}), 19.0)
	moving_target.global_position = Vector2(420, 100)
	root.add_child(moving_target)
	fine_player.global_position = Vector2(80, 100)
	fine_player.pursue(moving_target)
	fine_player._process(0.1)
	moving_target.global_position = Vector2(420, 170)
	var before_replan := fine_player.global_position.distance_to(moving_target.global_position)
	fine_player._repath_time = 0.0
	fine_player._process(0.1)
	_check(fine_player.global_position.distance_to(moving_target.global_position) < before_replan, "moving-target replan advances without returning to grid center")
	fine_player.global_position = Vector2(200, 100)
	moving_target.global_position = Vector2(295, 100)
	fine_player.pursue(moving_target)
	fine_player._process(0.1)
	_check(fine_player.global_position.x > 200.0 and fine_player.can_basic_attack(moving_target), "pursuit closes final 6 px instead of discarding short waypoint")
	fine_player.move_to(fine_player.global_position + Vector2(5, 0))
	var before_short_click := fine_player.global_position
	# A short command must arrive, allowing the newly requested acceleration/brake.
	fine_player._process(0.5)
	_check(fine_player.global_position.distance_to(before_short_click) >= 4.9, "valid 5 px ground click is not discarded")

	var enemy_fine := EnemyActor.new()
	enemy_fine.configure(&"chaser", open_navigation, fine_player)
	enemy_fine.global_position = Vector2(80, 220)
	root.add_child(enemy_fine)
	enemy_fine._path = open_navigation.get_path(enemy_fine.global_position, Vector2(500, 220))
	for _step: int in range(10):
		enemy_fine._move_along_path(0.1)
	var enemy_coarse := EnemyActor.new()
	enemy_coarse.configure(&"chaser", open_navigation, fine_player)
	enemy_coarse.global_position = Vector2(80, 220)
	root.add_child(enemy_coarse)
	enemy_coarse._path = open_navigation.get_path(enemy_coarse.global_position, Vector2(500, 220))
	enemy_coarse._move_along_path(1.0)
	_check(enemy_fine.global_position.is_equal_approx(enemy_coarse.global_position), "enemy movement also consumes distance uniformly across delta sizes")

	var precision_navigation := ArenaNavigation.new()
	precision_navigation.configure(Rect2(0, 0, 1600, 400), [], 20.0)
	var precision_target := Vector2(1480, 100)
	for fps: int in [30, 60, 144]:
		var precision_player := PlayerActor.new()
		precision_player.configure(precision_navigation, RunState.new())
		precision_player.global_position = Vector2(512, 100)
		root.add_child(precision_player)
		precision_player.move_to(precision_target)
		for _frame: int in range(fps * 6):
			precision_player._process(1.0 / float(fps))
		_check(precision_player.global_position.distance_to(precision_target) < 0.02, "player crosses precision plateaus and reaches target at %d Hz" % fps)
		precision_player.queue_free()

		var precision_enemy := EnemyActor.new()
		precision_enemy.configure(&"chaser", precision_navigation, fine_player)
		precision_enemy.global_position = Vector2(512, 220)
		root.add_child(precision_enemy)
		var enemy_target := Vector2(1480, 220)
		precision_enemy._path = precision_navigation.get_path(precision_enemy.global_position, enemy_target)
		for _frame: int in range(fps * 6):
			precision_enemy._move_along_path(1.0 / float(fps))
		_check(precision_enemy.global_position.distance_to(enemy_target) < 0.02, "enemy crosses precision plateaus and reaches target at %d Hz" % fps)
		precision_enemy.queue_free()
	fine_player.queue_free()
	coarse_player.queue_free()
	moving_target.queue_free()
	enemy_fine.queue_free()
	enemy_coarse.queue_free()

func _test_basic_attack_tolerance() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 400, 260), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.new())
	player.global_position = Vector2(80, 100)
	root.add_child(player)
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, RpgStats.derive({"vit": 1}), 19.0)
	enemy.global_position = Vector2(169, 100)
	root.add_child(enemy)
	_check(is_equal_approx(player.basic_attack_distance(enemy), 89.0) and player.can_basic_attack(enemy), "basic attack reaches 50 px beyond actor edges")
	enemy.global_position.x = 170.0
	_check(not player.can_basic_attack(enemy), "basic attack rejects target just outside initial edge range")
	enemy.global_position.x = 185.0
	_check(player.can_basic_attack(enemy, true), "retention band keeps engaged target without oscillation")
	enemy.global_position.x = 186.0
	_check(not player.can_basic_attack(enemy, true), "retention band remains finite")

	var blocked_navigation := ArenaNavigation.new()
	blocked_navigation.configure(Rect2(0, 0, 400, 260), [Rect2(130, 60, 20, 100)], 20.0)
	var blocked_player := PlayerActor.new()
	blocked_player.configure(blocked_navigation, RunState.new())
	blocked_player.global_position = Vector2(80, 100)
	root.add_child(blocked_player)
	enemy.global_position = Vector2(160, 100)
	_check(not blocked_player.can_basic_attack(enemy), "basic attack cannot pass through obstacle")
	player.queue_free()
	blocked_player.queue_free()
	enemy.queue_free()

func _path_is_densely_clear(navigation: ArenaNavigation, start: Vector2, path: PackedVector2Array) -> bool:
	var previous := start
	for point: Vector2 in path:
		if not navigation.is_segment_walkable(previous, point):
			return false
		var distance := previous.distance_to(point)
		var samples := maxi(1, ceili(distance / 2.0))
		for sample: int in range(samples + 1):
			if not navigation.is_walkable(previous.lerp(point, float(sample) / float(samples))):
				return false
		previous = point
	return true

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
