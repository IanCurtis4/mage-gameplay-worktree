extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "rx-causal-late"
	build.base_class_id = &"archer"
	build.evolution_id = &"hunter"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 20, &"dex": 10}
	build.skill_ranks = {&"hunter_freezing_trap": 2, &"hunter_thorn_trap": 1}
	RunController.pending_run_state = RunState.from_build("", build)
	RunController.pending_run_facade = null
	RunController.pending_training_mode = false
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	controller.navigation.configure(Rect2(0, 0, 1600, 1000), [], 20.0)
	controller.player.global_position = Vector2(300, 300)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1400, 900)
		enemy.health.max_hp = 10000.0
		enemy.health.current_hp = 10000.0
	var point := Vector2(410, 300)
	var existing: CombatActor = controller.enemies[0]
	_check(controller.player.use_hunter_trap(&"hunter_thorn_trap", point), "place paid thorn trap before reinforcement spawn")
	var trap := controller.trap_registry.active_traps()[-1] as HunterTrap
	trap.set_process(false)
	var reinforcement := controller._spawn_enemy(&"chaser", point + Vector2(10, 0))
	reinforcement.set_process(false)
	reinforcement.health.max_hp = 10000.0
	reinforcement.health.current_hp = 10000.0
	existing.global_position = point
	trap._process(0.61)
	_check(existing.health.current_hp < 10000.0 and reinforcement.health.current_hp < 10000.0, "both existing and later tracked victim receive primary trap damage")
	_check(existing.bleed_streams.size() == 1 and reinforcement.bleed_streams.size() == 1, "both victims receive canonical bleed stream")
	var before_existing := existing.health.current_hp
	var before_reinforcement := reinforcement.health.current_hp
	existing.advance_statuses(1.0)
	reinforcement.advance_statuses(1.0)
	var existing_loss := before_existing - existing.health.current_hp
	var reinforcement_loss := before_reinforcement - reinforcement.health.current_hp
	print("RX REPRO thorn ticks: existing=", existing_loss, " reinforcement=", reinforcement_loss, " root_targets=", trap.damage_request.context._budget.plan["targets"], " new_target=", reinforcement.get_instance_id())
	_check(existing_loss > 0.0, "existing victim proves intrinsic tick pipeline is active")
	_check(reinforcement_loss > 0.0, "tracked reinforcement must receive the same thorn bleed after triggering trap")
	controller.free()
	print("E06 RX causal late targets: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
