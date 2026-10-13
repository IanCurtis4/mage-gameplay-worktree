extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)
func kill(controller: RunController, actor: CombatActor) -> void:
	var hit := DamageRequest.new()
	hit.source_id = controller.player.get_instance_id()
	hit.target_id = actor.get_instance_id()
	hit.physical_damage = 999999.0
	hit.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	hit.can_crit = false
	actor.apply_damage(hit,controller.rng)
func pets(controller: RunController) -> Array[EnemyActor]:
	var result: Array[EnemyActor] = []
	for actor: CombatActor in controller.enemies:
		if actor is EnemyActor and actor.is_summoned: result.append(actor)
	return result
func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_gameplay_extension/fixture_%d" % Time.get_ticks_usec())
	var store := F.FaultStore.new(directory,ProfileCatalog.pilot())
	var facade := ProfileFacade.new(store,ProfileRewardResolver.pilot_progression())
	check(facade.create_character("create",0,"Roteiro isolado",&"mage")["ok"],"real profile created")
	var started := facade.start_run("start",facade.current_profile().revision)
	check(started["ok"],"real run session starts")
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_gameplay_extension = true
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false);controller.player.set_process(false)
	check(controller.gameplay_extension and controller.reward_service.mob_loot_enabled(),"new explicit entry enables real route and production loot")
	check(controller.active_bounds == PlaytestGameplay.BOUNDS and controller.route_camera.limit_right == 2720,"larger world and camera bounds")
	var initial_count := facade.current_profile().equipment_instances.size()
	var expected_base := 0
	var expected_job := 0
	var masters := 0
	for stage: int in range(1,7):
		check(controller.encounter_index == stage and controller.encounter_active,"all six stages start")
		check(controller._required_enemies().size() == [8,7,9,7,9,6][stage-1],"finite exact root exposure")
		var master: EnemyActor
		for actor: CombatActor in controller.enemies:
			actor.set_process(false)
			if actor is EnemyActor and actor._mob_definition.visual_kind != &"humanoid":
				check(actor.body_drawer.is_valid(), "prototype visual survives local presenter scope")
			check(not actor.player_target_acquired,"safe entry does not acquire distant groups")
			if actor is EnemyActor and actor.occurrence.mob_base_id == &"test_beast_master": master = actor
		controller._start_next_encounter()
		check(controller.encounter_index == stage,"active encounter blocks advancement")
		if master != null:
			masters += 1
			var placed := false
			for offset: Vector2 in [Vector2(-100,0),Vector2(100,0),Vector2(0,-100),Vector2(0,100)]:
				var position := master.global_position + offset
				if controller.navigation.is_walkable(position) and controller.navigation.is_segment_clear(master.global_position, position, 0):
					controller.player.global_position = position
					placed = true
					break
			check(placed, "legal position for actual acquisition")
			master._refresh_player_acquisition()
			await process_frame
			var summoned := pets(controller)
			check(master.summon_used and summoned.size() == 1,"one actual animal created after acquisition")
			if summoned.is_empty():controller.free();quit(1);return
			var pet := summoned[0]
			pet.set_process(false)
			check(pet.summoner_id == master.get_instance_id() and pet.occurrence.category_id == MobTierRules.lower_category(master.occurrence.category_id) and pet.occurrence.origin_id == master.occurrence.origin_id,"owner origin and strictly lower tier")
			var before_rng := controller.rng.state
			check(not controller.reward_service.register_mob_actor(pet)["ok"] and not controller.reward_service.issue_mob_drop(pet)["ok"] and controller.rng.state == before_rng,"summons cannot register or mint rewards or consume loot RNG")
			if stage == 4:
				var before_queue := controller.reward_service._queue.size()
				kill(controller,pet)
				check(pets(controller).is_empty() and controller.reward_service._queue.size() == before_queue and not controller._credited_kills.has(pet.get_instance_id()),"pet kill grants no ticket or independent credit")
				master._refresh_player_acquisition()
				await process_frame
				check(pets(controller).is_empty(),"dead animal never replaced")
			else:
				kill(controller,master)
				check(pets(controller).is_empty() and not pet.is_alive(),"master death immediately despawns living companion")
		for actor: CombatActor in controller.enemies.duplicate():
			if actor.is_alive(): kill(controller,actor)
		check(not controller.encounter_active and controller.reward != null and controller.enemies.is_empty(),"stage completes without orphan pet blocker")
		var ticket_id := controller.reward.ticket_id
		var ticket := controller.reward_service.ticket(ticket_id)
		check(ticket["reward_id"] == PlaytestGameplay.reward_id(stage) and ticket["payload"]["equipment_drops"].is_empty(),"unique stage ID and no stage equipment fallback")
		if stage == 2:
			var before := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE))
			var rng_state := controller.rng.state
			store.failure_stage = &"write_pending"
			check(not controller._collect_reward()["ok"] and controller.reward != null and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == before,"failed durable collection preserves crystal and profile")
			store.failure_stage = &""
			check(controller._collect_reward()["ok"] and controller.rng.state == rng_state,"retry keeps original RNG and tickets")
		else: check(controller._collect_reward()["ok"],"durable mob/stage collection")
		check(controller.reward == null and controller.run_state.pending_choices == 1,"exactly one stage augment opportunity")
		var amounts: Dictionary = PlaytestGameplay.reward_definitions()[PlaytestGameplay.reward_id(stage)]
		expected_base += amounts["base_xp"]; expected_job += amounts["job_xp"]
		var character: CharacterState = facade.current_profile().characters[0]
		check(character.base_xp_total == expected_base and character.job_xp_total == expected_job,"literal accumulated base/job stage XP")
		check(controller.reward_service.collect(ticket_id)["already_applied"] and controller.run_state.pending_choices == 1,"stage replay idempotent")
		controller._start_next_encounter()
		check(controller.encounter_index == stage,"pending augment blocks progression")
		controller._open_augment_menu()
		check(paused and controller.run_state.current_offer.size()>0,"real authored augment offers")
		controller._confirm_augment(controller.run_state.current_offer[0].id)
		check(not paused and controller.run_state.pending_choices == 0,"augment confirmation resumes")
		controller._start_next_encounter()
	check(masters==3 and controller.run_finished and paused and controller.result_overlay.visible,"six stages and three finite masters end correctly")
	check(expected_base==1400 and expected_job==1000,"XP schedule explicit independent oracle")
	var profile := facade.current_profile()
	check(profile.equipment_instances.size() >= initial_count+5,"five root guarantees preserve persistent exemplars")
	var high_level := false
	for instance: EquipmentInstance in profile.equipment_instances.values():
		if instance.power_ruleset_id == &"equipment_growth_v1" and instance.item_level==15: high_level = true
	check(high_level,"boss acquisition carries real source ilvl15")
	controller.free();paused=false
	await process_frame
	var legacy := RunController.new();root.add_child(legacy);legacy.set_process(false);legacy.player.set_process(false)
	check(not legacy.gameplay_extension and legacy.enemies.size()==2 and legacy.active_bounds==RunController.ARENA_BOUNDS,"legacy fixture remains two encounters in original map")
	legacy.free()
	await process_frame
	print("E06 gameplay route: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
