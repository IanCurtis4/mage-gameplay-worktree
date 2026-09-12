extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(change_scene_to_file("res://scenes/main.tscn") == OK, "main scene can be loaded as current scene")
	await scene_changed
	await process_frame
	var controller := current_scene as RunController
	_check(controller != null and controller.encounter_active and controller.encounter_index == 1, "first encounter starts automatically")
	_check(controller.enemies.size() == 2, "first encounter contains two chasers")
	var first_enemy := controller.enemies[0]
	var second_enemy := controller.enemies[1]
	first_enemy.global_position = Vector2(600, 300)
	second_enemy.global_position = Vector2(650, 300)
	var assisted_click := first_enemy.global_position + RunController.ACTOR_BODY_OFFSET + Vector2(-60, 0)
	_check(controller._enemy_at(assisted_click) == first_enemy, "selection assistance accepts click within 68 px of body")
	var direct_overlap_click := second_enemy.global_position + RunController.ACTOR_BODY_OFFSET
	_check(controller._enemy_at(direct_overlap_click) == second_enemy, "direct visual hit wins over overlapping assisted candidate")
	controller._update_hover(first_enemy.global_position + RunController.ACTOR_BODY_OFFSET)
	_check(first_enemy.is_hovered, "hovered enemy exposes visual intent state")
	controller._handle_world_click(direct_overlap_click)
	_check(controller.player.target == second_enemy and second_enemy.is_selected, "assisted click starts pursuit and visible selection")
	controller._handle_world_click(Vector2(300, 520))
	_check(controller.player.target == null and not second_enemy.is_selected, "ground click immediately cancels pursuit and selection")
	controller.player.mana = 14.2
	controller.player.slash_cooldown = 0.0
	controller._update_hud()
	_check(controller.mana_label.text.begins_with("MANA  14") and controller.skill_label.text.contains("SEM MANA") and not controller.skill_label.text.contains("Corte (15 mana) — PRONTO"), "HUD floors fractional mana and never shows false ready state")
	controller.player.slash_cooldown = 2.0
	controller._update_hud()
	_check(controller.skill_label.text.contains("RECARGA 2.0s"), "HUD distinguishes cooldown from insufficient mana")
	controller._show_skill_blocked("Corte em cone", controller.player.slash_cooldown, PlayerActor.SLASH_MANA_COST)
	_check(controller.status_label.text.contains("indisponível") and controller.status_label.text.contains("RECARGA"), "blocked skill gives immediate non-pausing feedback")
	controller.player.mana = controller.player.max_mana
	controller.player.slash_cooldown = 0.0
	controller._start_next_encounter()
	_check(controller.encounter_index == 1 and controller.enemies.size() == 2, "active encounter blocks manual advancement")

	_defeat_all(controller)
	_check(not controller.encounter_active and controller.reward != null, "clearing encounter spawns reward")
	controller._start_next_encounter()
	_check(controller.encounter_index == 1 and controller.enemies.is_empty(), "uncollected reward blocks advancement")
	controller.player.global_position = controller.reward.global_position
	await process_frame
	_check(controller.reward == null and controller.run_state.pending_choices == 1, "touching reward queues one choice")
	controller._start_next_encounter()
	_check(controller.encounter_index == 1, "pending choice blocks advancement")
	controller._open_augment_menu()
	_check(paused and controller.augment_overlay.visible, "augment menu pauses the scene tree")
	_check(controller.choice_title.get_parent() == controller.choice_column and controller.choice_title.text == "Escolha um augment", "augment title survives offer population")
	var offer := controller.run_state.current_offer
	_check(offer.size() == 3 and controller.choice_buttons.get_child_count() == 3, "augment menu preserves three choices")
	controller._confirm_augment(offer[0].id)
	_check(not paused and controller.run_state.pending_choices == 0, "confirming choice resumes and consumes pending state")

	controller._start_next_encounter()
	_check(controller.encounter_index == 2 and controller.enemies.size() == 4, "second encounter contains mixed four-enemy composition")
	_defeat_all(controller)
	controller.player.global_position = controller.reward.global_position
	await process_frame
	controller._open_augment_menu()
	var second_offer := controller.run_state.current_offer
	controller.player.mana = 5.0
	controller.player.attack_cooldown = 1.0
	controller.player.slash_cooldown = 2.0
	controller.player.dash_cooldown = 3.0
	controller._confirm_augment(second_offer[0].id)
	_check(paused and controller.run_finished and controller.result_overlay.visible, "second choice completes and pauses the victorious run")
	_check(controller.result_title.text == "Arena concluída!" and controller.run_state.augment_stacks.size() > 0, "victory preserves run summary state until restart")

	var completed_controller := controller
	controller._restart_run()
	await scene_changed
	await process_frame
	controller = current_scene as RunController
	_check(controller != completed_controller and not paused and controller.encounter_index == 1, "victory restart creates a fresh first encounter")
	_check(controller.run_state.augment_stacks.is_empty() and controller.run_state.pending_choices == 0, "victory restart clears augment state")
	_check(controller.player.mana == controller.player.max_mana and controller.player.attack_cooldown == 0.0 and controller.player.slash_cooldown == 0.0 and controller.player.dash_cooldown == 0.0, "victory restart clears mana deficits and cooldowns")

	var shooter := controller.enemies[0] as EnemyActor
	shooter._try_attack(true)
	var projectiles := get_nodes_in_group("enemy_projectiles")
	_check(projectiles.size() == 1, "enemy ranged emission creates a pausable projectile")
	var projectile := projectiles[0] as ArrowProjectile
	var shooter_position := shooter.global_position
	var shooter_cooldown := shooter.attack_cooldown
	var projectile_position := projectile.global_position
	var projectile_distance := projectile.travelled
	_kill_player(controller)
	_check(paused and controller.run_finished and controller.result_title.text == "Você caiu em combate", "player death pauses and ends the run")
	await process_frame
	await process_frame
	_check(shooter.global_position == shooter_position and shooter.attack_cooldown == shooter_cooldown, "death pause freezes enemy AI and cooldown")
	_check(projectile.global_position == projectile_position and projectile.travelled == projectile_distance, "death pause freezes projectile motion")

	var dead_controller := controller
	controller._restart_run()
	await scene_changed
	await process_frame
	controller = current_scene as RunController
	_check(controller != dead_controller and controller.player.is_alive() and controller.player.mana == controller.player.max_mana, "death restart creates a healthy fresh run")
	_check(not paused and controller.run_state.augment_stacks.is_empty() and controller.player.slash_cooldown == 0.0, "death restart clears pause, stacks and cooldowns")

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

func _kill_player(controller: RunController) -> void:
	var lethal := DamageRequest.new()
	lethal.source_id = 999
	lethal.target_id = controller.player.get_instance_id()
	lethal.base_damage = 9999.0
	lethal.hit_chance = 1.0
	lethal.can_crit = false
	controller.player.apply_damage(lethal, controller.rng)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
