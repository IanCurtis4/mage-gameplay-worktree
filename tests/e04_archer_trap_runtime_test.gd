extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await _check_lifecycle_and_pause()
	await _check_registry_cap_and_cleanup()
	await _check_controller_cleanup()
	print("E04 runtime de armadilhas: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_lifecycle_and_pause() -> void:
	var trap := _trap(101, &"snare_trap", Vector2(300, 200), 40.0, 0.5, 1.0)
	root.add_child(trap)
	var target := _target(Vector2(400, 200))
	var events := {"armed": 0, "triggered": 0, "expired": 0}
	var removed_reasons: Array[StringName] = []
	trap.armed.connect(func(_value: PlayerTrap) -> void: events["armed"] += 1)
	trap.triggered.connect(func(_value: PlayerTrap, _target_value: CombatActor) -> void: events["triggered"] += 1)
	trap.expired.connect(func(_value: PlayerTrap, _reason: StringName) -> void: events["expired"] += 1)
	trap.removed.connect(func(_value: PlayerTrap, reason: StringName) -> void: removed_reasons.append(reason))
	_check(trap.owner_id == 101 and trap.source_skill_id == &"snare_trap" and trap.global_position == Vector2(300, 200), "trap captures owner, source skill and fixed placement")
	_check(trap.radius == 40.0 and trap.arming_duration == 0.5 and trap.armed_duration == 1.0, "trap captures radius, arming time and armed permanence")
	_check(trap.state == PlayerTrap.State.ARMING and trap.is_active() and trap.process_mode == Node.PROCESS_MODE_PAUSABLE, "configured delayed trap starts active in ARMING with pausable processing")
	trap._process(0.3)
	_check(trap.state == PlayerTrap.State.ARMING and is_equal_approx(trap.arming_remaining, 0.2) and trap.lifetime_remaining == 1.0, "arming advances without consuming armed permanence")
	paused = true
	trap._process(0.8)
	paused = false
	_check(is_equal_approx(trap.arming_remaining, 0.2) and trap.lifetime_remaining == 1.0, "tree pause freezes both trap clocks")
	trap._process(0.25)
	_check(trap.state == PlayerTrap.State.ARMED and events["armed"] == 1 and trap.arming_remaining == 0.0 and is_equal_approx(trap.lifetime_remaining, 0.95), "arming transition emits once and applies leftover frame time to permanence")
	_check(not trap.try_trigger(target) and events["triggered"] == 0, "armed trap rejects a living target outside radius plus body collision")
	target.global_position = Vector2(357, 200)
	_check(trap.can_trigger(target) and trap.try_trigger(target), "armed trap samples the target at trigger time including collision radius")
	_check(trap.state == PlayerTrap.State.TRIGGERED and not trap.is_active() and trap.removal_reason == PlayerTrap.REASON_TRIGGERED, "successful trigger enters the terminal TRIGGERED state")
	_check(events["triggered"] == 1 and events["expired"] == 0 and removed_reasons == [&"triggered"], "trigger emits one effect hook and one removal without an expiry")
	_check(not trap.try_trigger(target) and not trap.expire(), "terminal trap rejects duplicate trigger and expiry")
	await process_frame

	var natural := _trap(102, &"explosive_trap", Vector2.ZERO, 24.0, 0.2, 0.4)
	root.add_child(natural)
	var natural_events := {"armed": 0, "expired": 0, "triggered": 0, "reason": &""}
	natural.armed.connect(func(_value: PlayerTrap) -> void: natural_events["armed"] += 1)
	natural.triggered.connect(func(_value: PlayerTrap, _target_value: CombatActor) -> void: natural_events["triggered"] += 1)
	natural.expired.connect(func(_value: PlayerTrap, reason: StringName) -> void:
		natural_events["expired"] += 1
		natural_events["reason"] = reason
	)
	natural._process(1.0)
	_check(natural.state == PlayerTrap.State.EXPIRED and natural.removal_reason == PlayerTrap.REASON_DURATION, "large frame crosses arming and permanence into terminal EXPIRED")
	_check(natural_events["armed"] == 1 and natural_events["expired"] == 1 and natural_events["triggered"] == 0 and natural_events["reason"] == &"duration", "natural timeout arms and expires once without synthesizing a trigger")
	_check(not natural.expire(&"cleanup"), "expired trap keeps terminal transition idempotent")
	target.queue_free()
	await process_frame

func _check_registry_cap_and_cleanup() -> void:
	var registry := PlayerTrapRegistry.new()
	root.add_child(registry)
	var events := {"registered": 0}
	var removed_reasons: Array[StringName] = []
	registry.trap_registered.connect(func(_trap_value: PlayerTrap) -> void: events["registered"] += 1)
	registry.trap_removed.connect(func(_trap_value: PlayerTrap, reason: StringName) -> void: removed_reasons.append(reason))
	var traps: Array[PlayerTrap] = [
		_trap(201, &"snare_trap", Vector2(10, 10), 30.0, 0.0, 30.0),
		_trap(201, &"explosive_trap", Vector2(20, 10), 30.0, 0.0, 30.0),
		_trap(201, &"snare_trap", Vector2(30, 10), 30.0, 0.0, 30.0),
		_trap(201, &"explosive_trap", Vector2(40, 10), 30.0, 0.0, 30.0),
	]
	for trap: PlayerTrap in traps.slice(0, 3):
		_check(registry.register_trap(trap), "registry accepts configured unparented trap")
	_check(registry.active_count(201) == 3 and events["registered"] == 3, "registry admits three traps for one owner across both source types")
	_check(traps[0].registration_order < traps[1].registration_order and traps[1].registration_order < traps[2].registration_order, "registry assigns a stable FIFO order")
	_check(registry.register_trap(traps[3]), "registry accepts the fourth trap by applying replacement policy")
	_check(traps[0].state == PlayerTrap.State.EXPIRED and traps[0].removal_reason == PlayerTrap.REASON_REPLACED, "fourth trap expires the oldest trap owned by the same actor")
	_check(registry.active_traps(201) == [traps[1], traps[2], traps[3]] and registry.active_count(201) == 3, "replacement preserves the newest three traps in FIFO order")
	_check(removed_reasons == [&"replaced"] and events["registered"] == 4, "replacement reports one removal and one registration without a trigger")
	var other_owner := _trap(202, &"snare_trap", Vector2(50, 10), 30.0, 0.0, 30.0)
	_check(registry.register_trap(other_owner) and registry.active_count(202) == 1 and registry.active_count() == 4, "capacity is independent per owner")
	_check(traps[3].is_in_group("player_traps") and traps[3].is_in_group("player_effects"), "registered traps join shared trap and effect cleanup groups")
	var invalid := PlayerTrap.new()
	_check(not registry.register_trap(invalid), "registry rejects an unconfigured trap")
	invalid.queue_free()
	var already_parented := _trap(203, &"snare_trap", Vector2.ZERO, 20.0, 0.0, 10.0)
	root.add_child(already_parented)
	_check(not registry.register_trap(already_parented), "registry rejects a trap already owned by another node")
	already_parented.queue_free()
	var target := _target(traps[1].global_position)
	_check(traps[1].try_trigger(target) and registry.active_count(201) == 2, "triggered trap leaves registry synchronously")
	_check(removed_reasons == [&"replaced", &"triggered"], "registry forwards the terminal trigger reason once")
	_check(registry.clear_owner(201, &"owner_cleanup") == 2 and registry.active_count(201) == 0 and registry.active_count() == 1, "owner cleanup removes only that owner's remaining traps")
	_check(traps[2].removal_reason == &"owner_cleanup" and traps[3].removal_reason == &"owner_cleanup", "owner cleanup preserves its explicit non-trigger reason")
	_check(registry.clear_all(&"run_end") == 1 and registry.active_count() == 0 and other_owner.removal_reason == &"run_end", "global cleanup expires every remaining owner without triggering")
	_check(removed_reasons == [&"replaced", &"triggered", &"owner_cleanup", &"owner_cleanup", &"run_end"], "registry emits exactly one ordered removal event per terminal transition")
	target.queue_free()
	await process_frame
	_check(get_nodes_in_group("player_traps").is_empty(), "terminal traps leave the scene tree and shared group")
	registry.queue_free()
	await process_frame

func _check_controller_cleanup() -> void:
	RunController.pending_run_state = null
	RunController.pending_run_facade = null
	RunController.selected_class_id = &"swordsman"
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
	_check(controller.trap_registry != null and controller.trap_registry.get_parent() == controller, "run controller owns one shared trap registry")
	var runtime_traps: Array[PlayerTrap] = []
	var events := {"triggered": 0}
	for index: int in range(4):
		var trap := _trap(controller.player.get_instance_id(), &"runtime_probe", Vector2(200 + index * 10, 200), 20.0, 0.0, 20.0)
		trap.triggered.connect(func(_trap_value: PlayerTrap, _target_value: CombatActor) -> void: events["triggered"] += 1)
		runtime_traps.append(trap)
		controller.trap_registry.register_trap(trap)
	_check(controller.trap_registry.active_count(controller.player.get_instance_id()) == 3 and runtime_traps[0].removal_reason == &"replaced", "controller registry enforces shared per-owner cap before concrete skills exist")
	controller._on_player_died(controller.player)
	_check(controller.run_finished and paused, "player death enters terminal run state")
	_check(controller.trap_registry.active_count() == 0 and events["triggered"] == 0, "run termination synchronously clears traps without activating their effects")
	_check(runtime_traps[1].removal_reason == &"run_end" and runtime_traps[2].removal_reason == &"run_end" and runtime_traps[3].removal_reason == &"run_end", "death cleanup records the common run-end reason on all active traps")
	_check(ClassCatalog.skill_definition(&"snare_trap") != null and ClassCatalog.skill_definition(&"explosive_trap") != null, "shared runtime accepts both delivered concrete trap skills")
	paused = false
	controller.queue_free()
	await process_frame

func _trap(owner_id: int, skill_id: StringName, placement: Vector2, radius: float, arming_time: float, lifetime: float) -> PlayerTrap:
	var trap := PlayerTrap.new()
	trap.configure(owner_id, skill_id, placement, radius, arming_time, lifetime)
	return trap

func _target(position_value: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	actor.global_position = position_value
	root.add_child(actor)
	actor.set_process(false)
	return actor

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
