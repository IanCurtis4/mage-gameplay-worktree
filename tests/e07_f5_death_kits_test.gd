extends SceneTree
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
const Spatial = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var identities: Array[Array] = [[&"swordsman", &""], [&"mage", &""], [&"archer", &""], [&"swordsman", &"defender"], [&"swordsman", &"berserker"], [&"mage", &"elementalist"], [&"mage", &"spiritualist"], [&"archer", &"sentinel"], [&"archer", &"hunter"], [&"mage", &"mg_ar"]]
	for identity: Array in identities:
		var build := BuildSnapshot.new()
		build.character_id = "f5_kits"
		build.base_class_id = identity[0]; build.evolution_id = identity[1]
		build.base_level = 30; build.job_level = 20 if build.evolution_id.is_empty() else 40
		build.library_skill_ids = build._skill_catalog.skill_ids_for_identity(build.base_class_id, build.evolution_id)
		for skill: StringName in build.library_skill_ids: build.skill_ranks[skill] = 1
		Dependencies.complete_snapshot(build)
		RunController.pending_run_state = RunState.from_build("f5_kits", build)
		var host := RunController.new()
		root.add_child(host)
		host.set_process(false)
		host.campaign_runtime = ExpeditionCampaignRuntime.new()
		var player := host.player
		player.set_process(false)
		var input := Spatial.make()
		input.traversal.radius = 20.0; input.traversal.height = 32.0
		for part: ExpeditionPartDefinition in input.parts:
			for surface: ExpeditionSurfaceDefinition in part.surfaces:
				for index: int in surface.vertices.size(): surface.vertices[index] *= Vector3(10, 1, 10)
			for connector: ExpeditionConnectorDefinition in part.connectors: connector.position *= Vector3(10, 1, 10); connector.width *= 10
			for socket: ExpeditionSocketDefinition in part.sockets: socket.position *= Vector3(10, 1, 10)
			for index: int in part.solid_volumes.size():
				var volume: AABB = part.solid_volumes[index]
				part.solid_volumes[index] = AABB(volume.position * Vector3(10, 1, 10), volume.size * Vector3(10, 1, 10))
		var generated := ExpeditionAssembler.build(input)
		check(generated["ok"], "real class death geometry")
		if not generated["ok"]: print(generated); host.free(); continue
		var world := WorldGeometry.new()
		check(world.configure(generated["data"]["manifest"], "sample")["ok"], "class world configuration")
		var content := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(), true)
		var campaign := ExpeditionCampaignState.create("death_kits", "f5_kits", generated["data"]["manifest"], content["catalog"].mob_catalog(), {})
		check(campaign["ok"], "empty-population class fixture has a valid campaign state")
		host.campaign_runtime.state = campaign["state"]
		host.campaign_runtime.state.visit("sample")
		host.campaign_runtime.worlds = {"sample": world}
		host.campaign_runtime.records = {"sample": {"fields": {}, "nodes": [], "modes": {}}}
		check(player.bind_world_geometry(world, Spatial.point("root", Vector3(200, 0, 500)), input.traversal.to_data(), "player")["ok"], "class player world binding")
		for index: int in host.enemies.size():
			var enemy: CombatActor = host.enemies[index]
			enemy.health.max_hp = 100000.0; enemy.health.current_hp = 100000.0
			check(enemy.bind_world_geometry(world, Spatial.point("root", Vector3(250 + index * 40, 0, 500)), input.traversal.to_data(), "enemy_%d" % index)["ok"], "class target world binding")
		if host.geometer_casting != null: check(host.geometer_casting.bind_world_construction(16.0)["ok"], "class construction binding")
		var skill: StringName = &"slash" if identity[0] == &"swordsman" else &"fireball" if identity[0] == &"mage" else &"arrow_rain"
		match identity[1]:
			&"defender": skill = &"defender_line_lock"
			&"berserker": skill = &"berserker_blood_rift"
			&"elementalist": skill = &"elementalist_ember_path"
			&"spiritualist": skill = &"spiritualist_soul_drain"
			&"sentinel": skill = &"sentinel_headshot"; player.sentinel_state.focus = 100.0
			&"hunter": skill = &"hunter_freezing_trap"
		var cast: Dictionary = host.geometer_casting.begin_world_trace(&"geometer_trace", Spatial.point("root", Vector3(300, 0, 500)), null, world.geometry_revision) if identity[1] == &"mg_ar" else host.cast_world_skill(skill, Spatial.point("root", Vector3(250, 0, 500)), Vector3.RIGHT, host.enemies[0], world.geometry_revision, 0, 16.0)
		check(cast["ok"], "real class action emitted before death: " + String(identity[1]))
		if player.has_active_cast(): player._advance_world_cast(10.0)
		var applied_bleeds := host.enemies[0].bleed_streams.duplicate(true)
		player.attack_cooldown = 3.25
		player.mage_cooldowns[&"fireball"] = 7.5
		player.defender_guard_return_cooldown = 2.0
		player.berserker_pursuit_cooldown = 4.0
		player.elementalist_focus_cooldown = 0.5
		player.spiritualist_recovery_cooldown = 0.75
		player.sentinel_state.focus = 75.0
		player.sentinel_state.observation_cooldown = 9.0
		player.sentinel_state.opening_cooldown = 8.0
		player.sentinel_state.intrinsic_cooldown = 7.0
		player.hunter_state.step_cooldown = 6.0
		host.spiritualist_echo_state.next_wave_id = 17
		host.run_state.queue_choice()
		var context := host.run_state.effect_ledger.new_root(player.get_instance_id())
		var request := DamageRequest.new()
		request.source_id = host.enemies[0].get_instance_id()
		request.target_id = player.get_instance_id()
		request.physical_damage = 1000000.0
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		player.apply_damage(request, host.rng)
		check(not player.is_alive() and not host.run_finished and host.campaign_runtime.pending_events.size() == 1, "real health death stays recoverable: " + String(identity[1]))
		check(player.attack_cooldown == 3.25 and player.mage_cooldowns[&"fireball"] == 7.5, "paid action cooldowns retained")
		check(player.defender_guard_return_cooldown == 2.0 and player.berserker_pursuit_cooldown == 4.0 and player.elementalist_focus_cooldown == 0.5 and player.spiritualist_recovery_cooldown == 0.75, "internal melee/caster cooldowns retained")
		check(player.sentinel_state.focus == 0.0 and player.sentinel_state.observation_cooldown == 9.0 and player.sentinel_state.opening_cooldown == 8.0 and player.sentinel_state.intrinsic_cooldown == 7.0 and player.hunter_state.step_cooldown == 6.0, "focus removed, sentinel/hunter cooldowns retained")
		check(host.spiritualist_echo_state.next_wave_id == 17 and context.is_active() and host.run_state.pending_choices == 1, "monotonic wave ID, existing causal roots and build claims retained")
		check(not player.has_active_cast() and host.enemies[0].bleed_streams == applied_bleeds, "future action canceled; applied enemy bleed preserved")
		check(_future_actions(host) == 0, "no owned action survives death")
		paused = true
		var barrier := SnapshotTickBarrier.new()
		check(barrier.acquire(host)["ok"], "post-death class barrier")
		var captured := SnapshotRegistry.new().capture(host, barrier)
		barrier.release()
		check(captured["ok"], "post-death graph is snapshot complete: " + str(captured.get("error_code")))
		if captured["ok"]:
			var restarted := SnapshotRegistry.new().restore(captured["snapshot"])
			check(restarted["ok"], "passive restart after class action cancellation")
			if restarted["ok"]:
				var copy: RunController = restarted["root"]
				check(not copy.player.is_alive() and _future_actions(copy) == 0 and copy.player.attack_cooldown == 3.25, "canceled actions stay absent after restart; paid cooldown remains")
				copy.free()
		paused = false
		ExpeditionDeathRecovery.revive(player, {"hp_fraction": 0.5, "sp_fraction": 0.25})
		check(player.is_alive() and player.health.current_hp == player.health.max_hp * 0.5 and player.current_sp == player.max_sp * 0.25, "revive resources from canonical class stats")
		host.free()
	print("E07 F5 death kits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _future_actions(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.is_in_group("player_projectiles") or child.is_in_group("player_effects"): count += 1
		count += _future_actions(child)
	return count
