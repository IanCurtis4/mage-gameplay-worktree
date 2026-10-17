extends SceneTree

const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_admin_run/fixture_%d" % Time.get_ticks_usec())
	var store := F.FaultStore.new(directory, ProfileCatalog.pilot())
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	_check(facade.create_character("admin_create", 0, "Admin isolado", &"mage")["ok"], "fixture character")
	var started := facade.start_run("admin_start", facade.current_profile().revision)
	_check(started["ok"], "fixture persistent run")
	if not started["ok"]:
		quit(1)
		return
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_gameplay_extension = true
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	for actor: CombatActor in controller.enemies:
		actor.set_process(false)
	var admin := PlaytestRunAdmin.new(controller)
	_check(not admin.execute("", &"spawn", &"test_gel")["ok"], "empty request rejected")
	_check(admin.execute("bad", &"unknown")["error_code"] == &"invalid_action", "unknown action rejected")
	controller.inventory_frozen = true
	_check(admin.execute("frozen", &"spawn", &"test_gel")["error_code"] == &"save_in_progress", "frozen inventory blocks mutation")
	controller.inventory_frozen = false
	var baseline := controller.enemies.size()
	var bad_spawn := admin.execute("bad_spawn", &"spawn", &"not_a_mob")
	_check(not bad_spawn["ok"] and controller.enemies.size() == baseline, "unknown mob leaves actors unchanged")
	var invalid_position := admin.execute("bad_position", &"spawn", &"test_gel", {"position": Vector2(-9999, -9999)})
	_check(not invalid_position["ok"] and controller.enemies.size() == baseline, "invalid position leaves actors unchanged")
	var bad_tier := admin.execute("bad_tier", &"spawn", &"test_gel", {"category": &"invalid"})
	_check(not bad_tier["ok"] and controller.enemies.size() == baseline, "invalid tier leaves actors unchanged")
	var spawned := admin.execute("spawn_one", &"spawn", &"test_gel")
	_check(spawned["ok"] and controller.enemies.size() == baseline + 1, "one real mob spawned")
	var enemy := instance_from_id(int(spawned.get("actor_id", 0))) as EnemyActor
	_check(enemy != null and enemy.get_meta("admin_spawn", false) and not enemy.is_summoned and enemy.stat_breakdown.base_level == int(spawned.get("level", -1)), "admin origin and catalog level applied")
	var same_spawn := admin.execute("spawn_one", &"spawn", &"test_gel")
	_check(same_spawn == spawned and controller.enemies.size() == baseline + 1, "same intent replays without another actor")
	_check(admin.execute("spawn_one", &"spawn", &"test_gel", {"category": &"rare"})["error_code"] == &"request_id_conflict", "same ID with different payload rejected")
	var original_enemies := controller.enemies.duplicate()
	while controller.enemies.size() < PlaytestRunAdmin.ACTOR_CAP:
		controller.enemies.append(enemy)
	_check(admin.execute("cap", &"spawn", &"test_gel")["error_code"] == &"actor_cap", "actor cap blocks spawn")
	controller.enemies = original_enemies
	var cleared := admin.execute("clear", &"clear_spawns")
	_check(cleared["ok"] and int(cleared["cleared"]) == 1 and controller.enemies.size() == baseline, "clear removes only admin actors")
	_check(admin.execute("clear", &"clear_spawns") == cleared, "clear replay reports prior result")
	var master_result := admin.execute("spawn_master", &"spawn", &"test_beast_master", {"category": &"rare"})
	_check(master_result["ok"], "real beast master spawn")
	if master_result["ok"]:
		var master := instance_from_id(int(master_result["actor_id"])) as EnemyActor
		master.set_process(false)
		controller._on_companion_requested(master)
		var children: Array[EnemyActor] = []
		for actor: CombatActor in controller.enemies:
			if actor is EnemyActor and actor.is_summoned and actor.summoner_id == master.get_instance_id():
				children.append(actor)
		_check(children.size() == 1 and children[0].get_meta("admin_spawn", false), "master descendant inherits admin origin")
		var tickets_before := controller.reward_service._queue.size()
		var hit := DamageRequest.new()
		hit.source_id = controller.player.get_instance_id()
		hit.target_id = master.get_instance_id()
		hit.physical_damage = 999999.0
		hit.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		master.apply_damage(hit, controller.rng)
		_check(controller.reward_service._queue.size() == tickets_before and not controller._credited_kills.has(master.get_instance_id()), "admin master death grants no ticket or kill credit")
		_check(controller.enemies.size() == baseline and (children.is_empty() or children[0] not in controller.enemies), "master death removes descendant without blocking stage")
	var capped_master_result := admin.execute("spawn_capped_master", &"spawn", &"test_beast_master", {"category": &"rare"})
	if capped_master_result["ok"]:
		var capped_master := instance_from_id(int(capped_master_result["actor_id"])) as EnemyActor
		var uncapped_list := controller.enemies.duplicate()
		while controller.enemies.size() < PlaytestRunAdmin.ACTOR_CAP:
			controller.enemies.append(capped_master)
		controller._on_companion_requested(capped_master)
		_check(controller.enemies.size() == PlaytestRunAdmin.ACTOR_CAP, "master cannot summon above actor cap")
		controller.enemies = uncapped_list
		admin.execute("clear_master", &"clear_spawns")
	var candidates := controller.run_state.effect_catalog().ids(&"augment")
	var selected: StringName = &""
	var ineligible: StringName = &""
	for id: StringName in candidates:
		if controller.run_state._augment_candidate(id, controller.run_state.composed_build())["ok"] and selected.is_empty():
			selected = id
		elif not controller.run_state._augment_candidate(id, controller.run_state.composed_build())["ok"] and ineligible.is_empty():
			ineligible = id
	_check(not selected.is_empty(), "at least one effective augment")
	_check(not ineligible.is_empty(), "at least one ineligible augment")
	var old_rng := controller.rng.state
	var old_stacks := controller.run_state.augment_stacks.duplicate(true)
	_check(admin.execute("augment_busy", &"augment", selected)["error_code"] == &"encounter_active", "combat augment needs paused admin")
	_check(controller.run_state.augment_stacks == old_stacks and controller.rng.state == old_rng, "rejected augment changes neither stacks nor RNG")
	controller.admin_panel.show()
	paused = true
	_check(admin.execute("unknown_augment", &"augment", &"not_an_augment")["error_code"] == &"unknown_definition", "unknown augment rejected")
	if not ineligible.is_empty():
		_check(not admin.execute("ineligible_augment", &"augment", ineligible)["ok"], "ineffective or unavailable augment rejected")
	_check(controller.run_state.augment_stacks == old_stacks and controller.rng.state == old_rng, "invalid augment leaves run and RNG unchanged")
	var augmented := admin.execute("augment_one", &"augment", selected)
	_check(augmented["ok"] and int(controller.run_state.augment_stacks.get(selected, 0)) == 1, "paused combat augment applies once")
	_check(admin.execute("augment_one", &"augment", selected) == augmented and int(controller.run_state.augment_stacks.get(selected, 0)) == 1, "augment replay does not stack")
	_check(controller.rng.state == old_rng, "specific augment does not roll RNG")
	var definition := controller.run_state.effect_catalog().get_definition(&"augment", selected) as AugmentDefinition
	controller.run_state.augment_stacks[selected] = definition.max_stacks
	var at_cap := controller.run_state.augment_stacks.duplicate(true)
	_check(admin.execute("augment_cap", &"augment", selected)["error_code"] == &"stack_cap" and controller.run_state.augment_stacks == at_cap, "cap rejection keeps run unchanged")
	controller.run_state.augment_stacks[selected] = 1
	var before_pending := controller.run_state.pending_choices
	var offer := admin.execute("offer_one", &"offer")
	_check(offer["ok"] and offer["open_offer"] and controller.run_state.pending_choices == before_pending + 1 and controller._admin_offer_override, "paused combat adds one identified choice")
	_check(admin.execute("offer_one", &"offer") == offer and controller.run_state.pending_choices == before_pending + 1, "offer replay does not add choice")
	_check(admin.execute("offer_other", &"offer")["error_code"] == &"offer_busy", "concurrent offer rejected")
	_check(admin.execute("augment_pending", &"augment", selected)["error_code"] == &"offer_busy", "normal choice remains isolated")
	paused = false
	controller.free()
	print("E06 admin run: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
