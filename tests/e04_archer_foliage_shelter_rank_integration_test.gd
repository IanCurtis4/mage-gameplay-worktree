extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_library_and_slot_boundary()
	await _check_ranked_player_runtime()
	await _check_concealment_and_enemy_acquisition()
	await _check_controller_preview_hud_and_area()
	print("E04 Abrigo de Folhagem por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_library_and_slot_boundary() -> void:
	var definition := ClassCatalog.skill_definition(&"foliage_shelter")
	var expected_durations: Array[float] = [4.0, 5.0, 6.0, 7.0, 8.0]
	var expected_costs: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
	_check(definition != null and definition.display_name == "Abrigo de Folhagem" and definition.targeting == SkillDefinition.Targeting.POINT and definition.handler_id == SkillDefinition.Handler.FOLIAGE_SHELTER, "catalog publishes the typed point-targeted Foliage Shelter handler")
	_check(definition.is_rank_catalog_valid() and definition.ranks.size() == 5 and definition.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not definition.can_crit, "Foliage Shelter owns a valid non-damaging geometric catalog")
	for rank: int in range(1, 6):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_durations[rank - 1] and values.sp_cost == expected_costs[rank - 1], "Foliage Shelter R%d owns its approved duration and SP cost" % rank)
		_check(values.cooldown == 12.0 and values.range == 360.0 and values.projectile_speed == 0.0, "Foliage Shelter R%d preserves fixed cooldown, placement range and no projectile" % rank)
		_check(values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0, "Foliage Shelter R%d remains instant" % rank)
		_check(values.precision_weight == 0.0 and values.physical_weight == 0.0 and values.magic_weight == 0.0 and values.effect_ids == [&"concealment_area"], "Foliage Shelter R%d exposes concealment without hidden damage scaling" % rank)
	var profile := ProfileCatalog.pilot()
	_check(profile.skill_metadata(&"foliage_shelter").get("max_purchased_rank") == 5, "profile progression recognizes all five Foliage Shelter ranks")
	_check(profile.base_class_is_available(&"archer"), "delivered Precision passive keeps the Archer availability gate open")
	var pilot := RunState.new(&"archer")
	_check(ClassCatalog.class_definition(&"archer").skill_ids.size() == CharacterState.ACTIVE_SLOT_COUNT and pilot.build_snapshot.active_slots.size() == CharacterState.ACTIVE_SLOT_COUNT, "legacy pilot remains bounded to exactly five active slots")
	_check(not pilot.skill_levels.has(&"foliage_shelter") and &"foliage_shelter" not in pilot.build_snapshot.active_slots, "eighth library skill is not silently auto-equipped")

func _check_ranked_player_runtime() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 700), [Rect2(400, 50, 120, 120)], 20.0)
	var rank_one := _archer(navigation, 1)
	var rank_five_source := _snapshot(5)
	var rank_five_state := RunState.from_build("foliage-r5", rank_five_source)
	rank_five_source.skill_ranks[&"foliage_shelter"] = 1
	var rank_five := PlayerActor.new()
	rank_five.configure(navigation, rank_five_state)
	rank_one.global_position = Vector2(100, 300)
	rank_five.global_position = Vector2(100, 500)
	root.add_child(rank_one)
	root.add_child(rank_five)
	var r1_emissions: Array = []
	var r5_emissions: Array = []
	rank_one.foliage_shelter_requested.connect(func(center: Vector2, duration: float) -> void: r1_emissions.append([center, duration]))
	rank_five.foliage_shelter_requested.connect(func(center: Vector2, duration: float) -> void: r5_emissions.append([center, duration]))
	var r1_sp := rank_one.current_sp
	var r5_sp := rank_five.current_sp
	_check(rank_one.use_foliage_shelter(Vector2(900, 300)) and rank_five.use_foliage_shelter(Vector2(900, 500)), "R1 and R5 place a valid shelter at a clamped point")
	_check(r1_emissions[0][0] == Vector2(460, 300) and r5_emissions[0][0] == Vector2(460, 500), "both ranks capture the fixed 360 placement range")
	_check(r1_emissions[0][1] == 4.0 and r5_emissions[0][1] == 8.0, "snapshot rank controls only the captured shelter duration")
	_check(rank_one.current_sp == r1_sp - 18.0 and rank_five.current_sp == r5_sp - 22.0, "each rank spends its approved SP cost once")
	_check(rank_one.skill_cooldown(&"foliage_shelter") == StatCalculator.effective_cooldown(12.0, rank_one.stat_breakdown) and rank_five.skill_cooldown(&"foliage_shelter") == StatCalculator.effective_cooldown(12.0, rank_five.stat_breakdown), "both ranks start the fixed effective cooldown")
	_check(rank_five.skill_rank(&"foliage_shelter") == 5 and rank_five.skill_range(&"foliage_shelter") == 360.0 and rank_five.skill_cast_time(&"foliage_shelter") == 0.0, "runtime values come from the isolated R5 snapshot")
	rank_five.mage_cooldowns[&"extended_aim"] = 0.0
	rank_five.current_sp = rank_five.max_sp
	_check(rank_five.use_extended_aim() and rank_five.skill_range(&"foliage_shelter") == 360.0, "Mira Estendida does not alter shelter placement range")
	rank_one.mage_cooldowns[&"foliage_shelter"] = 0.0
	rank_one.current_sp = rank_one.max_sp
	rank_one.global_position = Vector2(100, 100)
	var blocked_sp := rank_one.current_sp
	_check(not rank_one.use_foliage_shelter(Vector2(600, 100)) and rank_one.current_sp == blocked_sp and rank_one.skill_cooldown(&"foliage_shelter") == 0.0, "blocked placement fails before SP and cooldown commit")
	var invalid := _archer(navigation, 6)
	root.add_child(invalid)
	_check(invalid.skill_rank_definition(&"foliage_shelter") == null and invalid.skill_cost(&"foliage_shelter") == 0.0 and invalid.skill_range(&"foliage_shelter") == 0.0 and not invalid.use_foliage_shelter(Vector2(200, 200)), "invalid runtime rank is ineligible instead of falling back")
	for actor: PlayerActor in [rank_one, rank_five, invalid]:
		actor.queue_free()
	await process_frame

func _check_concealment_and_enemy_acquisition() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _archer(navigation, 5)
	player.global_position = Vector2(300, 300)
	root.add_child(player)
	player.set_process(false)
	var shelter := FoliageShelter.new()
	root.add_child(shelter)
	shelter.configure(player, player.global_position, 8.0)
	shelter.set_process(false)
	_check(shelter.is_active() and shelter.remaining == 8.0 and player.is_concealed(), "active area registers concealment immediately while the player stands inside")
	_check(not player.can_be_acquired_by(Vector2(600, 300)) and player.can_be_acquired_by(Vector2(350, 300)), "external observer cannot acquire while an observer in the same shelter can")
	var external := EnemyActor.new()
	external.configure(&"archer", navigation, player)
	external.global_position = Vector2(600, 300)
	root.add_child(external)
	external.set_process(false)
	external._path = PackedVector2Array([player.global_position])
	external._process(0.01)
	_check(not external.player_target_acquired and external._path.is_empty(), "external enemy drops retained pursuit when concealment becomes authoritative")
	var internal := EnemyActor.new()
	internal.configure(&"chaser", navigation, player)
	internal.global_position = Vector2(350, 300)
	root.add_child(internal)
	internal.set_process(false)
	var internal_attacks := [0]
	internal.attack_requested.connect(func(_request: DamageRequest, _target: CombatActor, _ranged: bool) -> void: internal_attacks[0] += 1)
	internal._process(0.01)
	_check(internal.player_target_acquired and internal_attacks[0] == 1, "enemy sharing the shelter retains acquisition and can attack normally")
	player.global_position = Vector2(450, 300)
	external._refresh_player_acquisition()
	_check(not player.is_concealed() and external.player_target_acquired, "leaving every shelter restores ordinary acquisition without ending the area")
	var arrow_request := DamageRequest.new()
	arrow_request.source_id = external.get_instance_id()
	arrow_request.target_id = player.get_instance_id()
	arrow_request.skill_id = &"enemy_arrow"
	arrow_request.physical_damage = 20.0
	arrow_request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var in_flight := ArrowProjectile.new()
	in_flight.configure(arrow_request, player, Vector2(100, 282), navigation)
	in_flight.hit.connect(func(request: DamageRequest, target: CombatActor) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		target.apply_damage(request, rng)
	)
	root.add_child(in_flight)
	player.global_position = Vector2(300, 300)
	var hp_before := player.health.current_hp
	in_flight._process(1.0)
	_check(player.is_concealed() and player.health.current_hp < hp_before, "concealment never erases a hostile projectile emitted before entry")
	player.current_sp = player.max_sp
	_check(player.use_extended_aim() and player.is_concealed(), "non-offensive self buff does not reveal the concealed player")
	player.current_sp = player.max_sp
	_check(player.use_double_shot(Vector2.RIGHT) and not player.is_concealed() and player.concealment_reveal_remaining == PlayerActor.CONCEALMENT_REVEAL_DURATION, "successful offensive skill starts the fixed temporary reveal")
	external._refresh_player_acquisition()
	_check(external.player_target_acquired, "external enemy can reacquire during offensive reveal")
	paused = true
	player._process(0.75)
	_check(player.concealment_reveal_remaining == PlayerActor.CONCEALMENT_REVEAL_DURATION, "tree pause freezes the reveal timer")
	paused = false
	player._process(PlayerActor.CONCEALMENT_REVEAL_DURATION)
	external._refresh_player_acquisition()
	_check(player.is_concealed() and not external.player_target_acquired, "reveal expiration returns a player still inside foliage to concealment")
	player.attack_cooldown = 0.0
	player.pursue(internal)
	player._try_basic_attack()
	_check(not player.is_concealed() and player.concealment_reveal_remaining == PlayerActor.CONCEALMENT_REVEAL_DURATION, "successful autoattack uses the same temporary offensive reveal")
	player.move_to(player.global_position)
	player._process(PlayerActor.CONCEALMENT_REVEAL_DURATION)
	player.mage_cooldowns[&"double_shot"] = 1.0
	_check(not player.use_double_shot(Vector2.RIGHT) and player.is_concealed(), "failed offensive attempt does not reveal")
	var remaining_before_pause := shelter.remaining
	paused = true
	await process_frame
	_check(shelter.remaining == remaining_before_pause, "tree pause freezes shelter lifetime")
	paused = false
	shelter._process(remaining_before_pause)
	_check(shelter.removal_reason == FoliageShelter.REASON_EXPIRED and not player.is_concealed() and player.can_be_acquired_by(external.global_position), "area expiration unregisters concealment exactly once")
	var death_shelter := FoliageShelter.new()
	root.add_child(death_shelter)
	death_shelter.configure(player, player.global_position, 8.0)
	death_shelter.set_process(false)
	var lethal := DamageRequest.new()
	lethal.source_id = external.get_instance_id()
	lethal.target_id = player.get_instance_id()
	lethal.physical_damage = 99999.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var lethal_rng := RandomNumberGenerator.new()
	lethal_rng.seed = 12
	player.apply_damage(lethal, lethal_rng)
	_check(not player.is_alive() and player._foliage_shelters.is_empty() and player.concealment_reveal_remaining == 0.0, "death clears concealment sources and reveal state synchronously")
	death_shelter._process(0.01)
	_check(death_shelter.removal_reason == &"owner_unavailable", "area observes an unavailable owner and removes itself without lingering state")
	for node: Node in [player, external, internal, shelter, death_shelter]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame

func _check_controller_preview_hud_and_area() -> void:
	RunController.pending_run_state = RunState.from_build("foliage-controller", _snapshot(5))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1200, 850)
	_check(controller._key_skill(KEY_D) == &"foliage_shelter" and controller.battle_controls.skill_buttons.has(&"foliage_shelter"), "equipped fifth slot binds Foliage Shelter to D and publishes its HUD card")
	var distant_point := controller.player.global_position + Vector2(1000, 0)
	controller.battle_indicators.show_aim(&"foliage_shelter", controller.player, distant_point, true)
	var expected_center := controller.player.global_position + Vector2.RIGHT * 360.0
	_check(controller.battle_indicators.endpoint == expected_center and controller.battle_indicators.active_range == 360.0, "preview clamps placement through the same fixed range as execution")
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"foliage_shelter"]
	_check(controller.skill_label.text.contains("Abrigo de Folhagem R5") and card.text.contains("R5") and card.text.contains("22 SP"), "HUD exposes Foliage Shelter rank and cost in pt-BR")
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"foliage_shelter", controller.player.global_position)
	var shelters := get_nodes_in_group("foliage_shelters")
	_check(shelters.size() == 1 and shelters[0] is FoliageShelter, "FOLIAGE_SHELTER handler materializes exactly one shared ground area")
	var shelter := shelters[0] as FoliageShelter
	_check(shelter.global_position == controller.player.global_position and shelter.remaining == 8.0 and shelter.duration == 8.0 and FoliageShelter.RADIUS == 110.0, "controller area captures R5 duration, fixed center and fixed radius")
	_check(controller.player.current_sp == sp_before - 22.0 and controller.player.skill_cooldown(&"foliage_shelter") == StatCalculator.effective_cooldown(12.0, controller.player.stat_breakdown), "controller spends one cost and starts one effective cooldown")
	var external := controller.enemies[0] as EnemyActor
	external._refresh_player_acquisition()
	_check(controller.player.is_concealed() and not external.player_target_acquired, "integrated external enemy cannot acquire the player inside foliage")
	var internal := controller.enemies[1] as EnemyActor
	internal.global_position = controller.player.global_position + Vector2(60, 0)
	internal._refresh_player_acquisition()
	_check(internal.player_target_acquired, "integrated enemy in the same area can acquire the player")
	shelter.expire(&"test_cleanup")
	_check(not controller.player.is_concealed() and controller.player.can_be_acquired_by(external.global_position), "integrated explicit cleanup restores acquisition immediately")
	await process_frame
	controller.player.mage_cooldowns[&"foliage_shelter"] = 0.0
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"foliage_shelter", controller.player.global_position)
	var encounter_shelter := get_nodes_in_group("foliage_shelters")[0] as FoliageShelter
	for enemy: CombatActor in controller.enemies.duplicate():
		controller._on_enemy_died(enemy)
	_check(encounter_shelter.removal_reason == &"encounter_end" and controller.player._foliage_shelters.is_empty(), "encounter cleanup expires the area and unregisters concealment synchronously")
	controller.queue_free()
	await process_frame

func _archer(navigation: ArenaNavigation, rank: int) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("foliage-r%d" % rank, _snapshot(rank)))
	return player

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "foliage-test"
	snapshot.base_class_id = &"archer"
	snapshot.skill_ranks = {
		&"double_shot": 1,
		&"piercing_arrow": 1,
		&"arrow_rain": 1,
		&"extended_aim": 1,
		&"foliage_shelter": rank,
	}
	snapshot.active_slots = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"foliage_shelter"]
	return snapshot

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
