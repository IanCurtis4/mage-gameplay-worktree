extends SceneTree
## H3 directed runtime transactions. AI disabled: not a solo/DPS/FPS claim.

var checks := 0
var failures := 0

class HunterInputController extends RunController:
	# Deterministic pointer boundary; real intent/input/dispatch/cast remain used.
	func _world_mouse_point() -> Vector2:
		return Vector2(410, 300)
	func _world_pointer_available() -> bool:
		return true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_math_snapshots()
	await _casts_and_geometry()
	await _input_modes()
	await _controls_and_bleed()
	await _tar_and_reaction()
	await _lifecycle_and_fifo()
	await _destructive_callback()
	await _field_clocks()
	await _freed_tar_occupants()
	print("Hunter H3 traps integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build() -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "hunter-h3-directed"
	build.base_class_id = &"archer"
	build.evolution_id = &"hunter"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 20, &"dex": 10}
	build.skill_ranks = {&"hunter_freezing_trap": 1, &"hunter_tar_trap": 1, &"hunter_thorn_trap": 1, &"snare_trap": 1, &"explosive_trap": 1}
	return build

func _controller(input_fixture: bool = false) -> RunController:
	RunController.pending_run_state = RunState.from_build("", _build())
	RunController.pending_run_facade = null
	RunController.pending_training_mode = false
	var controller: RunController = HunterInputController.new() if input_fixture else RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
	controller.player.global_position = Vector2(300, 300)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1400, 900)
		enemy.clear_statuses()
		enemy.health.max_hp = 10000.0
		enemy.health.current_hp = 10000.0
	return controller

func _place(controller: RunController, skill_id: StringName, point: Vector2) -> HunterTrap:
	controller.player.mage_cooldowns[skill_id] = 0.0
	controller.player.current_sp = controller.player.max_sp
	_check(controller.player.use_hunter_trap(skill_id, point), "paid placement " + String(skill_id))
	var traps := controller.trap_registry.active_traps()
	var trap := traps[-1] as HunterTrap
	trap.set_process(false)
	return trap

func _math_snapshots() -> void:
	for rank: int in range(1, 6):
		for skill_id: StringName in HunterMath.NEW_TRAP_IDS:
			var stats := StatCalculator.calculate({&"int": 20, &"dex": 5})
			var alternate := StatCalculator.calculate({&"int": 20, &"dex": 55, &"str": 55, &"luk": 55})
			var request := HunterMath.trap_request(1, skill_id, rank, stats, 1.2)
			var second := HunterMath.trap_request(1, skill_id, rank, alternate, 1.2)
			_check(request.physical_damage == second.physical_damage and request.magic_damage == second.magic_damage, "trap raw ignores precision/STR/LUK")
			_check(request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not request.can_crit and not request.is_secondary and request.damage_dealt_multiplier == 1.2, "primary captured request channels")
			var tuning := HunterTuning.values(skill_id, rank)
			var raw := (float(tuning.get("base", 0.0)) + float(tuning.get("int_coefficient", 0.0)) * stats.primary_value(&"int")) * float(tuning.get("rank_factor", 1.0))
			_check(is_equal_approx(request.magic_damage + request.physical_damage, raw), "catalog coefficients match raw snapshot")
			_check((request.magic_damage > 0.0) == (skill_id == &"hunter_freezing_trap"), "only freezing uses magic channel")
			_check(HunterMath.trap_request(1, skill_id, 0, stats, 1.0) == null and HunterMath.trap_request(1, skill_id, 6, stats, 1.0) == null, "illegal ranks cannot emit")

func _casts_and_geometry() -> void:
	var controller := _controller()
	var player := controller.player
	var point := Vector2(410, 300)
	for skill_id: StringName in HunterMath.NEW_TRAP_IDS:
		var sp := player.current_sp
		controller._commit_skill(skill_id, point)
		_check(player.has_active_cast() and player.current_sp == sp and controller.trap_registry.active_count() == 0, "preparation has no cost or trap")
		player.cancel_active_cast()
		_check(player.current_sp == sp and player.skill_cooldown(skill_id) == 0.0, "cancel has no cost")
		controller._commit_skill(skill_id, point)
		controller.navigation.configure(Rect2(0, 0, 1600, 1000), [Rect2(345, 240, 30, 100)], 20.0)
		player._advance_active_cast(10.0)
		_check(player.current_sp == sp and controller.trap_registry.active_count() == 0 and player.skill_cooldown(skill_id) == 0.0, "new obstruction before release rejects atomically")
		_check(not player.begin_skill_cast(skill_id, point) and not player.use_hunter_trap(skill_id, Vector2(NAN, 0)), "invalid start/point rejects")
		controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
		controller._commit_skill(skill_id, point)
		player._advance_active_cast(10.0)
		_check(controller.trap_registry.active_count() == 1 and player.current_sp == sp - player.skill_cost(skill_id), "release places and charges once")
		_check(not player.use_hunter_trap(skill_id, point) and controller.trap_registry.active_count() == 1, "cooldown rejects duplicate commit")
		controller.battle_indicators.show_aim(skill_id, player, Vector2(1200, 300), true)
		_check(controller.battle_indicators.endpoint == player.trap_center(skill_id, Vector2(1200, 300)) and is_equal_approx(player.global_position.distance_to(controller.battle_indicators.endpoint), 360.0), "preview shares clamped placement")
		controller.trap_registry.clear_all()
		player.mage_cooldowns[skill_id] = 0.0
		paused = true
		_check(not player.use_hunter_trap(skill_id, point), "paused actor cannot pay")
		paused = false
	controller.queue_free()
	await process_frame

func _input_modes() -> void:
	for mode: CastIntent.Mode in [CastIntent.Mode.CONFIRM, CastIntent.Mode.RELEASE, CastIntent.Mode.INSTANT]:
		for skill_id: StringName in HunterMath.NEW_TRAP_IDS:
			var controller := _controller(true)
			controller.control_preferences = ControlPreferences.new()
			controller.action_slots.fill(null)
			controller.action_slots[0] = skill_id
			controller.cast_intent.set_mode(mode)
			var player := controller.player
			var sp := player.current_sp
			var key := InputEventKey.new()
			key.keycode = KEY_1
			key.physical_keycode = KEY_1
			key.pressed = true
			controller._unhandled_input(key)
			_check(player.has_active_cast() == (mode == CastIntent.Mode.INSTANT) and player.current_sp == sp, "mode starts intent/preparation without charge")
			if mode == CastIntent.Mode.CONFIRM:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				click.position = controller.get_canvas_transform() * Vector2(410, 300)
				controller._unhandled_input(click)
			elif mode == CastIntent.Mode.RELEASE:
				key.pressed = false
				controller._input(key)
			_check(player.has_active_cast(), "all modes route through variable preparation")
			player._advance_active_cast(10.0)
			key.pressed = false
			controller._input(key)
			_check(controller.trap_registry.active_count() == 1 and player.current_sp == sp - player.skill_cost(skill_id), "all modes commit exactly once; later release cannot repeat")
			controller.queue_free()
			await process_frame

func _controls_and_bleed() -> void:
	var controller := _controller()
	var player := controller.player
	var victim := controller.enemies[0]
	var other := controller.enemies[1]
	var point := Vector2(410, 300)
	victim.global_position = point
	other.global_position = point + Vector2(20, 0)
	victim.configure_hard_control_profile(true)
	victim.set_unstoppable(10.0)
	var trap := _place(controller, &"hunter_freezing_trap", point)
	var raw_at_placement := trap.damage_request.magic_damage
	var bonus_at_placement := trap.opening_request.physical_damage
	player.stat_breakdown = StatCalculator.calculate({&"int": 50, &"dex": 10})
	trap._process(0.59)
	_check(victim.health.current_hp == 10000.0 and player.hunter_state.opening(victim.get_instance_id()).is_empty(), "stationary victim waits for arming")
	paused = true
	trap._process(2.0)
	_check(trap.state == PlayerTrap.State.ARMING and victim.health.current_hp == 10000.0, "pause freezes arming and trigger")
	paused = false
	trap._process(0.02)
	_check(trap.damage_request.magic_damage == raw_at_placement and (player.hunter_state.opening(victim.get_instance_id())["request"] as DamageRequest).physical_damage == bonus_at_placement, "INT changes after placement do not recapture trap/reward")
	_check(not victim.is_rooted() and victim.health.current_hp < 10000.0 and not player.hunter_state.opening(victim.get_instance_id()).is_empty(), "resisted magic root still damages and opens stationary boss")
	_check(other.health.current_hp == 10000.0 and player.hunter_state.opening(other.get_instance_id()).is_empty(), "freezing has a single primary prey")
	trap = _place(controller, &"hunter_thorn_trap", point)
	var snapshot_raw := trap.damage_request.physical_damage
	trap._process(0.61)
	var key := "%d:hunter_thorn_bleed" % player.get_instance_id()
	_check(victim.bleed_streams.size() == 1 and other.bleed_streams.size() == 1 and victim.slow_fraction == 0.2, "thorn applies bounded area bleed and slow")
	var bleed: DamageRequest = victim.bleed_streams[key]["request"]
	_check(is_equal_approx(bleed.physical_damage, snapshot_raw * 0.2) and bleed.is_secondary and not bleed.can_crit and bleed.magic_damage == 0.0, "bleed captures twenty percent raw and secondary channel")
	var window := player.hunter_state.opening(victim.get_instance_id())
	var hp := victim.health.current_hp
	victim.advance_statuses(1.0)
	var after_bleed := player.hunter_state.opening(victim.get_instance_id())
	_check(victim.health.current_hp < hp and after_bleed["remaining"] == window["remaining"] and after_bleed["activation_id"] == window["activation_id"] and player.hunter_state.step_remaining == 0.0, "bleed does not consume or renew opening")
	trap = _place(controller, &"hunter_thorn_trap", point)
	trap._process(0.61)
	_check(victim.bleed_streams.size() == 1 and float(victim.bleed_streams[key]["remaining"]) == 4.0, "same owner bleed refreshes rather than stacks")
	var blocked := controller._spawn_enemy(&"chaser", point + Vector2(60, 0))
	blocked.set_process(false)
	blocked.health.max_hp = 10000.0
	blocked.health.current_hp = 10000.0
	blocked.global_position = point + Vector2(60, 0)
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [Rect2(440, 260, 15, 80)], 20.0)
	trap = _place(controller, &"hunter_thorn_trap", point)
	trap._process(0.61)
	_check(blocked.health.current_hp == 10000.0 and blocked.bleed_streams.is_empty() and player.hunter_state.opening(blocked.get_instance_id()).is_empty(), "each area victim independently respects LoS")
	controller._show_result(false)
	_check(victim.bleed_streams.is_empty() and victim.slow_fraction == 0.0, "run end synchronously removes thorn streams/source")
	paused = false
	controller.queue_free()
	await process_frame

func _tar_and_reaction() -> void:
	var controller := _controller()
	var player := controller.player
	var point := Vector2(410, 300)
	var first := controller.enemies[0]
	var second := controller.enemies[1]
	first.global_position = point
	second.global_position = point + Vector2(60, 0)
	var trap := _place(controller, &"hunter_tar_trap", point)
	trap._process(0.61)
	var field := controller.hunter_tar_field
	field.set_process(false)
	_check(first.health.current_hp == 10000.0 and first.slow_fraction == 0.3 and second.slow_fraction == 0.3, "tar slows initial area without damage")
	_check(not player.hunter_state.opening(first.get_instance_id()).is_empty() and not player.hunter_state.opening(second.get_instance_id()).is_empty(), "initial tar occupants open exactly at primary activation")
	player.clear_hunter_state()
	first.global_position += Vector2(200, 0)
	first.advance_statuses(0.4)
	_check(first.slow_fraction == 0.0, "leaving tar expires short residual")
	first.global_position = point
	field.refresh_occupants()
	_check(first.slow_fraction == 0.3 and player.hunter_state.opening(first.get_instance_id()).is_empty(), "reentry slows without opening refresh")
	var late := CombatActor.new()
	late.setup("Tardia", Color.WHITE, StatCalculator.calculate({}), 18.0)
	late.global_position = point
	root.add_child(late)
	late.set_process(false)
	field.track_target(late)
	field.refresh_occupants()
	_check(late.slow_fraction == 0.3 and player.hunter_state.opening(late.get_instance_id()).is_empty(), "late tracked occupant only receives slow")
	first.apply_slow(0.1, 10.0, &"other_control")
	field._process(2.0)
	var expected_bonus := 0.125
	var requests: Array[DamageRequest] = []
	var removed_before_damage: Array[bool] = []
	for victim: CombatActor in [first, second]:
		victim.health.damage_applied.connect(func(_result: Dictionary) -> void: removed_before_damage.append(not field.active and first.slow_fraction == 0.1 and second.slow_fraction == 0.0))
	_check(player.use_explosive_trap(point), "paid base explosive is usable")
	var explosive := controller.trap_registry.active_traps()[0] as ExplosiveTrap
	explosive.set_process(false)
	explosive.hit.connect(func(request: DamageRequest, _victim: CombatActor) -> void: requests.append(request.copy()))
	var baseline := explosive.damage_request.physical_damage
	explosive._process(0.75)
	_check(requests.size() == 2 and removed_before_damage == [true, true], "tar is consumed and own slow removed before every area hit")
	for request: DamageRequest in requests:
		_check(is_equal_approx(request.physical_damage, baseline * (1.0 + expected_bonus)), "same remaining-fraction bonus for every victim")
	_check(is_equal_approx(explosive.damage_request.physical_damage, baseline), "reaction cannot mutate captured request")
	_check(controller._consume_hunter_tar(point, 105.0) == 0.0 and late.slow_fraction == 0.0, "reaction cannot be paid twice and cleans late occupant")
	var opening := player.hunter_state.opening(first.get_instance_id())
	_check(not opening.is_empty() and is_equal_approx((opening["request"] as DamageRequest).physical_damage, player.hunter_opening_snapshot(&"explosive_trap").physical_damage), "primary explosion opens without reaction boosting opening reward")
	late.queue_free()
	controller.queue_free()
	await process_frame

func _lifecycle_and_fifo() -> void:
	var controller := _controller()
	var player := controller.player
	var victim := controller.enemies[0]
	var point := Vector2(410, 300)
	victim.global_position = point
	var old_trap := _place(controller, &"hunter_tar_trap", point)
	_place(controller, &"hunter_freezing_trap", point)
	_place(controller, &"hunter_thorn_trap", point)
	_place(controller, &"hunter_tar_trap", point)
	_check(controller.trap_registry.active_count() == 3 and old_trap.state == PlayerTrap.State.EXPIRED and controller.hunter_tar_field == null, "fourth mechanism replaces FIFO without activating field")
	controller.trap_registry.clear_all()
	var trap := _place(controller, &"hunter_tar_trap", point)
	trap._process(0.61)
	var old_field := controller.hunter_tar_field
	old_field.set_process(false)
	trap = _place(controller, &"hunter_tar_trap", point)
	trap._process(0.61)
	var field := controller.hunter_tar_field
	field.set_process(false)
	_check(not old_field.active and field.active and old_field.source_id == field.source_id and victim.attribute_debuffs.remaining(AttributeDebuffState.MOVE_SPEED, field.source_id) == 0.4, "replacement removes old instance before applying one owner source")
	_check(controller.trap_registry.active_count() == 0, "triggered fields do not use mechanism cap")
	paused = true
	field._process(20.0)
	_check(field.remaining == 4.0 and field.consume_for_explosion(point, 105.0, controller.navigation) == 0.0, "pause prevents field timer/reaction")
	paused = false
	_check(field.consume_for_explosion(Vector2(900, 900), 105.0, controller.navigation) == 0.0 and field.active, "remote blast cannot consume field")
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [Rect2(440, 260, 15, 80)], 20.0)
	_check(field.consume_for_explosion(point + Vector2(100, 0), 105.0, controller.navigation) == 0.0 and field.active, "obstruction separates even overlapping fields")
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
	var prior_activation: int = player.hunter_state.opening(victim.get_instance_id())["activation_id"]
	var untouched := _place(controller, &"hunter_freezing_trap", point + Vector2(250, 150))
	untouched._process(0.61)
	untouched._process(20.0)
	_check(untouched.state == PlayerTrap.State.EXPIRED and player.hunter_state.opening(victim.get_instance_id())["activation_id"] == prior_activation, "duration expiration does not synthesize activation")
	var lethal := DamageRequest.new()
	lethal.source_id = victim.get_instance_id()
	lethal.target_id = player.get_instance_id()
	lethal.physical_damage = 100000.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	lethal.can_crit = false
	player.health.apply(lethal, 0.0, 1.0)
	_check(not field.active and victim.slow_fraction == 0.0 and controller.hunter_tar_field == null and controller.trap_registry.active_count() == 0, "owner death removes fields and source before result pause")
	paused = false
	controller.queue_free()
	await process_frame

func _destructive_callback() -> void:
	var controller := _controller()
	var first := controller.enemies[0]
	var second := controller.enemies[1]
	var point := Vector2(410, 300)
	first.global_position = point
	second.global_position = point
	# Ensure first is the deterministic earlier instance, independent of roster order.
	if first.get_instance_id() > second.get_instance_id():
		var swap := first
		first = second
		second = swap
	first.health.damage_applied.connect(func(_result: Dictionary) -> void: second.free())
	var trap := _place(controller, &"hunter_thorn_trap", point)
	trap._process(0.61)
	_check(first.health.current_hp < 10000.0 and not is_instance_valid(second), "thorn revalidates victims freed by earlier callback")
	for index: int in range(controller.enemies.size() - 1, -1, -1):
		if not is_instance_valid(controller.enemies[index]):
			controller.enemies.remove_at(index)
	controller.queue_free()
	await process_frame

func _field_clocks() -> void:
	for hz: int in [30, 60, 144]:
		var controller := _controller()
		var victim := controller.enemies[0]
		var point := Vector2(410, 300)
		victim.global_position = point
		var trap := _place(controller, &"hunter_tar_trap", point)
		trap._process(0.61)
		var field := controller.hunter_tar_field
		field.set_process(false)
		for frame: int in range(hz * 2):
			victim.advance_statuses(1.0 / hz)
			field._process(1.0 / hz)
		_check(is_equal_approx(field.remaining, 2.0) and is_equal_approx(field.consume_for_explosion(point, 105.0, controller.navigation), 0.125), "deterministic timer/reaction at %dHz" % hz)
		controller.queue_free()
		await process_frame
	# Natural field expiry keeps a short residue, but terminal cleanup must still
	# remove it after the field has disappeared (including while result pauses).
	var controller := _controller()
	var point := Vector2(410, 300)
	var victim := controller.enemies[0]
	victim.global_position = point
	var trap := _place(controller, &"hunter_tar_trap", point)
	trap._process(0.61)
	var field := controller.hunter_tar_field
	field.set_process(false)
	field._process(4.0)
	_check(not field.active and victim.slow_fraction == 0.3, "normal field expiry retains only short residue")
	await process_frame
	_check(not is_instance_valid(field), "normal expired field is actually freed")
	controller._show_result(false)
	_check(victim.slow_fraction == 0.0, "terminal cleanup removes residue even without a field node")
	paused = false
	controller.queue_free()
	await process_frame

func _freed_tar_occupants() -> void:
	var controller := _controller()
	var point := Vector2(410, 300)
	var first := controller.enemies[0]
	var second := controller.enemies[1]
	first.global_position = point
	second.global_position = point
	var trap := _place(controller, &"hunter_tar_trap", point)
	trap._process(0.61)
	var field := controller.hunter_tar_field
	field.set_process(false)
	controller.enemies.erase(first)
	first.free()
	field._process(0.1)
	_check(field.active and field._targets.size() == 1 and second.slow_fraction == 0.3, "freed Tar occupant is pruned before typed iteration while surviving prey remains slowed")
	controller.enemies.erase(second)
	second.free()
	field.expire()
	_check(not field.active, "Tar cleanup skips freed occupants without assigning stale typed references")
	# An armed area mechanism also keeps snapshots after prey removal.
	var removed := CombatActor.new()
	removed.setup("Removida", Color.WHITE, StatCalculator.calculate({}))
	removed.position = point
	root.add_child(removed)
	var survivor := controller._spawn_enemy(&"chaser", point)
	survivor.set_process(false)
	trap = _place(controller, &"hunter_thorn_trap", point)
	trap.track_target(removed)
	removed.free()
	trap._process(0.61)
	_check(survivor.health.current_hp < survivor.health.max_hp, "area activation skips stale references and hits a live prey")
	controller.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
