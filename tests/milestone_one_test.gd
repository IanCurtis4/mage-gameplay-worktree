extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_test_health_application()
	_test_augment_flow()
	_test_navigation()
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
	_check(path.size() > 2, "navigation produces a route around an obstacle")
	var clear := true
	for point: Vector2 in path:
		clear = clear and navigation.is_walkable(point)
	_check(clear, "every path point lies in a walkable region")
	var dash_end := navigation.move_until_blocked(Vector2(48, 100), Vector2(280, 100))
	_check(dash_end.x < obstacle.position.x - 15.0, "dash stops before inflated obstacle")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
