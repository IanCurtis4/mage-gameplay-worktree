extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var controller := scene.instantiate() as RunController
	root.add_child(controller)
	await process_frame
	_check(controller.encounter_active and controller.encounter_index == 1, "first encounter starts automatically")
	_check(controller.enemies.size() == 2, "first encounter contains two chasers")
	_defeat_all(controller)
	_check(not controller.encounter_active and controller.reward != null, "clearing encounter spawns reward")
	controller.player.global_position = controller.reward.global_position
	await process_frame
	_check(controller.reward == null and controller.run_state.pending_choices == 1, "touching reward queues one choice")
	controller._open_augment_menu()
	_check(paused and controller.augment_overlay.visible, "augment menu pauses the scene tree")
	var offer := controller.run_state.current_offer
	_check(offer.size() == 3, "augment menu preserves three choices")
	controller._confirm_augment(offer[0].id)
	_check(not paused and controller.run_state.pending_choices == 0, "confirming choice resumes and consumes pending state")
	controller._start_next_encounter()
	_check(controller.encounter_index == 2 and controller.enemies.size() == 4, "second encounter contains mixed four-enemy composition")
	var lethal := DamageRequest.new()
	lethal.source_id = 999
	lethal.target_id = controller.player.get_instance_id()
	lethal.base_damage = 9999.0
	lethal.hit_chance = 1.0
	lethal.can_crit = false
	controller.player.apply_damage(lethal, controller.rng)
	_check(paused and controller.run_finished and controller.result_overlay.visible, "player death ends and pauses the run")
	paused = false
	controller.queue_free()
	print("Fluxo da arena: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _defeat_all(controller: RunController) -> void:
	for enemy: CombatActor in controller.enemies.duplicate():
		var lethal := DamageRequest.new()
		lethal.source_id = controller.player.get_instance_id()
		lethal.target_id = enemy.get_instance_id()
		lethal.base_damage = 9999.0
		lethal.hit_chance = 1.0
		lethal.can_crit = false
		enemy.apply_damage(lethal, controller.rng)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
